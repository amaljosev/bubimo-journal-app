// lib/core/di/injection.dart

import 'package:bubimo/core/services/review_prompt_service.dart';
import 'package:bubimo/features/ads/data/services/ads_preference_service.dart';
import 'package:bubimo/features/ads/data/services/interstitial_ad_service.dart';
import 'package:bubimo/features/plus/data/datasources/plus_iap_data_source.dart';
import 'package:bubimo/features/plus/data/datasources/plus_local_data_source.dart';
import 'package:bubimo/features/plus/data/repositories/plus_repository_impl.dart';
import 'package:bubimo/features/plus/domain/repositories/plus_repository.dart';
import 'package:bubimo/features/plus/domain/usecases/get_cached_plus_status.dart';
import 'package:bubimo/features/plus/domain/usecases/get_plus_products.dart';
import 'package:bubimo/features/plus/domain/usecases/refresh_plus_status.dart';
import 'package:bubimo/features/plus/domain/usecases/start_plus_purchase.dart';
import 'package:bubimo/features/plus/domain/usecases/watch_plus_purchase_outcomes.dart';
import 'package:bubimo/features/plus/presentation/bloc/plus_bloc.dart';
import 'package:bubimo/features/backup/presentation/bloc/backup/backup_bloc.dart';
import 'package:bubimo/features/backup/presentation/bloc/export/bloc/export_bloc.dart';

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
import '../network/network_info.dart';
import '../storage/media_storage_service.dart';
import '../theme/font/safe_font_service.dart';

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
import '../../features/backup/data/datasources/text_export_data_source.dart';
import '../../features/backup/data/repositories/backup_repository_impl.dart';
import '../../features/backup/data/repositories/pdf_export_repository_impl.dart';
import '../../features/backup/data/repositories/text_export_repository_impl.dart';
import '../../features/backup/domain/repositories/backup_repository.dart';
import '../../features/backup/domain/repositories/pdf_export_repository.dart';
import '../../features/backup/domain/repositories/text_export_repository.dart';
import '../../features/backup/domain/usecases/export_diary_backup.dart';
import '../../features/backup/domain/usecases/export_diary_pdf.dart';
import '../../features/backup/domain/usecases/export_diary_text.dart';
import '../../features/backup/domain/usecases/import_diary_backup.dart';

// diary_entry (stickers)
import '../../features/diary_entry/data/datasources/sticker_cache_data_source.dart';
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
import '../../features/backgrounds/data/datasources/background_cache_data_source.dart';
import '../../features/backgrounds/data/datasources/supabase_background_data_source.dart';
import '../../features/backgrounds/data/repositories/background_repository_impl.dart';
import '../../features/backgrounds/domain/repositories/background_repository.dart';
import '../../features/backgrounds/presentation/bloc/background_picker/background_picker_bloc.dart';
import '../services/supabase_storage_asset_service.dart';

// cloud_backup
import '../../features/cloud_backup/data/datasources/cloud_backup_local_datasource.dart';
import '../../features/cloud_backup/data/datasources/google_auth_datasource.dart';
import '../../features/cloud_backup/data/datasources/google_drive_datasource.dart';
import '../../features/cloud_backup/data/repositories/cloud_backup_repository_impl.dart';
import '../../features/cloud_backup/domain/repositories/cloud_backup_repository.dart';
import '../../features/cloud_backup/presentation/bloc/cloud_backup_bloc.dart';

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

// app_update
import '../../features/app_update/data/datasources/app_update_local_data_source.dart';
import '../../features/app_update/data/repositories/app_update_repository_impl.dart';
import '../../features/app_update/domain/repositories/app_update_repository.dart';
import '../../features/app_update/domain/usecases/check_for_update.dart';
import '../../features/app_update/domain/usecases/start_flexible_update.dart';

final GetIt getIt = GetIt.instance;

/// Registers every dependency the app needs, using manual GetIt
/// registration (no build_runner / injectable codegen).
Future<void> configureDependencies() async {
  // --- Core ---
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // Ensure the database is opened before any feature tries to use it.
  await getIt<AppDatabase>().database;

  getIt.registerLazySingleton<MediaStorageService>(
    () => const MediaStorageService(),
  );

  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());

  getIt.registerLazySingleton(
    () => SafeFontService(networkInfo: getIt<NetworkInfo>()),
  );

  // In-app review service — singleton so the `_isRequesting` guard and
  // NetworkInfo dependency are shared app-wide.
  getIt.registerLazySingleton<ReviewPromptService>(
    () => ReviewPromptService(networkInfo: getIt<NetworkInfo>()),
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
  getIt.registerLazySingleton<PdfExportDataSource>(
    () => PdfExportDataSource(getIt<DiaryLocalDataSource>()),
  );
  getIt.registerLazySingleton<PdfExportRepository>(
    () => PdfExportRepositoryImpl(getIt<PdfExportDataSource>()),
  );
  getIt.registerLazySingleton(
    () => ExportDiaryPdf(getIt<PdfExportRepository>()),
  );
  getIt.registerLazySingleton<TextExportDataSource>(
    () => TextExportDataSource(getIt<DiaryLocalDataSource>()),
  );
  getIt.registerLazySingleton<TextExportRepository>(
    () => TextExportRepositoryImpl(getIt<TextExportDataSource>()),
  );
  getIt.registerLazySingleton(
    () => ExportDiaryText(getIt<TextExportRepository>()),
  );
  getIt.registerFactory(
    () => BackupBloc(
      exportDiaryBackup: getIt<ExportDiaryBackup>(),
      importDiaryBackup: getIt<ImportDiaryBackup>(),
    ),
  );
  getIt.registerFactory(
    () => ExportBloc(
      exportDiaryPdf: getIt<ExportDiaryPdf>(),
      exportDiaryText: getIt<ExportDiaryText>(),
    ),
  );

  // --- diary_entry (stickers) ---
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  getIt.registerLazySingleton(
    () => SupabaseStickerDataSource(getIt<SupabaseClient>()),
  );
  getIt.registerLazySingleton<StickerRepository>(
    () => StickerRepositoryImpl(getIt<SupabaseStickerDataSource>()),
  );
  getIt.registerLazySingleton<StickerCacheDataSource>(
    () => JsonFileStickerCacheDataSource(),
  );
  getIt.registerFactory(
    () => StickerPickerBloc(
      stickerRepository: getIt<StickerRepository>(),
      cacheDataSource: getIt<StickerCacheDataSource>(),
    ),
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

  getIt.registerLazySingleton(
    () => AppThemeCubit(
      getSelectedTheme: getIt<GetSelectedTheme>(),
      selectTheme: getIt<SelectTheme>(),
      resetToDefaultTheme: getIt<ResetToDefaultTheme>(),
      fontService: getIt<SafeFontService>(),
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
  getIt.registerLazySingleton<BackgroundCacheDataSource>(
    () => JsonFileBackgroundCacheDataSource(),
  );
  getIt.registerLazySingleton(
    () => SupabaseStorageAssetService(
      getIt<SupabaseClient>(),
      getIt<MediaStorageService>(),
    ),
  );
  getIt.registerLazySingleton(
    () => SupabaseBackgroundDataSource(
      getIt<SupabaseClient>(),
      getIt<SupabaseStorageAssetService>(),
    ),
  );
  getIt.registerLazySingleton<BackgroundRepository>(
    () => BackgroundRepositoryImpl(
      remote: getIt<SupabaseBackgroundDataSource>(),
      cache: getIt<BackgroundCacheDataSource>(),
    ),
  );
  getIt.registerFactory(
    () => BackgroundPickerBloc(repository: getIt<BackgroundRepository>()),
  );

  // --- cloud_backup ---
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
      networkInfo: getIt<NetworkInfo>(),
    ),
  );
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
  getIt.registerLazySingleton(
    () => CheckReminderPermissions(getIt<LocalNotificationService>()),
  );
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
  getIt.registerLazySingleton(() => const OnboardingLocalDataSource());
  getIt.registerLazySingleton(
    () => CheckOnboardingStatus(getIt<OnboardingLocalDataSource>()),
  );
  getIt.registerLazySingleton(
    () => CompleteOnboarding(getIt<OnboardingLocalDataSource>()),
  );
  getIt.registerFactory(
    () => OnboardingBloc(completeOnboarding: getIt<CompleteOnboarding>()),
  );

  // --- app_update ---
  getIt.registerLazySingleton(() => const AppUpdateLocalDataSource());
  getIt.registerLazySingleton<AppUpdateRepository>(
    () => AppUpdateRepositoryImpl(getIt<AppUpdateLocalDataSource>()),
  );
  getIt.registerLazySingleton(
    () => CheckForUpdate(getIt<AppUpdateRepository>()),
  );
  getIt.registerLazySingleton(
    () => StartFlexibleUpdate(getIt<AppUpdateRepository>()),
  );

  // --- ads ---
  getIt.registerLazySingleton<AdsPreferenceService>(
    () => AdsPreferenceService(),
  );
  getIt.registerLazySingleton<InterstitialAdService>(
    () => InterstitialAdService(getIt<AdsPreferenceService>()),
  );

  // --- plus (Bubimo Plus: Google Play Billing) ---
  getIt.registerLazySingleton(() => PlusIapDataSource());
  getIt.registerLazySingleton(() => PlusLocalDataSource());
  getIt.registerLazySingleton<PlusRepository>(
    () => PlusRepositoryImpl(
      iapDataSource: getIt<PlusIapDataSource>(),
      localDataSource: getIt<PlusLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton(
    () => GetCachedPlusStatus(getIt<PlusRepository>()),
  );
  getIt.registerLazySingleton(() => RefreshPlusStatus(getIt<PlusRepository>()));
  getIt.registerLazySingleton(() => GetPlusProducts(getIt<PlusRepository>()));
  getIt.registerLazySingleton(() => StartPlusPurchase(getIt<PlusRepository>()));
  getIt.registerLazySingleton(
    () => WatchPlusPurchaseOutcomes(getIt<PlusRepository>()),
  );

  getIt.registerLazySingleton(
    () => PlusBloc(
      getCachedPlusStatus: getIt<GetCachedPlusStatus>(),
      refreshPlusStatus: getIt<RefreshPlusStatus>(),
      getPlusProducts: getIt<GetPlusProducts>(),
      startPlusPurchase: getIt<StartPlusPurchase>(),
      watchPlusPurchaseOutcomes: getIt<WatchPlusPurchaseOutcomes>(),
    ),
  );
}