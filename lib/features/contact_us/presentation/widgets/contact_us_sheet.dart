// lib/features/contact_us/presentation/widgets/contact_us_sheet.dart

import 'package:flutter/material.dart';

import 'package:bubimo/core/di/injection.dart';
import 'package:bubimo/features/contact_us/domain/contact_reason.dart';
import 'package:bubimo/features/contact_us/domain/usecases/send_support_email.dart';

/// Bottom sheet offering contact options (Feedback, Support, Bug
/// Report, Feature Suggestion), each launching the device mail client
/// with a prefilled subject.
///
/// Plain StatelessWidget — no bloc needed, this has no state to manage
/// beyond a one-shot fire-and-forget action per tile.
class ContactUsSheet extends StatelessWidget {
  const ContactUsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              height: 5,
              width: 50,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            for (final reason in ContactReason.values)
              _ContactOptionTile(
                reason: reason,
                onTap: () {
                  Navigator.pop(context);
                  _sendEmail(context, reason);
                },
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _sendEmail(BuildContext context, ContactReason reason) async {
    final result = await getIt<SendSupportEmail>().call(reason);

    result.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
      (_) {},
    );
  }
}

class _ContactOptionTile extends StatelessWidget {
  final ContactReason reason;
  final VoidCallback onTap;

  const _ContactOptionTile({required this.reason, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconFor(reason), color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reason.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ContactReason reason) {
    switch (reason) {
      case ContactReason.feedback:
        return Icons.rate_review_outlined;
      case ContactReason.support:
        return Icons.support_agent_outlined;
      case ContactReason.bugReport:
        return Icons.bug_report_outlined;
      case ContactReason.featureSuggestion:
        return Icons.lightbulb_outline;
    }
  }
}