// lib/features/backup/presentation/widgets/backup_result_dialog.dart

import 'package:flutter/material.dart';

/// Shows the simple one-button result/error dialog used by both the
/// Local Backup and Export Diary screens. Resolves once dismissed.
Future<void> showBackupResultDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// "Saved to your Downloads folder: <path>" — or the app-storage
/// fallback wording when the device didn't expose Downloads.
String savedLocationMessage({
  required String filePath,
  required bool savedToPublicDownloads,
}) {
  return savedToPublicDownloads
      ? 'Saved to your Downloads folder:\n$filePath'
      : 'Saved inside the app\'s own storage (your device didn\'t make '
          'its Downloads folder available):\n$filePath';
}

/// "1 entry" / "5 entries".
String entryCountLabel(int count) => '$count ${count == 1 ? 'entry' : 'entries'}';