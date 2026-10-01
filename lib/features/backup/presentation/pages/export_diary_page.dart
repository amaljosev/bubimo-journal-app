// lib/features/backup/presentation/pages/export_diary_page.dart

import 'package:bubimo/features/backup/presentation/bloc/export/bloc/export_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../widgets/backup_result_dialog.dart';
import '../widgets/backup_section_card.dart';

/// Screen for downloading a readable copy of the diary as a PDF or a
/// plain-text file.
///
/// These are one-way exports — date, title and text only, no photos or
/// stickers — and can't be used to restore the diary. Restorable
/// backups live on the Local Backup screen (`BackupRestorePage`).
class ExportDiaryPage extends StatelessWidget {
  const ExportDiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ExportBloc>(),
      child: const _ExportDiaryView(),
    );
  }
}

class _ExportDiaryView extends StatelessWidget {
  const _ExportDiaryView();

  Future<void> _showResult(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showBackupResultDialog(context, title: title, message: message);
    if (context.mounted) {
      context.read<ExportBloc>().add(const ExportResultAcknowledged());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Diary')),
      body: BlocConsumer<ExportBloc, ExportState>(
        listenWhen: (previous, current) =>
            current.status == ExportStatus.pdfSuccess ||
            current.status == ExportStatus.textSuccess ||
            current.status == ExportStatus.failure,
        listener: (context, state) {
          switch (state.status) {
            case ExportStatus.pdfSuccess:
              final result = state.pdfExportResult!;
              _showResult(
                context,
                title: 'PDF ready',
                message:
                    '${entryCountLabel(result.entryCount)} saved as a PDF.\n\n'
                    '${savedLocationMessage(filePath: result.filePath, savedToPublicDownloads: result.savedToPublicDownloads)}',
              );
            case ExportStatus.textSuccess:
              final result = state.textExportResult!;
              _showResult(
                context,
                title: 'Text file ready',
                message:
                    '${entryCountLabel(result.entryCount)} saved as a text file.\n\n'
                    '${savedLocationMessage(filePath: result.filePath, savedToPublicDownloads: result.savedToPublicDownloads)}',
              );
            case ExportStatus.failure:
              _showResult(
                context,
                title: 'Something went wrong',
                message: state.errorMessage ?? 'Please try again.',
              );
            case ExportStatus.idle:
            case ExportStatus.exportingPdf:
            case ExportStatus.exportingText:
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
                icon: Icons.picture_as_pdf_outlined,
                title: 'PDF document',
                description:
                    'A neatly laid-out document, good for printing or '
                    'sharing. Each entry shows its date, title, and text.',
                note:
                    'Text in non-Latin scripts may not display correctly '
                    'in the PDF — use the text file for those.',
                buttonLabel: 'Download PDF',
                isLoading: state.status == ExportStatus.exportingPdf,
                isEnabled: !state.isBusy,
                onPressed: () =>
                    context.read<ExportBloc>().add(const ExportPdfRequested()),
              ),
              const SizedBox(height: 20),
              BackupSectionCard(
                icon: Icons.text_snippet_outlined,
                title: 'Plain text (.txt)',
                description:
                    'A simple text file that opens in any app, is easy to '
                    'copy from, and works with text in every language. '
                    'Entries are listed from oldest to newest.',
                buttonLabel: 'Download TXT',
                isLoading: state.status == ExportStatus.exportingText,
                isEnabled: !state.isBusy,
                onPressed: () => context
                    .read<ExportBloc>()
                    .add(const ExportTextRequested()),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Always-visible reminder of what these exports contain and that they
/// aren't backups, so nobody tries to restore from one.
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
              'These are readable copies of your diary — date, title, and '
              'text only. Photos and stickers aren\'t included, and you '
              'can\'t restore your diary from them. To save a copy you can '
              'restore later, use Local Backup in Settings.',
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