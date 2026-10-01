// lib/features/backup/data/datasources/pdf_export_data_source.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/diary_export_utils.dart';
import '../../../../core/utils/downloads_directory_resolver.dart';
import '../../../diary_entry/data/datasources/diary_local_data_source.dart';
import '../../../diary_entry/domain/entities/diary_entry.dart';
import '../../domain/entities/pdf_export_result.dart';

/// File extension for the generated human-readable export.
const String kPdfExportFileExtension = '.pdf';

/// Builds a plain, human-readable PDF of every non-deleted diary
/// entry — date, title, and body text ONLY. No photos, stickers,
/// backgrounds, or styling are included, by explicit design: this is a
/// document meant to be read, shared, or printed, not a backup (see
/// `BackupLocalDataSource` for the actual round-trip able `.bubimo`
/// format, which DOES carry every image). Mixing the two concerns into
/// one file format would blur what each is actually for.
///
/// Title/body/date formatting lives in [DiaryExportUtils], shared with
/// `TextExportDataSource`.
///
/// KNOWN LIMITATION: uses the `pdf` package's default Helvetica font,
/// which only renders Latin-script text correctly. Entries containing
/// non-Latin scripts (e.g. Arabic, Devanagari, CJK) will not render
/// correctly until a bundled Unicode TTF font is added — out of scope
/// for this pass since no such font asset exists in this project yet.
/// The plain-text export has no such limit.
class PdfExportDataSource {
  final DiaryLocalDataSource diaryLocalDataSource;

  const PdfExportDataSource(this.diaryLocalDataSource);

  Future<PdfExportResult> createPdf() async {
    final entries = await diaryLocalDataSource.getAllEntries();

    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              'My Diary',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
          ];

          for (final entry in entries) {
            widgets.add(_buildEntrySection(entry));
          }

          return widgets;
        },
      ),
    );

    final bytes = await document.save();

    final fileName =
        'bubimo_diary_${DiaryExportUtils.fileTimestamp()}$kPdfExportFileExtension';
    final (filePath, savedToPublicDownloads) = await saveToDownloads(
      bytes: bytes,
      fileName: fileName,
      allowedExtensions: const ['pdf'],
      dialogTitle: 'Save PDF',
    );

    return PdfExportResult(
      filePath: filePath,
      entryCount: entries.length,
      savedToPublicDownloads: savedToPublicDownloads,
    );
  }

  pw.Widget _buildEntrySection(DiaryEntry entry) {
    final title = DiaryExportUtils.displayTitle(entry.title);
    final body = DiaryExportUtils.extractPlainText(entry.content ?? '');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            DiaryExportUtils.formatDate(entry.date),
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (body.isNotEmpty)
            pw.Text(body, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ],
      ),
    );
  }
}