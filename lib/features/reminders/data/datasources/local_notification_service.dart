// lib/features/reminders/data/datasources/local_notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/app_settings_table.dart';
import '../../domain/usecases/get_reminder_settings.dart';

class LocalNotificationService {
  final AppDatabase appDatabase;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _reminderNotificationId = 1001;

  /// Guards [initialize] so it only ever runs once and so every call
  /// site that depends on it (`scheduleDailyReminder`, indirectly
  /// `tz.local`) can await the same in-flight result instead of
  /// assuming app startup already ran it first.
  ///
  /// This is the fix for `LateInitializationError: Field
  /// '_local@...' has not been initialized.`: `tz.local` is backed by
  /// a `late` field in the `timezone` package with no built-in
  /// default — it stays unset, and throws on first read, until
  /// `tz.setLocalLocation` runs at least once inside [initialize].
  /// Nothing previously guaranteed [initialize] ran before
  /// [scheduleDailyReminder] read `tz.local` via
  /// [_nextInstanceOfTime]; [ensureInitialized] closes that gap
  /// directly at the point of use, rather than relying on ordering
  /// elsewhere in the app that this class can't see or enforce.
  Future<void>? _initializationFuture;

  LocalNotificationService(this.appDatabase);

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    // Every path below calls `setLocalLocation` explicitly, so
    // `tz.local` is guaranteed valid once this method returns —
    // regardless of whether the device timezone lookup succeeds.
    // (Previously the catch block left `tz.local` untouched on the
    // mistaken assumption that a "UTC default" already existed; it
    // doesn't, and that gap is what produced the crash in the
    // screenshot.)
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      // Device timezone lookup failed, or returned an identifier
      // `tz.getLocation` doesn't recognize. 'UTC' is always present
      // in the timezone package's built-in database, so this call
      // cannot itself throw. A reminder firing on UTC rather than
      // local time is a degraded experience; an unhandled crash on
      // every attempt to set a reminder is not an acceptable one.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Runs [initialize] exactly once, however many call sites invoke
  /// this concurrently. Safe to call from every method on this class
  /// that touches `tz.local` or the plugin — it will no-op (return
  /// the same completed future) once initialization has already
  /// happened, whether that was via app startup calling [initialize]
  /// directly or via an earlier call to this method.
  Future<void> ensureInitialized() {
    return _initializationFuture ??= initialize();
  }

  Future<void> requestExactAlarmsPermission() async {
    await ensureInitialized();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  Future<bool> canScheduleExactAlarms() async {
    await ensureInitialized();
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications();
    return result ?? true;
  }

  /// Schedules (or replaces) the daily repeating reminder notification
  /// at [time].
  Future<void> scheduleDailyReminder(ReminderTime time) async {
    // Guarantees `tz.local` is set before `_nextInstanceOfTime` reads
    // it below — this is the specific call that was previously
    // reachable before `initialize()` had ever run.
    await ensureInitialized();

    final scheduledDate = _nextInstanceOfTime(time);

    await _plugin.zonedSchedule(
      _reminderNotificationId,
      'Time to write',
      'How was your day? Capture it in your diary.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'diary_reminder_channel',
          'Diary Reminders',
          channelDescription: 'Daily reminder to write a diary entry',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels the scheduled daily reminder notification, if any.
  Future<void> cancelReminder() async {
    await ensureInitialized();
    await _plugin.cancel(_reminderNotificationId);
  }

  /// Persists reminder settings to the singleton `app_settings` row.
  /// If [time] is null, the stored `reminder_time` column is left
  /// unchanged — only [enabled] is updated. This lets
  /// `CancelReminder` disable the reminder without losing the
  /// previously chosen time.
  Future<void> saveSettings({
    required ReminderTime? time,
    required bool enabled,
  }) async {
    final db = await appDatabase.database;

    final values = <String, Object?>{
      AppSettingsTable.columnReminderEnabled: enabled ? 1 : 0,
    };
    if (time != null) {
      values[AppSettingsTable.columnReminderTime] = time.toStorageString();
    }

    final rowsAffected = await db.update(
      AppSettingsTable.tableName,
      values,
      where: '${AppSettingsTable.columnId} = ?',
      whereArgs: [AppSettingsTable.singletonId],
    );

    if (rowsAffected == 0) {
      // Singleton settings row doesn't exist yet (fresh install).
      await db.insert(AppSettingsTable.tableName, {
        AppSettingsTable.columnId: AppSettingsTable.singletonId,
        AppSettingsTable.columnLockType: AppSettingsTable.defaultLockType,
        AppSettingsTable.columnLockTimeoutMinutes:
            AppSettingsTable.defaultLockTimeoutMinutes,
        ...values,
      });
    }
  }

  /// Reads the currently saved reminder settings.
  Future<ReminderSettings> getSettings() async {
    final db = await appDatabase.database;
    final rows = await db.query(
      AppSettingsTable.tableName,
      columns: [
        AppSettingsTable.columnReminderTime,
        AppSettingsTable.columnReminderEnabled,
      ],
      where: '${AppSettingsTable.columnId} = ?',
      whereArgs: [AppSettingsTable.singletonId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return const ReminderSettings(time: null, enabled: false);
    }

    final row = rows.first;
    return ReminderSettings(
      time: ReminderTime.fromStorageString(
        row[AppSettingsTable.columnReminderTime] as String?,
      ),
      enabled: (row[AppSettingsTable.columnReminderEnabled] as int? ?? 0) == 1,
    );
  }

  /// Computes the next occurrence of [time] in the device's local
  /// timezone — today if that time hasn't passed yet, otherwise
  /// tomorrow. `matchDateTimeComponents: DateTimeComponents.time` in
  /// [scheduleDailyReminder] then makes it repeat daily from there.
  ///
  /// Requires `tz.local` to already be set — callers must go through
  /// [ensureInitialized] first (see [scheduleDailyReminder], the only
  /// current caller).
  tz.TZDateTime _nextInstanceOfTime(ReminderTime time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}