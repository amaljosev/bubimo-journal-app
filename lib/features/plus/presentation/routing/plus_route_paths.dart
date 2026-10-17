// lib/features/plus/presentation/routing/plus_route_paths.dart

/// Route path for the Plus paywall, defined inside the plus feature
/// (same pattern as `AppLockRoutePaths`) so widgets in this feature can
/// push it without importing app_router.dart and creating a circular
/// import. `AppRoutes.plus` re-exports it.
class PlusRoutePaths {
  PlusRoutePaths._();

  static const String paywall = '/plus';
}
