// lib/features/app_lock/presentation/pages/security_question_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/lock_bloc.dart';
import '../widgets/lock_palette.dart';

/// Handles both directions of the security-question flow:
/// - Setup ([isVerification] = false): user writes their own question
///   and answer, popping with `{'question': ..., 'answer': ...}` for
///   AppLockSettingsPage to persist via SetLockType.
/// - Verification ([isVerification] = true): shows the stored question
///   (from AppLockState.securityQuestion) and dispatches
///   VerifySecurityAnswerAttempt on submit. Also offers a biometric
///   shortcut button when AppLockState.showsBiometricShortcut is true.
class SecurityQuestionPage extends StatefulWidget {
  const SecurityQuestionPage({super.key, required this.isVerification});

  final bool isVerification;

  @override
  State<SecurityQuestionPage> createState() => _SecurityQuestionPageState();
}

class _SecurityQuestionPageState extends State<SecurityQuestionPage> {
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _error = '';

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (widget.isVerification) {
      final answer = _answerController.text.trim();
      if (answer.isEmpty) return;
      context.read<LockBloc>().add(VerifySecurityAnswerAttempt(answer));
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.pop({
      'question': _questionController.text.trim(),
      'answer': _answerController.text.trim(),
    });
  }

  void _useBiometricShortcut() {
    context.read<LockBloc>().add(
      const VerifyBiometricAttempt(reason: 'Unlock with biometrics instead'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.isVerification
        ? _buildVerifyForm()
        : _buildSetupForm();

    if (!widget.isVerification) {
      return _scaffold(context, content);
    }

    return BlocListener<LockBloc, AppLockState>(
      listenWhen: (previous, current) =>
          previous.verificationStatus != current.verificationStatus,
      listener: (context, state) {
        if (state.verificationStatus == VerificationStatus.failure) {
          setState(
            () => _error = state.verificationError ?? 'Incorrect answer',
          );
          context.read<LockBloc>().add(const ResetVerification());
        }
        // Success is handled by whatever ancestor hosts this screen
        // (e.g. a lock-gate widget) — this screen just reports the
        // attempt via the bloc.
      },
      child: _scaffold(context, content),
    );
  }

  Widget _scaffold(BuildContext context, Widget content) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        title: Text(
          widget.isVerification
              ? 'Answer to unlock'
              : 'Set a Security Question',
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
            colors: [colorScheme.surfaceContainerHighest, colorScheme.surface],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ClipPath(
                  clipper: const CloudTopClipper(),
                  child: Container(
                    width: double.infinity,
                    color: colorScheme.surface,
                    padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupForm() {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your question',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                cursorColor: Colors.amber,
                controller: _questionController,
                maxLines: null,
                maxLength: 100,
                style: TextStyle(color: colorScheme.onPrimary),
                decoration: _inputDecoration(
                  context,
                  'e.g. What street did you grow up on?',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a question'
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                'Your answer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _answerController,
                cursorColor: Colors.amber,              
                style: TextStyle(color: colorScheme.onPrimary),
                obscureText: true,
                decoration: _inputDecoration(context, 'Answer'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter an answer'
                    : null,
              ),
              const Spacer(),
              _buildSubmitButton(context, 'Save'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerifyForm() {
    return BlocBuilder<LockBloc, AppLockState>(
      buildWhen: (previous, current) =>
          previous.securityQuestion != current.securityQuestion ||
          previous.showsBiometricShortcut != current.showsBiometricShortcut,
      builder: (context, state) {
        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.securityQuestion ?? 'Your security question',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _answerController,
              obscureText: true,
              autofocus: true,
              onFieldSubmitted: (_) => _onSubmit(),
              decoration: _inputDecoration(context, 'Your answer'),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _error,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
              ),
            ],
            if (state.showsBiometricShortcut) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: _useBiometricShortcut,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  icon: const Icon(Icons.fingerprint_rounded, size: 18),
                  label: const Text(
                    'Use biometrics instead',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            const Spacer(),
            _buildSubmitButton(context, 'Unlock'),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colorScheme.onSurface),
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildSubmitButton(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
