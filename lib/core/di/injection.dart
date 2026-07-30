// lib/core/di/injection.dart

import 'package:bubimo/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:bubimo/features/contact_us/data/repositories/contact_repository_impl.dart';
import 'package:bubimo/features/contact_us/domain/repositories/contact_repository.dart';
import 'package:bubimo/features/contact_us/domain/usecases/send_support_email.dart';
import 'package:bubimo/features/home/presentation/bloc/diary_list/diary_list_bloc.dart';
import 'package:bubimo/features/theme/data/datasources/theme_local_data_source.dart';
import 'package:bubimo/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:bubimo/features/theme/domain/usecases/reset_to_default_theme.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../storage/media_storage_service.dart';

// diary_entry
import '../../features/diary_entry/data/datasources/diary_local_data_source.dart';
import '../../features/diary_entry/data/repositories/diary_repository_impl.dart';
import '../../features/diary_entry/domain/repositories/diary_repository.dart';
import '../../features/diary_entry/domain/usecases/create_diary_entry.dart';
import '../../features/diary_entry/domain/usecases/delete_diary_entry.dart';
import '../../features/diary_entry/domain/usecases/get_all_diary_entries.dart';
import '../../features/diary_entry/domain/usecases/get_diary_entry_by_id.dart';
import '../../features/diary_entry/domain/usecases/update_diary_entry.dart';
import '../../features/diary_entry/presentation/bloc/diary_form/diary_form_bloc.dart';

// backup (Import & Export)
import '../../features/backup/data/datasources/backup_local_data_source.dart';
import '../../features/backup/data/datasources/pdf_export_data_source.dart';
import '../../features/backup/data/repositories/backup_repository_impl.dart';
import '../../features/backup/data/repositories/pdf_export_repository_impl.dart';
import '../../features/backup/domain/repositories/backup_repository.dart';
import '../../features/backup/domain/repositories/pdf_export_repository.dart';
import '../../features/backup/domain/usecases/export_diary_backup.dart';
import '../../features/backup/domain/usecases/export_diary_pdf.dart';
import '../../features/backup/domain/usecases/import_diary_backup.dart';

// diary_entry (stickers)
import '../../features/diary_entry/data/datasources/supabase_sticker_data_source.dart';
import '../../features/diary_entry/data/repositories/sticker_repository_impl.dart';
import '../../features/diary_entry/domain/repositories/sticker_repository.dart';
import '../../features/diary_entry/presentation/bloc/sticker_picker/sticker_picker_bloc.dart';

import '../../features/theme/domain/repositories/theme_repository.dart';
import '../../features/theme/domain/usecases/delete_custom_theme.dart';
import '../../features/theme/domain/usecases/get_all_themes.dart';
import '../../features/theme/domain/usecases/get_selected_theme.dart';
import '../../features/theme/domain/usecases/save_custom_theme.dart';
import '../../features/theme/domain/usecases/select_theme.dart';
import '../../features/theme/presentation/bloc/custom_theme_form/custom_theme_form_bloc.dart';
import '../../features/theme/presentation/bloc/theme_list/theme_list_bloc.dart';
import '../../features/theme/presentation/cubit/app_theme_cubit.dart';

// analytics
import '../../features/profile/domain/usecases/analytics_usecases/get_analytics_snapshot.dart';
import '../../features/profile/domain/usecases/analytics_usecases/get_current_streak.dart';
import '../../features/profile/domain/usecases/analytics_usecases/get_entry_stats.dart';
import '../../features/profile/domain/usecases/analytics_usecases/get_heatmap_data.dart';
import '../../features/profile/domain/usecases/analytics_usecases/get_longest_streak.dart';
import '../../features/profile/domain/usecases/analytics_usecases/get_mood_counts.dart';
import '../../features/profile/domain/usecases/analytics_usecases/get_word_count_trend.dart';
import '../../features/profile/presentation/bloc/analytics_bloc.dart';

// profile
import '../../features/profile/data/datasources/profile_local_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/get_user_profile.dart';
import '../../features/profile/domain/usecases/update_user_profile.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';

// backgrounds
import '../../features/backgrounds/data/datasources/supabase_background_data_source.dart';
import '../../features/backgrounds/presentation/bloc/background_picker/background_picker_bloc.dart';
import '../services/supabase_storage_asset_service.dart';

// cloud_backup
import '../../features/cloud_backup/data/datasources/cloud_backup_local_datasource.dart';
import '../../features/cloud_backup/data/datasources/google_auth_datasource.dart';
import '../../features/cloud_backup/data/datasources/google_drive_datasource.dart';
import '../../features/cloud_backup/data/repositories/cloud_backup_repository_impl.dart';
import '../../features/cloud_backup/domain/repositories/cloud_backup_repository.dart';
import '../../features/cloud_backup/presentation/bloc/cloud_backup_bloc.dart';

// rich_editor (remote stickers)

// reminders
import '../../features/reminders/data/datasources/local_notification_service.dart';
import '../../features/reminders/domain/usecases/cancel_reminder.dart';
import '../../features/reminders/domain/usecases/check_reminder_permissions.dart';
import '../../features/reminders/domain/usecases/get_reminder_settings.dart';
import '../../features/reminders/domain/usecases/set_reminder.dart';
import '../../features/reminders/presentation/bloc/reminder_settings/reminder_settings_bloc.dart';

// app_lock
import '../../features/app_lock/data/datasources/biometric_data_source.dart';
import '../../features/app_lock/data/datasources/lock_local_data_source.dart';
import '../../features/app_lock/data/repositories/app_lock_repository_impl.dart';
import '../../features/app_lock/domain/repositories/app_lock_repository.dart';
import '../../features/app_lock/domain/usecases/authenticate_with_biometrics.dart';
import '../../features/app_lock/domain/usecases/check_biometric_availability.dart';
import '../../features/app_lock/domain/usecases/get_lock_config.dart';
import '../../features/app_lock/domain/usecases/set_biometric_enabled.dart';
import '../../features/app_lock/domain/usecases/set_lock_type.dart'
    as app_lock_usecase;
import '../../features/app_lock/domain/usecases/verify_pin.dart';
import '../../features/app_lock/domain/usecases/verify_security_answer.dart';
import '../../features/app_lock/presentation/bloc/lock_bloc.dart';

// onboarding
import '../../features/onboarding/data/datasources/onboarding_local_data_source.dart';
import '../../features/onboarding/domain/usecases/check_onboarding_status.dart';
import '../../features/onboarding/domain/usecases/complete_onboarding.dart';
import '../../features/onboarding/presentation/bloc/onboarding_bloc.dart';

final GetIt getIt = GetIt.instance;

/// Registers every dependency the app needs, using manual GetIt
/// registration (no build_runner / injectable codegen).
///
/// Call this once, before `runApp` — see `main.dart`. Assumes
/// `Supabase.initialize(...)` has already run before this is called,
/// since the backgrounds feature registers a `SupabaseClient` here.
///
/// This file is updated incrementally as each milestone adds new
/// datasources, repositories, use cases, and blocs/cubits — never
/// regenerated from scratch. New registrations are always added AFTER
/// the bloc/use case classes they reference already exist.
Future<void> configureDependencies() async {
  // --- Core ---
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // Ensure the database is opened before any feature tries to use it.
  await getIt<AppDatabase>().database;

  // Single app-wide entry point for turning a picked/cropped file or a
  // block of downloaded bytes into a durable, app-owned file. Every
  // feature that accepts a photo (diary_entry, profile, theme) depends
  // on this the same way every feature depends on AppDatabase for rows
  // — see media_storage_service.dart's doc comment for why storing the
  // raw image_picker/image_cropper path directly is unsafe.
  getIt.registerLazySingleton<MediaStorageService>(
    () => const MediaStorageService(),
  );

  // --- diary_entry ---
  getIt.registerLazySingleton<DiaryLocalDataSource>(
    () => DiaryLocalDataSourceImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<DiaryRepository>(
    () => DiaryRepositoryImpl(getIt<DiaryLocalDataSource>()),
  );
  getIt.registerLazySingleton(() => CreateDiaryEntry(getIt<DiaryRepository>()));
  getIt.registerLazySingleton(
    () => GetAllDiaryEntries(getIt<DiaryRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetDiaryEntryById(getIt<DiaryRepository>()),
  );
  getIt.registerLazySingleton(() => UpdateDiaryEntry(getIt<DiaryRepository>()));
  getIt.registerLazySingleton(() => DeleteDiaryEntry(getIt<DiaryRepository>()));

  getIt.registerFactory(
    () => DiaryFormBloc(
      createDiaryEntry: getIt<CreateDiaryEntry>(),
      updateDiaryEntry: getIt<UpdateDiaryEntry>(),
      getDiaryEntryById: getIt<GetDiaryEntryById>(),
    ),
  );

  // --- backup (Import & Export) ---
  // Depends on DiaryLocalDataSource (registered just above) and
  // MediaStorageService (registered under --- Core ---) — both must be
  // registered before this block runs, hence its placement here rather
  // than alongside an alphabetically-later feature.
  getIt.registerLazySingleton<BackupLocalDataSource>(
    () => BackupLocalDataSource(
      diaryLocalDataSource: getIt<DiaryLocalDataSource>(),
      mediaStorageService: getIt<MediaStorageService>(),
    ),
  );
  getIt.registerLazySingleton<BackupRepository>(
    () => BackupRepositoryImpl(getIt<BackupLocalDataSource>()),
  );
  getIt.registerLazySingleton(
    () => ExportDiaryBackup(getIt<BackupRepository>()),
  );
  getIt.registerLazySingleton(
    () => ImportDiaryBackup(getIt<BackupRepository>()),
  );
  // "Download as PDF" — a separate, one-way, human-readable export.
  // Depends only on DiaryLocalDataSource, not on BackupLocalDataSource/
  // BackupRepository, since it doesn't read or write `.bubimo` bundles
  // at all — see PdfExportRepository's doc comment for why this is a
  // distinct repository rather than a third method bolted onto
  // BackupRepository.
  getIt.registerLazySingleton<PdfExportDataSource>(
    () => PdfExportDataSource(getIt<DiaryLocalDataSource>()),
  );
  getIt.registerLazySingleton<PdfExportRepository>(
    () => PdfExportRepositoryImpl(getIt<PdfExportDataSource>()),
  );
  getIt.registerLazySingleton(
    () => ExportDiaryPdf(getIt<PdfExportRepository>()),
  );
  // Factory, not singleton — same reasoning as DiaryFormBloc just
  // above: a fresh instance per visit to the page, not one shared
  // instance whose stale exportResult/importResult could leak into a
  // later, unrelated visit.
  getIt.registerFactory(
    () => BackupBloc(
      exportDiaryBackup: getIt<ExportDiaryBackup>(),
      importDiaryBackup: getIt<ImportDiaryBackup>(),
      exportDiaryPdf: getIt<ExportDiaryPdf>(),
    ),
  );

  // --- diary_entry (stickers) ---
  // Assumes Supabase.initialize(...) has already run in main(). The
  // SupabaseClient singleton is registered once here and reused by the
  // backgrounds feature below — registration order doesn't matter for
  // lazy singletons (resolved on first use), but it's registered here
  // since stickers are the first section that needs it.
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  getIt.registerLazySingleton(
    () => SupabaseStickerDataSource(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<StickerRepository>(
    () => StickerRepositoryImpl(getIt<SupabaseStickerDataSource>()),
  );
  // Factory (not singleton) — a fresh StickerPickerBloc is created each
  // time the picker sheet opens, mirroring BackgroundPickerBloc.
  getIt.registerFactory(
    () => StickerPickerBloc(stickerRepository: getIt<StickerRepository>()),
  );

  // --- home ---
  getIt.registerFactory(
    () => DiaryListBloc(getAllDiaryEntries: getIt<GetAllDiaryEntries>()),
  );

  // --- theme ---
  getIt.registerLazySingleton<ThemeLocalDataSource>(
    () => ThemeLocalDataSourceImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<ThemeRepository>(
    () => ThemeRepositoryImpl(getIt<ThemeLocalDataSource>()),
  );
  getIt.registerLazySingleton(() => GetAllThemes(getIt<ThemeRepository>()));
  getIt.registerLazySingleton(() => GetSelectedTheme(getIt<ThemeRepository>()));
  getIt.registerLazySingleton(() => SelectTheme(getIt<ThemeRepository>()));
  getIt.registerLazySingleton(
    () => ResetToDefaultTheme(getIt<ThemeRepository>()),
  );
  getIt.registerLazySingleton(() => SaveCustomTheme(getIt<ThemeRepository>()));
  getIt.registerLazySingleton(
    () => DeleteCustomTheme(getIt<ThemeRepository>()),
  );

  // AppThemeCubit is a lazy singleton (not a factory) — it must persist
  // for the app's entire lifetime since it drives MaterialApp's theme.
  getIt.registerLazySingleton(
    () => AppThemeCubit(
      getSelectedTheme: getIt<GetSelectedTheme>(),
      selectTheme: getIt<SelectTheme>(),
      resetToDefaultTheme: getIt<ResetToDefaultTheme>(),
    ),
  );

  getIt.registerFactory(
    () => ThemeListBloc(
      getAllThemes: getIt<GetAllThemes>(),
      getSelectedTheme: getIt<GetSelectedTheme>(),
      deleteCustomTheme: getIt<DeleteCustomTheme>(),
      appThemeCubit: getIt<AppThemeCubit>(),
    ),
  );
  getIt.registerFactory(
    () => CustomThemeFormBloc(
      saveCustomTheme: getIt<SaveCustomTheme>(),
      appThemeCubit: getIt<AppThemeCubit>(),
    ),
  );

  // --- analytics ---
  // Individual per-metric use cases are still registered (kept as thin
  // wrappers around shared pure calculation functions — see each
  // Get*'s doc comment) for any call site or test that wants just one
  // metric. AnalyticsBloc itself depends only on GetAnalyticsSnapshot,
  // which does a SINGLE getAllDiaryEntries() fetch and derives every
  // metric from that one result, instead of the previous pattern of 5
  // independent use cases each re-fetching every entry from scratch.
  getIt.registerLazySingleton(() => GetMoodCounts(getIt<GetAllDiaryEntries>()));
  getIt.registerLazySingleton(
    () => GetCurrentStreak(getIt<GetAllDiaryEntries>()),
  );
  getIt.registerLazySingleton(
    () => GetLongestStreak(getIt<GetAllDiaryEntries>()),
  );
  getIt.registerLazySingleton(
    () => GetHeatmapData(getIt<GetAllDiaryEntries>()),
  );
  getIt.registerLazySingleton(() => GetEntryStats(getIt<GetAllDiaryEntries>()));
  getIt.registerLazySingleton(
    () => GetWordCountTrend(getIt<GetAllDiaryEntries>()),
  );
  getIt.registerLazySingleton(
    () => GetAnalyticsSnapshot(getIt<GetAllDiaryEntries>()),
  );

  getIt.registerFactory(
    () => AnalyticsBloc(getAnalyticsSnapshot: getIt<GetAnalyticsSnapshot>()),
  );

  // --- profile ---
  // Backs the combined Profile & Analytics screen's profile section
  // (photo, username, diary name, header image). AnalyticsBloc above
  // is reused as-is for that screen's analytics section.
  getIt.registerLazySingleton<ProfileLocalDataSource>(
    () => ProfileLocalDataSourceImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(getIt<ProfileLocalDataSource>()),
  );
  getIt.registerLazySingleton(() => GetUserProfile(getIt<ProfileRepository>()));
  getIt.registerLazySingleton(
    () => UpdateUserProfile(getIt<ProfileRepository>()),
  );

  getIt.registerFactory(
    () => ProfileCubit(
      getUserProfile: getIt<GetUserProfile>(),
      updateUserProfile: getIt<UpdateUserProfile>(),
    ),
  );

  // --- backgrounds ---
  // SupabaseClient is registered above (diary_entry stickers section).
  getIt.registerLazySingleton(
    () => SupabaseStorageAssetService(
      getIt<SupabaseClient>(),
      getIt<MediaStorageService>(),
    ),
  );
  getIt.registerLazySingleton(
    () => SupabaseBackgroundDataSource(getIt<SupabaseStorageAssetService>()),
  );
  getIt.registerFactory(
    () => BackgroundPickerBloc(
      remoteDataSource: getIt<SupabaseBackgroundDataSource>(),
    ),
  );

  // --- cloud_backup ---
  // GoogleAuthDataSource is a lazy singleton — it tracks the current
  // signed-in account itself (via google_sign_in's authenticationEvents
  // stream), so it must persist for the app's lifetime rather than
  // being recreated per bloc instance, or every new CloudBackupBloc
  // would forget who's signed in.
  //
  // CloudBackupLocalDataSource persists just the signed-in account's
  // email via SharedPreferences, so `CloudBackupRepositoryImpl` can
  // skip the native Google sign-in call entirely on repeat visits to
  // the Cloud Backup screen when nothing has ever been linked (or the
  // user explicitly signed out) — see its doc comment and
  // `CloudBackupRepository.restoreSession`.
  //
  // Depends on BackupLocalDataSource (registered under
  // --- backup (Import & Export) --- above) — cloud backup reuses that
  // exact archive-building/import logic rather than re-implementing
  // entry/media serialization a second time. See
  // CloudBackupRepositoryImpl's doc comment.
  getIt.registerLazySingleton(() => GoogleAuthDataSource());
  getIt.registerLazySingleton(
    () => GoogleDriveDataSource(getIt<GoogleAuthDataSource>()),
  );
  getIt.registerLazySingleton(() => CloudBackupLocalDataSource());
  getIt.registerLazySingleton<CloudBackupRepository>(
    () => CloudBackupRepositoryImpl(
      authDataSource: getIt<GoogleAuthDataSource>(),
      driveDataSource: getIt<GoogleDriveDataSource>(),
      backupLocalDataSource: getIt<BackupLocalDataSource>(),
      localDataSource: getIt<CloudBackupLocalDataSource>(),
    ),
  );
  // Factory — fresh per visit, same reasoning as BackupBloc: a stale
  // currentBackup/message shouldn't leak into a later, unrelated visit.
  getIt.registerFactory(
    () => CloudBackupBloc(repository: getIt<CloudBackupRepository>()),
  );

  // --- reminders ---
  getIt.registerLazySingleton(
    () => LocalNotificationService(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton(
    () => GetReminderSettings(getIt<LocalNotificationService>()),
  );
  getIt.registerLazySingleton(
    () => SetReminder(getIt<LocalNotificationService>()),
  );
  getIt.registerLazySingleton(
    () => CancelReminder(getIt<LocalNotificationService>()),
  );
  // CheckReminderPermissions needs LocalNotificationService: its
  // exact-alarm status check goes through
  // LocalNotificationService.canScheduleExactAlarms() rather than
  // permission_handler directly — permission_handler's
  // Permission.scheduleExactAlarm.status has a filed upstream bug
  // where it can report granted even when the OS has it denied (see
  // that use case's doc comment). Notification-permission status
  // still goes through permission_handler as normal.
  getIt.registerLazySingleton(
    () => CheckReminderPermissions(getIt<LocalNotificationService>()),
  );
  // RequestReminderPermissions ALSO needs LocalNotificationService, for
  // the same reason plus its own exact-alarm request — same dependency
  // LocalNotificationService's own constructor already registered
  // above, so no new registration is needed for it.
  getIt.registerLazySingleton(
    () => RequestReminderPermissions(getIt<LocalNotificationService>()),
  );

  getIt.registerFactory(
    () => ReminderSettingsBloc(
      getReminderSettings: getIt<GetReminderSettings>(),
      setReminder: getIt<SetReminder>(),
      cancelReminder: getIt<CancelReminder>(),
      checkReminderPermissions: getIt<CheckReminderPermissions>(),
      requestReminderPermissions: getIt<RequestReminderPermissions>(),
    ),
  );

  // --- app_lock ---
  // Reuses the shared app_settings singleton row/table (see
  // AppSettingsTable) rather than a separate database or
  // flutter_secure_storage — lock_type, the hashed PIN/security-answer,
  // the security-question prompt, and biometric_enabled are all
  // columns already defined on that table. No new table, no new
  // storage mechanism, no migration needed.
  getIt.registerLazySingleton<LockLocalDataSource>(
    () => LockLocalDataSourceImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<BiometricDataSource>(
    () => BiometricDataSourceImpl(),
  );
  getIt.registerLazySingleton<AppLockRepository>(
    () => AppLockRepositoryImpl(
      localDataSource: getIt<LockLocalDataSource>(),
      biometricDataSource: getIt<BiometricDataSource>(),
    ),
  );

  getIt.registerLazySingleton(() => GetLockConfig(getIt<AppLockRepository>()));
  getIt.registerLazySingleton(
    () => app_lock_usecase.SetLockType(getIt<AppLockRepository>()),
  );
  // Independent of SetLockType — flips biometric_enabled without
  // touching lock_type. See SetBiometricEnabled's doc comment.
  getIt.registerLazySingleton(
    () => SetBiometricEnabled(getIt<AppLockRepository>()),
  );
  getIt.registerLazySingleton(
    () => CheckBiometricAvailability(getIt<AppLockRepository>()),
  );
  getIt.registerLazySingleton(
    () => AuthenticateWithBiometrics(getIt<AppLockRepository>()),
  );
  getIt.registerLazySingleton(() => VerifyPin(getIt<AppLockRepository>()));
  getIt.registerLazySingleton(
    () => VerifySecurityAnswer(getIt<AppLockRepository>()),
  );

  // Lazy singleton, NOT a factory — LockBloc must persist for the
  // app's entire lifetime (mirrors AppThemeCubit just above): both
  // main.dart's LoadLockConfig dispatch at startup and LockGate's
  // BlocConsumer need to be reading and reacting to the same instance.
  // A factory here would silently hand LockGate a brand-new, never-
  // loaded bloc instance the moment it's built.
  getIt.registerLazySingleton(
    () => LockBloc(
      getLockConfig: getIt<GetLockConfig>(),
      setLockType: getIt<app_lock_usecase.SetLockType>(),
      setBiometricEnabled: getIt<SetBiometricEnabled>(),
      checkBiometricAvailability: getIt<CheckBiometricAvailability>(),
      authenticateWithBiometrics: getIt<AuthenticateWithBiometrics>(),
      verifyPin: getIt<VerifyPin>(),
      verifySecurityAnswer: getIt<VerifySecurityAnswer>(),
    ),
  );
  getIt.registerLazySingleton<ContactRepository>(
    () => const ContactRepositoryImpl(),
  );
  getIt.registerLazySingleton<SendSupportEmail>(
    () => SendSupportEmail(getIt<ContactRepository>()),
  );

  // --- onboarding ---
  // Uses SharedPreferences, not the app_settings table — this is a
  // one-shot device flag, not app data that belongs alongside
  // reminders/theme/lock config. No AppDatabase dependency, so
  // nothing here needs the database to be open first (unlike most
  // other lazy singletons above).
  getIt.registerLazySingleton(() => const OnboardingLocalDataSource());
  // Lazy singleton: read from app_router.dart's `initialLocation`
  // logic once per app start, not per-widget-build — a factory would
  // work too since this use case has no internal state, but
  // lazySingleton avoids reconstructing it pointlessly on every cold
  // start check.
  getIt.registerLazySingleton(
    () => CheckOnboardingStatus(getIt<OnboardingLocalDataSource>()),
  );
  getIt.registerLazySingleton(
    () => CompleteOnboarding(getIt<OnboardingLocalDataSource>()),
  );
  // Factory, not a singleton — mirrors ReminderSettingsBloc/
  // CloudBackupBloc: onboarding is only ever shown once per real
  // user, but a factory keeps this consistent with every other
  // screen-scoped bloc in the app and avoids a stale
  // scrollPosition/currentPage surviving if onboarding were ever
  // re-entered (e.g. a future "replay onboarding" debug/support
  // option).
  getIt.registerFactory(
    () => OnboardingBloc(completeOnboarding: getIt<CompleteOnboarding>()),
  );
}