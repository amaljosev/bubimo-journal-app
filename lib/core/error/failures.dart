// lib/core/error/failures.dart

sealed class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}

/// Something went wrong reading/writing to the local SQLite database.
final class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'A database error occurred.']);
}

/// Something went wrong reading/writing local cached data (e.g. shared
/// preferences, file system) that isn't the SQLite database itself.
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'A local storage error occurred.']);
}

/// Something went wrong performing a network request — no connection,
/// a non-2xx response, a timeout, etc. Distinct from [DatabaseFailure]
/// (local SQLite) and [CacheFailure] (local file/preferences storage),
/// since the underlying cause and the user-facing message differ.
/// Mirrors [NetworkException] in exceptions.dart, which already existed
/// but had no corresponding Failure type for repositories to emit.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'A network error occurred.']);
}

/// Input provided by the user (or another layer) failed validation before
/// it ever reached the data layer — e.g. empty theme name, invalid PIN
/// format, malformed import file.
final class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid input provided.']);
}

/// Fallback for anything unexpected that doesn't map to a known failure
/// type. Should be rare — prefer adding a specific Failure subtype when
/// a new error case becomes common enough to handle distinctly.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred.']);
}

/// Device biometric or device-credential authentication couldn't run —
/// no hardware, nothing enrolled, or the platform call itself failed.
/// Mirrors [BiometricException] in exceptions.dart. Distinct from a
/// normal failed/cancelled authentication attempt, which is a `false`
/// success value rather than a Failure.
final class BiometricFailure extends Failure {
  const BiometricFailure([
    super.message = 'Biometric authentication is not available.',
  ]);
}

/// A lock-specific data error that isn't a generic database failure —
/// e.g. verifying a PIN/pattern/security answer before one has been
/// configured. Mirrors [LockException] in exceptions.dart.
final class LockFailure extends Failure {
  const LockFailure([super.message = 'App lock is not configured.']);
}

/// Copying/writing a picked, cropped, or downloaded file into the app's
/// own media directory failed. Mirrors [MediaStorageException] in
/// exceptions.dart. Distinct from [DatabaseFailure] since the DB write
/// and the file write are two separate operations that fail
/// independently — this is specifically the file half.
final class MediaStorageFailure extends Failure {
  const MediaStorageFailure([
    super.message = 'Failed to save media file.',
  ]);
}

/// Something went wrong creating, reading, or applying a backup/export
/// bundle — a corrupt archive, a missing/unreadable manifest, or a
/// manifest whose format version this app build can't parse. Mirrors
/// [ImportExportException] in exceptions.dart.
final class ImportExportFailure extends Failure {
  const ImportExportFailure([
    super.message = 'Failed to process the backup file.',
  ]);
}

/// Google sign-in failed for a reason other than the user simply
/// dismissing the picker. Mirrors [AuthException] in exceptions.dart.
final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sign-in failed.']);
}

/// The user dismissed the Google account picker or consent screen
/// without completing sign-in. Mirrors [AuthCancelledException] — kept
/// distinct so the bloc can return to idle silently instead of showing
/// this as an error.
final class AuthCancelledFailure extends Failure {
  const AuthCancelledFailure([super.message = 'Sign-in was cancelled.']);
}

/// A previously-authorized Google session is no longer valid and the
/// user needs to sign in again. Mirrors [AuthExpiredException].
final class AuthExpiredFailure extends Failure {
  const AuthExpiredFailure([
    super.message = 'Your Google sign-in has expired. Please sign in again.',
  ]);
}

/// A Google Drive-specific problem occurred during cloud backup/restore
/// once authentication itself succeeded (quota exceeded, rate limited,
/// blocked by an organizational policy, or an unexpected server error).
/// Mirrors [CloudBackupException]. Kept as ONE failure type carrying a
/// specific message, rather than one subclass per Drive error code —
/// the presentation layer only ever displays the message, so granular
/// subclasses would add file/type overhead without adding any behavior
/// the message string doesn't already provide.
final class CloudBackupFailure extends Failure {
  const CloudBackupFailure([
    super.message = 'Cloud backup failed.',
  ]);
}

class ContactFailure extends Failure {
  const ContactFailure(super.message);
}

/// The device has no real internet access right now. Mirrors
/// [NoInternetException] — shared across every feature that needs a
/// connectivity check before doing network work (cloud backup/
/// restore, Google Fonts fetching, Supabase-backed stickers/
/// backgrounds), rather than one Failure subtype per feature. The
/// presentation layer decides how to surface this per screen: cloud
/// backup uses it to gate navigation to a dedicated no-internet
/// screen, while the lighter-weight sticker/background/font sheets
/// just show it in a SnackBar.
final class NoInternetFailure extends Failure {
  const NoInternetFailure([
    super.message = 'No internet connection.',
  ]);
}

/// A specific font (a built-in theme's font, or a custom-theme Google
/// Font pick) was actually attempted and failed to download or cache.
/// Mirrors [FontDownloadException]. Kept as one type carrying a
/// specific message rather than one subclass per failure cause,
/// consistent with [CloudBackupFailure]'s reasoning above — the
/// presentation layer only ever displays the message.
final class FontDownloadFailure extends Failure {
  const FontDownloadFailure([
    super.message = 'Could not download this font. Using the default font for now.',
  ]);
}

/// An in-app-update check or download-start call was actually
/// attempted on a real Android/Play Store install and failed at the
/// platform level. Mirrors [AppUpdateException] — see that class's
/// doc comment for why "unsupported platform/install" is NOT one of
/// this Failure's causes (that case resolves to
/// `AppUpdateStatus.noUpdateAvailable` and never reaches this type at
/// all).
final class AppUpdateFailure extends Failure {
  const AppUpdateFailure([
    super.message = 'Could not check for updates right now.',
  ]);
}