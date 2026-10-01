// lib/features/backup/data/datasources/text_export_data_source.dart

import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/utils/diary_export_utils.dart';
import '../../../../core/utils/downloads_directory_resolver.dart';
import '../../../diary_entry/data/datasources/diary_local_data_source.dart';
import '../../domain/entities/text_export_result.dart';

/// File extension for the generated plain-text export.
const String kTextExportFileExtension = '.txt';

/// Builds a plain UTF-8 text file of every non-deleted diary entry —
/// date, title, and body text ONLY, matching [PdfExportDataSource]'s
/// content rules (no photos, stickers, backgrounds or styling). Like
/// the PDF, this is a readable copy, not a backup.
///
/// Entries are written oldest-first so the file reads like a diary from
/// start to finish. Unlike the PDF, UTF-8 text has no script
/// limitation, so non-Latin entries export correctly.
class TextExportDataSource {
  final DiaryLocalDataSource diaryLocalDataSource;

  const TextExportDataSource(this.diaryLocalDataSource);

  static const String _entryDivider = '----------------------------------------';

  Future<TextExportResult> createText() async {
    final entries = List.of(await diaryLocalDataSource.getAllEntries())
      ..sort((a, b) => a.date.compareTo(b.date));

    final buffer = StringBuffer();
    buffer.writeln('My Diary');
    buffer.writeln('========');
    buffer.writeln();

    for (final entry in entries) {
      final body = DiaryExportUtils.extractPlainText(entry.content ?? '');

      buffer.writeln(DiaryExportUtils.formatDate(entry.date));
      buffer.writeln(DiaryExportUtils.displayTitle(entry.title));
      if (body.isNotEmpty) {
        buffer.writeln();
        buffer.writeln(body);
      }
      buffer.writeln();
      buffer.writeln(_entryDivider);
      buffer.writeln();
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));

    final fileName =
        'bubimo_diary_${DiaryExportUtils.fileTimestamp()}$kTextExportFileExtension';
    final (filePath, savedToPublicDownloads) = await saveToDownloads(
      bytes: bytes,
      fileName: fileName,
      allowedExtensions: const ['txt'],
      dialogTitle: 'Save text file',
    );

    return TextExportResult(
      filePath: filePath,
      entryCount: entries.length,
      savedToPublicDownloads: savedToPublicDownloads,
    );
  }
}