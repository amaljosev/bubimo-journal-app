// lib/features/app_lock/presentation/pages/pin_lock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/lock_bloc.dart';
import '../widgets/lock_palette.dart';

enum LockMode { create, verify }

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, required this.mode});

  final LockMode mode;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  String _entered = '';
  String _firstPin = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(String d) {
    if (_entered.length >= 4) return;

    setState(() {
      _entered += d;
      _error = '';
    });

    if (_entered.length != 4) return;

    if (widget.mode == LockMode.create) {
      _handleCreateStep();
    } else {
      context.read<LockBloc>().add(VerifyPinAttempt(_entered));
    }
  }

  void _handleCreateStep() {
    if (_firstPin.isEmpty) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() {
          _firstPin = _entered;
          _entered = '';
        });
      });
      return;
    }

    if (_firstPin == _entered) {
      context.pop(_entered);
    } else {
      _showError('PIN mismatch');
      _firstPin = '';
      _entered = '';
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _showError(String message) {
    setState(() => _error = message);
    _shakeController.forward(from: 0.0);
  }

  void _useBiometricShortcut() {
    context.read<LockBloc>().add(
      const VerifyBiometricAttempt(reason: 'Unlock with biometrics instead'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == LockMode.create;

    if (!isCreate) {
      return BlocListener<LockBloc, AppLockState>(
        listenWhen: (previous, current) =>
            previous.verificationStatus != current.verificationStatus,
        listener: (context, state) {
          if (state.verificationStatus == VerificationStatus.failure) {
            _showError(state.verificationError ?? 'Wrong PIN');
            _entered = '';
            context.read<LockBloc>().add(const ResetVerification());
          }
          // On success this screen doesn't navigate itself — whatever
          // hosts it (e.g. a lock-gate widget higher in the tree)
          // reacts to verificationStatus == success. Same contract as
          // pushing this screen directly for a one-off re-verification.
        },
        child: _buildContent(context, isCreate),
      );
    }

    return _buildContent(context, isCreate);
  }

  Widget _buildContent(BuildContext context, bool isCreate) {
    final colorScheme = Theme.of(context).colorScheme;
    // secondaryColor is this app's dedicated "accent highlight" role
    // (see theme_mapper.dart's doc comment on AppThemeData.secondary
    // Color: "Accent highlights, like the colored bar on diary
    // entries") — the right theme slot for the PIN dots/keypad accent,
    // rather than a fixed literal that wouldn't reskin with the rest
    // of the app.
    final accent = colorScheme.secondary;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surfaceContainerHighest,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                title: isCreate
                    ? (_firstPin.isEmpty ? 'Set PIN' : 'Confirm PIN')
                    : 'Enter PIN',
                // Verify mode (LockMode.verify) is how LockGate renders
                // this screen — built INLINE at the lock-gate route,
                // never pushed on top of anything, so there is nothing
                // for a back button to pop to there. Only show back in
                // create mode, where this screen is always reached via
                // context.push from AppLockSettingsPage and popping is
                // valid. Mirrors how SecurityQuestionPage already hides
                // its back button whenever isVerification is true.
                onBack: isCreate ? () => context.pop() : null,
              ),
              const SizedBox(height: 6),
              Text(
                isCreate
                    ? (_firstPin.isEmpty
                          ? 'Create a 4-digit PIN'
                          : 'Type it again to confirm')
                    : 'Enter your 4-digit PIN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _entered.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? colorScheme.onSurface : colorScheme.surface,
                        border: Border.all(
                          color: isFilled ? accent : accent.withValues(alpha: 0.35),
                          width: 1.4,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),
              // Was a hard SizedBox(height: 32) — that's enough room
              // for one line of error text, but a real TextButton.icon
              // (icon + label + its own internal padding, ~36-48px
              // min touch target) doesn't fit in 32px and overflowed
              // the moment the biometric shortcut button appeared
              // alongside it. This region now sizes itself to whatever
              // it's actually showing (nothing / error text / the
              // shortcut button) instead of being pinned to a height
              // that only ever fit the error case.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _error.isNotEmpty
                      ? Center(
                          child: Text(
                            _error,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.error,
                            ),
                          ),
                        )
                      // Biometric shortcut only ever shown on the
                      // verify path (not while creating a new PIN), and
                      // only when AppLockState.showsBiometricShortcut
                      // is true (biometricEnabled AND lockType is pin).
                      : (!isCreate)
                      ? BlocBuilder<LockBloc, AppLockState>(
                          buildWhen: (previous, current) =>
                              previous.showsBiometricShortcut != current.showsBiometricShortcut,
                          builder: (context, state) {
                            if (!state.showsBiometricShortcut) {
                              return const SizedBox.shrink();
                            }
                            return Center(
                              child: TextButton.icon(
                                onPressed: _useBiometricShortcut,
                                style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                                label: const Text(
                                  'Use biometrics instead',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ClipPath(
                  clipper: const CloudTopClipper(),
                  child: Container(
                    width: double.infinity,
                    // Distinct tone from the keypad keys below
                    // (surfaceContainerLowest vs. the accent-tinted
                    // keys) — same panel/tile separation used on
                    // AppLockSettingsPage, so keys don't blend into
                    // the panel on themes where a flat white panel
                    // and pastel-pink keys would otherwise sit too
                    // close in luminance.
                    color: colorScheme.surfaceContainerLowest,
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
                    child: Center(child: _buildKeypad(colorScheme, accent)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ColorScheme colorScheme, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int col = 1; col <= 3; col++)
                  _buildKey('${row * 3 + col}', colorScheme, accent),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 78),
              _buildKey('0', colorScheme, accent),
              _buildBackspaceKey(colorScheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String digit, ColorScheme colorScheme, Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 68,
      height: 68,
      child: Material(
        // A real, visible tint of the theme's secondary color — not
        // tied to surfaceContainerHigh, since these keys are meant to
        // read as "accent-colored" rather than neutral. 0.16 alpha
        // keeps it looking intentional on both light and dark
        // surfaceContainerLowest panels instead of washing out or
        // over-saturating on either.
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(34),
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: () => _addDigit(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 68,
      height: 68,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(34),
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: _backspace,
          child: Center(
            child: Icon(
              Icons.backspace_rounded,
              size: 24,
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colorScheme.onSurface,
                size: 20,
              ),
            ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}