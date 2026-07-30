// lib/core/database/tables/app_settings_table.dart

/// Schema definition for the `app_settings` table.
///
/// Single-row ("singleton") table holding all app-wide settings:
/// reminders, theme selection, lock configuration. [columnThemeId]
/// (already present in earlier schema versions) is reused as-is by the
/// rebuilt Theme feature to persist the active theme's id — no new
/// column/migration is needed for theme selection itself.
///
/// Onboarding completion is NOT stored here — it lives in
/// SharedPreferences instead (see the onboarding feature's
/// `OnboardingLocalDataSource`), since it's a simple one-shot device
/// flag rather than app data that belongs alongside reminders/theme/
/// lock config.
class AppSettingsTable {
  AppSettingsTable._();

  static const String tableName = 'app_settings';

  /// Fixed row id — always use this value when reading/writing the
  /// single app settings row instead of generating a new id.
  static const String singletonId = 'singleton';

  static const String columnId = 'id';
  static const String columnReminderTime = 'reminder_time';
  static const String columnReminderEnabled = 'reminder_enabled';

  /// Stores the id of the currently active theme — either a built-in
  /// id constant (see `BuiltInThemes`) or a `custom_themes.id` value.
  /// `NULL` means no selection has been made yet, in which case the
  /// Theme feature falls back to `BuiltInThemes.defaultBuiltInThemeId`.
  static const String columnThemeId = 'theme_id';
  static const String columnFontPreference = 'font_preference';

  /// Stored as one of: 'none', 'biometric', 'pin', 'pattern',
  /// 'device_credential'. Only one is active at a time.
  static const String columnLockType = 'lock_type';
  static const String columnLockPinHash = 'lock_pin_hash';
  static const String columnLockPatternHash = 'lock_pattern_hash';
  static const String columnLockSecurityQuestion = 'lock_security_question';
  static const String columnLockSecurityAnswerHash =
      'lock_security_answer_hash';
  static const String columnBiometricEnabled = 'biometric_enabled';
  static const String columnLockTimeoutMinutes = 'lock_timeout_minutes';

  static const String defaultLockType = 'none';
  static const int defaultLockTimeoutMinutes = 1;

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnReminderTime TEXT,
      $columnReminderEnabled INTEGER NOT NULL DEFAULT 0,
      $columnThemeId TEXT,
      $columnFontPreference TEXT,
      $columnLockType TEXT NOT NULL DEFAULT '$defaultLockType',
      $columnLockPinHash TEXT,
      $columnLockPatternHash TEXT,
      $columnLockSecurityQuestion TEXT,
      $columnLockSecurityAnswerHash TEXT,
      $columnBiometricEnabled INTEGER NOT NULL DEFAULT 0,
      $columnLockTimeoutMinutes INTEGER DEFAULT $defaultLockTimeoutMinutes
    );
  ''';
}