// lib/core/network/network_info.dart

import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Single app-wide source of truth for "is there real internet access
/// right now" — backed by `internet_connection_checker_plus`, which
/// verifies actual reachability against external endpoints rather than
/// just reporting the device's radio/Wi-Fi state (the way
/// `connectivity_plus` alone would — a phone can report "connected to
/// Wi-Fi" while sitting behind a hotel captive portal with no real
/// internet access).
///
/// Registered once as a GetIt lazy singleton (see injection.dart) and
/// shared by every feature that needs a connectivity check before
/// doing network work: cloud backup/restore (this milestone), and
/// Google Fonts fetching + Supabase-backed stickers/backgrounds
/// (upcoming milestones) — one implementation, reused everywhere,
/// rather than each feature standing up its own checker.
abstract class NetworkInfo {
  /// One-shot check — does the device have real internet access right
  /// now. Use this immediately before a network-dependent operation
  /// (an upload, a font fetch, a Supabase query) rather than caching
  /// the result, since connectivity can change between checks.
  Future<bool> get isConnected;

  /// Stream of connectivity changes, for screens/gates that want to
  /// react live (e.g. auto-retry once the connection comes back on the
  /// no-internet gate screen) rather than only checking once.
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {
  final InternetConnection _connectionChecker;

  NetworkInfoImpl({InternetConnection? connectionChecker})
      : _connectionChecker = connectionChecker ?? InternetConnection();

  @override
  Future<bool> get isConnected => _connectionChecker.hasInternetAccess;

  @override
  Stream<bool> get onConnectivityChanged => _connectionChecker.onStatusChange
      .map((status) => status == InternetStatus.connected);
}