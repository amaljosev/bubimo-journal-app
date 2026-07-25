// lib/features/backup/presentation/pages/backup_restore_page.dart

import 'package:bubimo/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';

/// Single screen for creating a local backup (`.bubimo` file),
/// restoring diary entries from one, and downloading a human-readable
/// PDF — see `app_drawer.dart`'s `onExportTap` wiring. Deliberately one
/// screen for all three rather than separate ones (see [BackupBloc]'s
/// doc comment) — the drawer's separate "Backup" item is reserved for
/// a future cloud-sync feature and intentionally left unwired by this
/// feature.
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

  Future<void> _handleDownloadPdf(BuildContext context) async {
    context.read<BackupBloc>().add(const PdfExportRequested());
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
        appBar: AppBar(title: const Text('Import & Export')),
        body: BlocConsumer<BackupBloc, BackupState>(
          listenWhen: (previous, current) =>
              current.status == BackupStatus.exportSuccess ||
              current.status == BackupStatus.importSuccess ||
              current.status == BackupStatus.pdfExportSuccess ||
              current.status == BackupStatus.failure,
          listener: (context, state) {
            switch (state.status) {
              case BackupStatus.exportSuccess:
                _showResultDialog(
                  context,
                  title: 'Backup created',
                  message: state.exportResult!.savedToPublicDownloads
                      ? 'Saved to your Downloads folder:\n'
                          '${state.exportResult!.filePath}'
                      : 'Saved inside the app\'s own storage (your device '
                          'didn\'t make its Downloads folder available):\n'
                          '${state.exportResult!.filePath}',
                );
              case BackupStatus.importSuccess:
                setState(() => _hasImportedEntries = true);
                final result = state.importResult!;
                _showResultDialog(
                  context,
                  title: 'Import complete',
                  message: result.skippedCount == 0
                      ? 'Added ${result.importedCount} ${result.importedCount == 1 ? 'entry' : 'entries'} to your diary.'
                      : 'Added ${result.importedCount} ${result.importedCount == 1 ? 'entry' : 'entries'} to your diary. '
                          '${result.skippedCount} ${result.skippedCount == 1 ? 'entry' : 'entries'} in the file '
                          'couldn\'t be read and ${result.skippedCount == 1 ? 'was' : 'were'} skipped.',
                );
              case BackupStatus.pdfExportSuccess:
                final result = state.pdfExportResult!;
                _showResultDialog(
                  context,
                  title: 'PDF ready',
                  message:
                      '${result.entryCount} ${result.entryCount == 1 ? 'entry' : 'entries'} saved as a readable PDF.\n\n'
                      '${result.savedToPublicDownloads ? 'Saved to your Downloads folder:' : 'Saved inside the app\'s own storage (your device didn\'t make its Downloads folder available):'}\n'
                      '${result.filePath}',
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
            case BackupStatus.exportingPdf:
              break;
          }
        },
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              _InfoBanner(colorScheme: colorScheme, textTheme: textTheme),
              const SizedBox(height: 20),
              _SectionCard(
                icon: Icons.ios_share_rounded,
                title: 'Backup',
                description:
                    'Creates a backup file containing every diary entry '
                    '— including photos, stickers, and backgrounds. This '
                    'file is only for restoring your diary later; it '
                    'isn\'t meant to be opened or read directly.',
                buttonLabel: 'Create backup',
                isLoading: state.status == BackupStatus.exporting,
                isEnabled: !state.isBusy,
                onPressed: () => _handleExport(context),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 20),
              _SectionCard(
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
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 20),
              _SectionCard(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Download as PDF',
                description:
                    'Creates a readable document with each entry\'s '
                    'date, title, and text — no photos or stickers. '
                    'Open it, share it, or print it. This is not a '
                    'backup and can\'t be used to restore your diary.',
                buttonLabel: 'Download PDF',
                isLoading: state.status == BackupStatus.exportingPdf,
                isEnabled: !state.isBusy,
                onPressed: () => _handleDownloadPdf(context),
                colorScheme: colorScheme,
                textTheme: textTheme,
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
    await showDialog<void>(
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
    if (context.mounted) {
      context.read<BackupBloc>().add(const BackupResultAcknowledged());
    }
  }
}

/// A short, always-visible explanation of the difference between a
/// backup and a PDF export, shown above both sections so the choice is
/// clear before the user taps anything — addresses the two options
/// otherwise reading as near-duplicates ("Export" vs "Download as
/// PDF") at a glance.
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
            child: RichText(
              text: TextSpan(
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: 'Backup',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' saves everything so you can restore your diary '
                        'later — it\'s not something you open and read. ',
                  ),
                  TextSpan(
                    text: 'Download as PDF',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' makes a readable copy of your entries to view, '
                        'share, or print.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft, rounded card for one action (export or import) — matches the
/// app's existing surface language (`colorScheme.surface`, low-alpha
/// shadow rather than Material elevation, generous rounded corners) per
/// `AppDrawer`'s and `DiaryBottomToolbar`'s established styling.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
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
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}