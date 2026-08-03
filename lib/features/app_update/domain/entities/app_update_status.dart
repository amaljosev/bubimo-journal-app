// lib/features/app_update/domain/entities/app_update_status.dart

/// Result of asking the platform whether a newer version of the app
/// is available, independent of *how* that was determined.
///
/// Deliberately just two states, not a richer object carrying
/// `availableVersionCode` / `updatePriority` / staleness-in-days from
/// the underlying `in_app_update` package's `AppUpdateInfo` — nothing
/// in this app currently branches on those, and exposing them here
/// would leak an Android-Play-Store-specific shape into the domain
/// layer for fields no use case reads. If a future requirement needs
/// e.g. "only nudge for high-priority updates", add a field then
/// rather than speculatively now.
enum AppUpdateStatus {
  /// No update is available, or the platform/install source doesn't
  /// support checking (iOS, side loaded APK, Play-less device) — see
  /// `AppUpdateLocalDataSource`'s doc comment for why those collapse
  /// into this same case rather than a separate "unsupported" value.
  noUpdateAvailable,

  /// An update is available AND Google Play reports flexible updates
  /// are allowed for it (`updateAvailability ==
  /// updateAvailable && flexibleUpdateAllowed`). This app only ever
  /// offers the flexible flow (see `StartFlexibleUpdate`'s doc
  /// comment), so an update that's available but flexible-blocked
  /// (rare — Play can restrict this per-release) is treated the same
  /// as no update rather than a state nothing downstream can act on.
  updateAvailable,
}