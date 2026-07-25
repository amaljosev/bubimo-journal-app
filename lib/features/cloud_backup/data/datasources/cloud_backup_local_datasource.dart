// lib/features/cloud_backup/data/datasources/cloud_backup_local_datasource.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the email of the Google account last used for cloud
/// backup, purely on this device.
///
/// This is what lets `CloudBackupRepositoryImpl` skip the native
/// Google sign-in call entirely when the Cloud Backup screen is opened
/// and no account has ever been linked (or the user explicitly signed
/// out) — instead of calling into `google_sign_in` on every visit, the
/// repository first checks this local marker and only talks to Google
/// at all when one is present, to confirm the session is still valid.
///
/// Deliberately just an email string, not a full account/session
/// object — the real session (tokens, etc.) is entirely owned and
/// cached by the `google_sign_in` plugin itself; this class only
/// remembers "was someone signed in last time", which is presentation
/// information the plugin has no durable API for.
class CloudBackupLocalDataSource {
  static const String _kSignedInEmailKey = 'cloud_backup_signed_in_email';

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSignedInEmailKey);
  }

  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSignedInEmailKey, email);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSignedInEmailKey);
  }
}