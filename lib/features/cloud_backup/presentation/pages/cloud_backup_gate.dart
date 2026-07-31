// lib/features/cloud_backup/presentation/pages/cloud_backup_gate.dart

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/network_info.dart';
import 'cloud_backup_page.dart';
import 'no_internet_page.dart';

/// Entry point for `AppRoutes.cloudBackup` — checks real internet
/// access BEFORE the actual [CloudBackupPage] (with its Google
/// sign-in / Drive upload-download UI) is ever built, and shows
/// [NoInternetPage] instead when there's none.
///
/// This is a gate, not a wrapper: [CloudBackupPage] itself has no
/// connectivity awareness and assumes it's only ever reached with a
/// working connection — matching how the cloud backup screen was
/// asked for ("if user don't have internet connection don't navigate
/// to cloud backup screen, act as a gate"). Contrast with the
/// lighter-weight sticker/background/font pickers, which stay
/// reachable while offline and just show a SnackBar per attempted
/// action instead of a full gate.
///
/// A brief loading state covers the very first check on open;
/// afterward, only the [NoInternetPage] retry path re-checks (there's
/// no live connectivity listener here — going online mid-visit while
/// already on the real screen is handled by the repository's own
/// per-operation check, see `CloudBackupRepositoryImpl._requireInternet`,
/// not by tearing down this gate).
class CloudBackupGate extends StatefulWidget {
  const CloudBackupGate({super.key});

  @override
  State<CloudBackupGate> createState() => _CloudBackupGateState();
}

class _CloudBackupGateState extends State<CloudBackupGate> {
  final NetworkInfo _networkInfo = getIt<NetworkInfo>();

  bool _checking = true;
  bool _isRetrying = false;
  bool _hasInternet = false;

  @override
  void initState() {
    super.initState();
    _check(initial: true);
  }

  Future<void> _check({bool initial = false}) async {
    setState(() {
      if (initial) {
        _checking = true;
      } else {
        _isRetrying = true;
      }
    });

    final hasInternet = await _networkInfo.isConnected;

    if (!mounted) return;
    setState(() {
      _hasInternet = hasInternet;
      _checking = false;
      _isRetrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasInternet) {
      return NoInternetPage(
        isRetrying: _isRetrying,
        onRetry: () => _check(),
      );
    }

    return const CloudBackupPage();
  }
}