// lib/features/backup/presentation/pages/backup_restore_page.dart

import 'package:bubimo/features/backup/presentation/bloc/backup/backup_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../widgets/backup_result_dialog.dart';
import '../widgets/backup_section_card.dart';

/// Screen for creating a local backup (`.bubimo` file) and restoring
/// diary entries from one.
///
/// Readable exports (PDF / TXT) used to live here too, but a backup you
/// restore from and a copy you read looked too alike on one screen —
/// they now have their own screen, `ExportDiaryPage`.
class BackupRestorePage extends StatelessWidget {
  const BackupRestorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BackupBloc>(),
      child: const _BackupRestoreView(),
    );
  }
}

class _BackupRestoreView extends StatefulWidget {
  const _BackupRestoreView();

  @override
  State<_BackupRestoreView> createState() => _BackupRestoreViewState();
}

class _BackupRestoreViewState extends State<_BackupRestoreView> {
  /// True once a local `.bubimo` import has completed successfully
  /// during this visit. Reported back to whoever pushed this route
  /// (see `home_page.dart`'s `_openImportExport`) so Home knows to
  /// refresh its entry list — same reasoning as
  /// `CloudBackupPage._hasRestoredEntries`: `MainShell` keeps
  /// `DiaryListBloc` alive for its whole lifetime, so nothing
  /// re-fetches automatically just because this screen was popped.
  bool _hasImportedEntries = false;

  Future<void> _handleExport(BuildContext context) async {
    context.read<BackupBloc>().add(const BackupExportRequested());
  }

  Future<void> _handleImport(BuildContext context) async {
    // File selection is a presentation-layer concern — the bloc only
    // ever receives an already-resolved path (see
    // BackupImportRequested's doc comment).
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      // FileType.custom + allowedExtensions would be more precise (only
      // showing .bubimo files), but file_picker's custom-extension
      // filtering does not reliably surface files with the app's own
      // non-standard extension across every Android file-manager
      // implementation the OS picker can launch. FileType.any avoids
      // a confusing "no files found" experience if the user's chosen
      // file manager doesn't honor the extension filter; the imported
      // file's contents are validated by the manifest check regardless
      // (see BackupLocalDataSource.importBackup) rather than relying
      // on the extension at all as a safety mechanism.
    );

    final pickedPath = result?.files.single.path;
    if (pickedPath == null || !context.mounted) return;

    context.read<BackupBloc>().add(BackupImportRequested(pickedPath));
  }

  Future<void> _showImportConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
          'Entries from the backup file will be added as new diary '
          'entries. Nothing already in your diary will be changed or '
          'removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _handleImport(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_hasImportedEntries);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Local Backup')),
        body: BlocConsumer<BackupBloc, BackupState>(
          listenWhen: (previous, current) =>
              current.status == BackupStatus.exportSuccess ||
              current.status == BackupStatus.importSuccess ||
              current.status == BackupStatus.failure,
          listener: (context, state) {
            switch (state.status) {
              case BackupStatus.exportSuccess:
                _showResultDialog(
                  context,
                  title: 'Backup created',
                  message: savedLocationMessage(
                    filePath: state.exportResult!.filePath,
                    savedToPublicDownloads:
                        state.exportResult!.savedToPublicDownloads,
                  ),
                );
              case BackupStatus.importSuccess:
                setState(() => _hasImportedEntries = true);
                final result = state.importResult!;
                _showResultDialog(
                  context,
                  title: 'Import complete',
                  message: result.skippedCount == 0
                      ? 'Added ${entryCountLabel(result.importedCount)} to your diary.'
                      : 'Added ${entryCountLabel(result.importedCount)} to your diary. '
                          '${entryCountLabel(result.skippedCount)} in the file '
                          'couldn\'t be read and ${result.skippedCount == 1 ? 'was' : 'were'} skipped.',
                );
              case BackupStatus.failure:
                _showResultDialog(
                  context,
                  title: 'Something went wrong',
                  message: state.errorMessage ?? 'Please try again.',
                );
              case BackupStatus.idle:
              case BackupStatus.exporting:
              case BackupStatus.importing:
                break;
            }
          },
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                _InfoBanner(colorScheme: colorScheme, textTheme: textTheme),
                const SizedBox(height: 20),
                BackupSectionCard(
                  icon: Icons.ios_share_rounded,
                  title: 'Create backup',
                  description:
                      'Creates a backup file containing every diary entry '
                      '— including photos, stickers, and backgrounds. This '
                      'file is only for restoring your diary later; it '
                      'isn\'t meant to be opened or read directly.',
                  buttonLabel: 'Create backup',
                  isLoading: state.status == BackupStatus.exporting,
                  isEnabled: !state.isBusy,
                  onPressed: () => _handleExport(context),
                ),
                const SizedBox(height: 20),
                BackupSectionCard(
                  icon: Icons.file_download_outlined,
                  title: 'Restore from backup',
                  description:
                      'Add entries from a previously created backup file. '
                      'Existing entries are never changed or removed — '
                      'restored entries are always added alongside what\'s '
                      'already in your diary, keeping their original dates.',
                  buttonLabel: 'Choose backup file',
                  isLoading: state.status == BackupStatus.importing,
                  isEnabled: !state.isBusy,
                  onPressed: () => _showImportConfirmation(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showResultDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showBackupResultDialog(context, title: title, message: message);
    if (context.mounted) {
      context.read<BackupBloc>().add(const BackupResultAcknowledged());
    }
  }
}

/// A short, always-visible explanation of what a backup file is for,
/// pointing readers who want a readable copy to the separate export
/// screen.
class _InfoBanner extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _InfoBanner({required this.colorScheme, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'A backup saves everything so you can restore your diary '
              'later — it\'s not something you open and read. For a '
              'readable copy, use Export as PDF or Text in Settings.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}