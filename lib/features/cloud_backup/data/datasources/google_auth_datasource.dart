// lib/features/cloud_backup/data/datasources/google_auth_datasource.dart

import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/secrets.dart';
import '../../../../core/error/exceptions.dart';

/// Drive scope limited to files this app itself created
/// (`appDataFolder`) — the app can never see or touch anything else in
/// the user's Drive, and Google's OAuth consent screen reflects that
/// narrow scope to the user.
const String kDriveAppDataScope =
    'https://www.googleapis.com/auth/drive.appdata';

/// Guards every native call that can present UI (the account picker,
/// and the Drive-scope consent sheet). Without this, dismissing that
/// UI abnormally — swiping it away, or tapping the platform "X" close
/// control instead of an explicit Cancel — can leave the underlying
/// native completion handler never firing. When that happens the
/// awaited Dart Future simply never resolves: the bloc stays `busy`
/// forever, the "Sign in with Google" button never re-enables, and
/// after long enough the OS itself flags the app as unresponsive. A
/// timeout guarantees the Future always resolves one way or another,
/// which is the only way to recover once the native side has gone
/// silent — there's no cancellation API for an in-flight
/// authenticate()/authorizeScopes() call to fall back on instead.
const Duration _kInteractiveAuthTimeout = Duration(seconds: 90);

/// Adds `Authorization: Bearer <token>` to every outgoing request, so
/// `googleapis`' generated `drive.DriveApi` client can be built from a
/// plain authenticated [http.Client].
class _BearerAuthClient extends http.BaseClient {
  _BearerAuthClient(this._inner, this._accessToken);

  final http.Client _inner;
  final String _accessToken;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Wraps `google_sign_in` v7's singleton API for this app's one use:
/// obtaining an authenticated [http.Client] scoped to
/// [kDriveAppDataScope] for `CloudBackupRepositoryImpl`'s Drive calls.
///
/// `google_sign_in` 7.x replaced the old per-instance API with a
/// process-wide singleton (`GoogleSignIn.instance`) that must be
/// `initialize()`d exactly once before any other call, and replaced the
/// old `currentUser` getter with an `authenticationEvents` stream — this
/// class tracks the latest signed-in account from that stream itself
/// since there's no synchronous "who's signed in right now" accessor
/// anymore.
class GoogleAuthDataSource {
  static const List<String> _scopes = <String>[kDriveAppDataScope];

  bool _initialized = false;

  GoogleSignInAccount? _currentUser;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: Secrets.googleApi);

    _authSub = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _currentUser = event.user;
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _currentUser = null;
      }
    });

    _initialized = true;
  }

  /// Returns the current account, attempting a silent recovery if this
  /// datasource hasn't observed a sign-in event yet this session (e.g.
  /// right after app start).
  Future<GoogleSignInAccount?> _resolveAccount() async {
    if (_currentUser != null) return _currentUser;
    final account =
        await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account != null) _currentUser = account;
    return _currentUser;
  }

  /// Best-effort email of whichever account this datasource currently
  /// considers signed in — null if none is known yet. Read this right
  /// after a successful [signIn] to learn which account to persist.
  String? get currentAccountEmail => _currentUser?.email;

  /// Interactive sign-in + Drive scope authorization (shows the account
  /// picker, and a consent screen if the scope hasn't been granted
  /// before).
  Future<void> signIn() async {
    await _ensureInitialized();
    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate()
          .timeout(
            _kInteractiveAuthTimeout,
            onTimeout: () => throw const AuthCancelledException(
              message: 'Sign-in was dismissed.',
            ),
          );
      _currentUser = account;

      // Only call authorizeScopes if the Drive scope isn't already
      // granted — authorizeScopes() launches a second consent UI,
      // unnecessary (and an extra interruption) if it's already been
      // granted in a previous session.
      final existing =
          await account.authorizationClient.authorizationForScopes(_scopes);
      if (existing == null) {
        await account.authorizationClient
            .authorizeScopes(_scopes)
            .timeout(
              _kInteractiveAuthTimeout,
              onTimeout: () => throw const AuthCancelledException(
                message: 'Drive access request was dismissed.',
              ),
            );
      }
    } on AuthCancelledException {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException(message: 'Cancelled');
      }
      throw AuthException(
        message: e.description ?? 'Google sign-in failed.',
      );
    } on Exception catch (e) {
      // Covers platform-level failures (e.g. access_denied,
      // network_error, sign_in_required) surfaced during
      // authorizeScopes on Android that aren't GoogleSignInExceptions.
      throw AuthException(message: 'Drive authorization failed: $e');
    }
  }

  /// Non-interactive (silent) sign-in. Returns true if a signed-in
  /// account was found.
  ///
  /// Callers that want to avoid the native call entirely when there is
  /// no reason to believe an account is linked (first launch, or after
  /// an explicit sign-out) should check their own locally-saved marker
  /// BEFORE calling this — see `CloudBackupRepositoryImpl.restoreSession`.
  /// This method itself has no such memory; it always asks Google.
  Future<bool> signInSilently() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance
          .attemptLightweightAuthentication()!
          .timeout(_kInteractiveAuthTimeout, onTimeout: () => null);
      _currentUser = account;
      return account != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    try {
      await GoogleSignIn.instance.signOut();
      _currentUser = null;
    } catch (e) {
      throw AuthException(message: e.toString());
    }
  }

  Future<bool> get isSignedIn async {
    await _ensureInitialized();
    return (await _resolveAccount()) != null;
  }

  /// Builds an authenticated [http.Client] for `googleapis`'
  /// `drive.DriveApi`. Throws [AuthExpiredException] if no valid
  /// account/token can be obtained.
  Future<http.Client> authClient() async {
    await _ensureInitialized();

    final GoogleSignInAccount? account = await _resolveAccount();
    if (account == null) {
      throw const AuthExpiredException(message: 'Not signed in.');
    }

    try {
      final GoogleSignInClientAuthorization authorization =
          await account.authorizationClient.authorizationForScopes(
                _scopes,
              ) ??
              await account.authorizationClient
                  .authorizeScopes(_scopes)
                  .timeout(
                    _kInteractiveAuthTimeout,
                    onTimeout: () => throw const AuthCancelledException(
                      message: 'Drive access request was dismissed.',
                    ),
                  );

      return _BearerAuthClient(http.Client(), authorization.accessToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException(message: 'Cancelled');
      }
      throw const AuthExpiredException(message: 'Authorization expired.');
    } catch (e) {
      throw AuthException(message: e.toString());
    }
  }

  /// Call when disposing — optional, since this datasource is
  /// typically registered as an app-wide singleton and lives for the
  /// process's lifetime.
  Future<void> dispose() async {
    await _authSub?.cancel();
    _authSub = null;
  }
}