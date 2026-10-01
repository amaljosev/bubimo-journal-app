// lib/features/backup/presentation/widgets/backup_section_card.dart

import 'package:flutter/material.dart';

/// A soft, rounded card for one action (create backup, restore, export
/// as PDF, export as text) — matches the app's existing surface
/// language (`colorScheme.surface`, low-alpha shadow rather than
/// Material elevation, generous rounded corners).
///
/// Shared by the Local Backup and Export Diary screens so both look and
/// behave identically.
class BackupSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  /// Optional smaller, muted line under [description] for a caveat.
  final String? note;
  final String buttonLabel;
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;

  const BackupSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: isEnabled ? onPressed : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}