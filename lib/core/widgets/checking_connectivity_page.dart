// lib/core/widgets/checking_connectivity_page.dart

import 'package:flutter/material.dart';

/// Shown immediately while a gate (`CloudBackupGate`, `InternetGate`)
/// runs its first connectivity check, before it knows whether to
/// proceed or show [NoInternetPage] — this is what gives the user
/// instant feedback on tap instead of an apparently-dead tap while the
/// check is in flight.
///
/// Deliberately bare — no title, no copy, no theming beyond the
/// spinner's own default color. This is expected to resolve in well
/// under a second in the common case, so unlike [NoInternetPage] it
/// isn't worth explaining itself.
class CheckingConnectivityPage extends StatelessWidget {
  const CheckingConnectivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}