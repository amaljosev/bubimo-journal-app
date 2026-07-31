// lib/core/error/exceptions.dart

/// Base class for all data-layer exceptions.
/// Thrown by data sources (local DB, cache, network); caught in repository
/// impls and converted into a matching Failure (see failures.dart) before
/// crossing into the domain layer.
abstract class AppException implements Exception {
  final String message;

  const AppException({required this.message});

  @override
  String toString() => message;
}

/// Thrown by local data sources on sqflite read/write/insert/delete errors,
/// or when an expected row is not found.
///
/// Named `AppDatabaseException` (not `DatabaseException`) because
/// `package:sqflite_common` already exports its own `DatabaseException`
/// class with a different (positional) constructor signature. Importing
/// both into the same file causes a name collision / wrong-constructor bug.
class AppDatabaseException extends AppException {
  const AppDatabaseException({required super.message});
}

/// Thrown by local cache/key-value data sources (e.g. app_settings reads).
class CacheException extends AppException {
  const CacheException({required super.message});
}

/// Thrown by remote data sources (Supabase, Google Drive) on network or
/// API errors, once those milestones are implemented.
class NetworkException extends AppException {
  const NetworkException({required super.message});
}

/// Thrown by the app lock feature when device biometric authentication
/// (fingerprint/face) or device-credential authentication cannot run —
/// no hardware, nothing enrolled, or the underlying platform call
/// failed. Not thrown for a normal failed/cancelled attempt (that's a
/// `false` return value, not an exception) — only for setup/hardware
/// issues that prevent authentication from being attempted at all.
class BiometricException extends AppException {
  const BiometricException({required super.message});
}

/// Thrown by the app lock feature for lock-specific data errors that
/// aren't generic database failures — e.g. verifying a PIN/pattern/
/// security answer when none has been configured yet.
class LockException extends AppException {
  const LockException({required super.message});
}

/// Thrown by [MediaStorageService] when copying/writing a picked,
/// cropped, or downloaded file into the app's own media directory
/// fails — e.g. the source file vanished between pick and copy (gallery
/// cache eviction), or a disk write failed (permissions, out of space).
///
/// Kept distinct from [AppDatabaseException]/[CacheException] since this
/// is a raw filesystem (dart:io) failure, not a sqflite or key-value
/// storage failure — the calling repository maps it to its own
/// [Failure] type (e.g. `MediaStorageFailure` for diary/profile,
/// `ImportExportFailure` for backup/restore) rather than a generic one,
/// so the presentation layer can show a message specific to what the
/// user was actually doing.
class MediaStorageException extends AppException {
  const MediaStorageException({required super.message});
}

/// Thrown by the import/export feature for archive-level problems that
/// aren't a plain filesystem or database error — e.g. a `.bubimo`
/// bundle missing its manifest, a manifest whose `formatVersion` this
/// app build doesn't know how to read, or a corrupt/truncated zip.
class ImportExportException extends AppException {
  const ImportExportException({required super.message});
}

/// Thrown by the cloud backup feature's Google sign-in step for any
/// authentication problem other than the user simply dismissing the
/// account picker (that's [AuthCancelledException], handled
/// separately since it's an expected, silent outcome rather than an
/// error to surface).
class AuthException extends AppException {
  const AuthException({required super.message});
}

/// Thrown when the user dismisses the Google account picker or the
/// consent screen without completing sign-in. Kept distinct from
/// [AuthException] so the bloc can treat this as a silent no-op
/// (return to idle) rather than showing an error message for what is,
/// from the user's perspective, not a failure at all.
class AuthCancelledException extends AppException {
  const AuthCancelledException({required super.message});
}

/// Thrown when a previously-authorized Google session/token is no
/// longer valid (revoked, expired, or never obtained) and the caller
/// needs to sign in again — distinct from [AuthException] so the UI
/// can specifically prompt "please sign in again" rather than a
/// generic auth error.
class AuthExpiredException extends AppException {
  const AuthExpiredException({required super.message});
}

/// Thrown by the cloud backup feature for any Google Drive-specific
/// problem once authentication itself has succeeded — quota exceeded,
/// rate limiting, a blocked organizational policy, or an unexpected
/// Drive API/server error. Carries a specific, already-user-facing
/// message rather than being split into one exception class per Drive
/// error code — see [CloudBackupFailure]'s doc comment for the
/// reasoning.
class CloudBackupException extends AppException {
  const CloudBackupException({required super.message});
}

/// Thrown by any feature that requires real internet access (Google
/// Drive cloud backup/restore, Google Fonts fetching, Supabase-backed
/// stickers/backgrounds) when [NetworkInfo.isConnected] is false right
/// before the network call would otherwise be made.
///
/// Deliberately ONE shared exception type across all of those
/// features rather than a separate no-connection exception per
/// feature — lack of internet is the same condition and the same
/// user-facing message regardless of which network call was about to
/// happen, so a single type (mapped to the single [NoInternetFailure]
/// below) avoids pointless duplication. Callers that need
/// feature-specific handling on top of this (e.g. the cloud backup
/// gate screen vs. a stickers sheet's SnackBar) branch on how they
/// catch/map it, not on having a different exception class per
/// feature.
class NoInternetException extends AppException {
  const NoInternetException({
    super.message = 'No internet connection.',
  });
}