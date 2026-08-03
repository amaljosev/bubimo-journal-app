// lib/features/app_lock/presentation/pages/app_lock_settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/debounced_tap.dart';
import '../../domain/entities/lock_type.dart';
import '../bloc/lock_bloc.dart';
import '../routing/app_lock_route_paths.dart';
import '../widgets/lock_palette.dart';

/// Each lock option's icon gets its own fixed, distinct hue rather
/// than being drawn from the theme's primary/secondary/tertiary slots.
///
/// This app's [ColorScheme] only exposes 3 real accent roles
/// (primary/secondary/tertiary — and tertiary is mapped to the same
/// value as secondary in theme_mapper.dart), which isn't enough to
/// keep 4 options visually distinct, and on some themes collapsed two
/// options to the identical color. These 4 hues are chosen to sit at
/// very different points on the color wheel (blue-violet, pink,
/// amber, purple) so they stay distinguishable from each other and
/// from the theme's own primary/secondary regardless of which of the
/// 6 built-in themes — or a custom theme — is active. Selection state
/// (border/soft background/checkmark) still uses the *theme's* own
/// primary color, so the page still visibly reskins with the rest of
/// the app; only the resting icon color is fixed.
class _LockOptionData {
  const _LockOptionData({
    required this.type,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
  });

  final LockType type;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
}

const _options = <_LockOptionData>[
  _LockOptionData(
    type: LockType.none,
    icon: Icons.lock_open_rounded,
    label: 'No Lock',
    subtitle: 'Your diary opens right away',
    iconColor: Color(0xFF9AA0A8), // neutral slate
  ),
  _LockOptionData(
    type: LockType.biometric,
    icon: Icons.fingerprint_rounded,
    label: 'Mobile Lock',
    subtitle: 'Use your device face or fingerprint',
    iconColor: Color(0xFF5B8DEF), // blue
  ),
  _LockOptionData(
    type: LockType.pin,
    icon: Icons.password_rounded,
    label: 'PIN Lock',
    subtitle: 'Unlock with a 4-digit code',
    iconColor: Color(0xFFFF6F91), // pink
  ),
  _LockOptionData(
    type: LockType.securityQuestion,
    icon: Icons.question_answer_rounded,
    label: 'Security Question',
    subtitle: 'Unlock by answering your question',
    iconColor: Color(0xFFF2A93B), // amber
  ),
];

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<LockBloc>().add(const LoadLockConfig());
  }

  Future<void> _onSelectLockType(LockType type) async {
    final bloc = context.read<LockBloc>();
    final currentType = bloc.state.lockType;

    if (type == currentType) return;

    switch (type) {
      case LockType.biometric:
        final succeeded = await _promptBiometric(bloc);
        if (!succeeded) return;
        bloc.add(const SetLockType(type: LockType.biometric));
      case LockType.pin:
        final pin = await context.push<String>(AppLockRoutePaths.pinCreate);
        if (pin == null || !mounted) return;
        bloc.add(SetLockType(type: type, pin: pin));
      case LockType.securityQuestion:
        final result = await context.push<Map<String, String>>(
          AppLockRoutePaths.securityQuestionSetup,
        );
        if (result == null || !mounted) return;
        bloc.add(
          SetLockType(
            type: type,
            question: result['question'],
            answer: result['answer'],
          ),
        );
      case LockType.none:
        bloc.add(const SetLockType(type: LockType.none));
    }
  }

  Future<void> _onToggleBiometricShortcut(bool enabled) async {
    final bloc = context.read<LockBloc>();

    if (enabled) {
      // Confirm biometrics actually work on this device before turning
      // the shortcut on — same reasoning as the primary Mobile Lock
      // option: don't persist a setting that would leave the user
      // unable to unlock via a broken/unavailable prompt. Unlike the
      // primary option, failing here just means the toggle stays off;
      // it doesn't touch lockType at all.
      final succeeded = await _promptBiometric(
        bloc,
        reason: 'Authenticate to enable the biometric shortcut',
      );
      if (!succeeded) return;
    }

    bloc.add(ToggleBiometric(enabled));
  }

  /// Runs the biometric prompt via the bloc's existing verify flow, then
  /// waits for it to settle and reports whether it succeeded. Reuses
  /// VerifyBiometricAttempt instead of adding a separate "checking
  /// biometrics" concept to AppLockState. Shared by both the primary
  /// Mobile Lock option and the secondary biometric-shortcut toggle.
  Future<bool> _promptBiometric(
    LockBloc bloc, {
    String reason = 'Authenticate to enable biometric lock',
  }) async {
    bloc.add(VerifyBiometricAttempt(reason: reason));

    await bloc.stream.firstWhere(
      (state) => state.verificationStatus != VerificationStatus.inProgress,
    );

    final succeeded =
        bloc.state.verificationStatus == VerificationStatus.success;

    // AppLockState.verificationError now always carries one of
    // LockFailure's fixed, human-readable default messages (e.g.
    // "Authentication was cancelled or failed." /
    // "Biometric authentication is not available on this device.") —
    // see app_lock_repository_impl.dart's authenticateWithBiometrics /
    // isBiometricAvailable, which log the real underlying
    // exception/stack to the debug console themselves and never pass
    // it up into the message shown here. So this is safe to show
    // directly, with no raw exception text leaking into the SnackBar.
    final message = bloc.state.verificationError;
    bloc.add(const ResetVerification());

    if (!succeeded && mounted) {
      _showSnackBar(
        message == null || message.isEmpty
            ? 'Biometric authentication failed. Please try again.'
            : message,
      );
    }
    return succeeded;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSecondary,
        title: Text(
          'Secure your thoughts',
          style: TextStyle(color: colorScheme.onSecondary),
        ),
        leading: context.canPop() == true
            ? BackButton(onPressed: () => context.pop())
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.secondary, colorScheme.primary],
          ),
        ),
        child: BlocConsumer<LockBloc, AppLockState>(
          listener: (context, state) {
            if (state.loadError != null) {
              _showSnackBar('Error: ${state.loadError}');
            }
          },
          builder: (context, state) {
            if (state.isLoading) {
              return Center(
                child: CircularProgressIndicator(color: colorScheme.onSurface),
              );
            }

            // The "also allow biometric" shortcut only makes sense once
            // a PIN or Security Question is the primary method —
            // LockType.biometric is already biometric-only, and
            // LockType.none has nothing to shortcut into.
            final showsBiometricToggle =
                state.lockType == LockType.pin ||
                state.lockType == LockType.securityQuestion;

            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Expanded(
                    child: ClipPath(
                      clipper: const CloudTopClipper(),
                      child: Container(
                        width: double.infinity,
                        // A distinct tone from the tiles below
                        // (surfaceContainerHigh) — previously this and
                        // the tile background resolved to visually
                        // identical colors on several themes, making
                        // tiles disappear into the panel.
                        color: colorScheme.surfaceContainerLowest,
                        padding: const EdgeInsets.fromLTRB(20, 42, 20, 20),
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            for (final option in _options) ...[
                              _LockOptionTile(
                                data: option,
                                selected: state.lockType == option.type,
                                onTap: () => _onSelectLockType(option.type),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (showsBiometricToggle) ...[
                              const SizedBox(height: 6),
                              _BiometricShortcutToggle(
                                enabled: state.biometricEnabled,
                                onChanged: _onToggleBiometricShortcut,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LockOptionTile extends StatelessWidget {
  const _LockOptionTile({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _LockOptionData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Selection state (border/soft fill/checkmark) uses the theme's
    // own primary color, so the page still reskins with the rest of
    // the app; the icon itself uses its fixed, always-distinct color.
    final selectionAccent = colorScheme.primary;

    // DebouncedTap instead of a raw InkWell/Material — same rationale
    // as every other tappable list item in the app (see
    // core/navigation/debounced_tap.dart): a fast double-tap here would
    // otherwise be able to push the PIN-create / security-question-setup
    // route twice before the first transition finishes.
    return DebouncedTap(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // surfaceContainerHigh: a real, visible step up from the
          // surrounding panel's surfaceContainerLowest — previously
          // both resolved close enough that tiles were invisible.
          color: selected
              ? selectionAccent.withValues(alpha: 0.14)
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? selectionAccent.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerLowest,
              ),
              child: Icon(data.icon, color: data.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selectionAccent,
                ),
                child: Icon(Icons.check, size: 14, color: colorScheme.surface),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

/// The "also allow biometric" row — shown only when the primary lock
/// type is PIN or Security Question (see showsBiometricToggle above).
/// A switch, not a pushable tile: there's nothing to navigate to, it's
/// a direct on/off setting.
class _BiometricShortcutToggle extends StatelessWidget {
  const _BiometricShortcutToggle({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Matches Mobile Lock's fixed icon color, same as before.
    const accent = Color(0xFF5B8DEF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerLowest,
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biometric Shortcut',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Also allow face or fingerprint to unlock',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
