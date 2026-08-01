// lib/core/network/internet_gate.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../di/injection.dart';
import '../widgets/checking_connectivity_page.dart';
import '../widgets/no_internet_page.dart';
import 'network_info.dart';

/// Gates a one-off action that needs real internet access but has no
/// routed destination screen to swap the way `CloudBackupGate` swaps
/// `CloudBackupPage` — e.g. Settings' "Privacy Policy" row, which
/// launches an external URL directly rather than pushing an app
/// screen. Deliberately mirrors `CloudBackupGate`'s own structure and
/// widgets, not just its idea: same [CheckingConnectivityPage] for the
/// first check, same [NoInternetPage] for the offline state, same
/// checking/retry field shape.
///
/// [run] pushes [_InternetGatePage] immediately, synchronously, on
/// every call — it does NOT pre-check connectivity itself before
/// deciding whether to navigate. That's deliberate: `CloudBackupGate`
/// gets its "instant feedback on tap" for free, because GoRouter
/// builds it (showing its checking state) the moment navigation
/// starts, before its own connectivity check has resolved. An earlier
/// version of this gate awaited the check FIRST and only pushed
/// anything if it came back offline — which meant an online tap (the
/// common case) had no visual feedback at all until the check
/// resolved, and a slow check could look like a dead tap. Pushing
/// unconditionally first reproduces the same instant-transition
/// feedback `CloudBackupGate` has, at the cost of a brief
/// push-then-pop for the online case — the same trade-off
/// `CloudBackupGate` itself already makes (it also always shows its
/// checking state first, never skips straight to real content even
/// when the check would resolve near-instantly).
///
/// Online: [_InternetGatePage] pops itself, then runs [action] — same
/// as if the device had been online for the very first tap. Offline:
/// shows [NoInternetPage]; its retry re-checks and does the same
/// pop-then-run once connectivity returns.
class InternetGate {
  InternetGate._();

  static Future<void> run(
    BuildContext context, {
    required FutureOr<void> Function() action,
    required String title,
    required String message,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InternetGatePage(
          action: action,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _InternetGatePage extends StatefulWidget {
  final FutureOr<void> Function() action;
  final String title;
  final String message;

  const _InternetGatePage({
    required this.action,
    required this.title,
    required this.message,
  });

  @override
  State<_InternetGatePage> createState() => _InternetGatePageState();
}

/// Field/method shape deliberately mirrors `_CloudBackupGateState` —
/// `_checking`/`_isRetrying`, a single `_check({initial})` driving
/// both the first check and every retry. No `_hasInternet` field here
/// the way `_CloudBackupGateState` has one: that gate needs to
/// remember "online" to keep rendering real content on every rebuild,
/// but this gate acts on "online" immediately (pop + run action) and
/// never rebuilds into a third state, so there's nothing to remember
/// between builds — reaching `build()` at all means the last check
/// came back offline.
class _InternetGatePageState extends State<_InternetGatePage> {
  bool _checking = true;
  bool _isRetrying = false;

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

    final hasInternet = await getIt<NetworkInfo>().isConnected;
    if (!mounted) return;

    if (hasInternet) {
      // Pop this gate first, then run the action — matches what would
      // have happened had the device been online on the very first
      // tap, rather than leaving the caller to notice the pop and
      // re-invoke the action itself.
      Navigator.of(context).pop();
      await widget.action();
      return;
    }

    setState(() {
      _checking = false;
      _isRetrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const CheckingConnectivityPage();
    }

    return NoInternetPage(
      title: widget.title,
      message: widget.message,
      isRetrying: _isRetrying,
      onRetry: () => _check(),
    );
  }
}