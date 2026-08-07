// lib/core/utils/downloads_directory_resolver.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Message [ExportCancelledException] carries — deliberately exported
/// as a constant so `BackupBloc` can recognize a cancelled save (and
/// quietly return to idle) without a red error, distinct from every
/// other export/import [Failure] which DOES get shown to the user. See
/// `BackupBloc`'s doc comment on `_emitBackupResult` for that check.
const String kExportCancelledMessage =
    'Export was cancelled — no file was saved.';

/// Thrown by [saveToDownloads] when the user dismisses the save-file
/// dialog instead of picking a location. Deliberately its own
/// exception type (rather than just returning null) so this can't be
/// silently conflated with a genuine write failure by any catch clause
/// downstream — see `BackupRepositoryImpl.exportBackup` and
/// `PdfExportRepositoryImpl.exportPdf`, both of which catch this
/// specifically, ahead of their generic `catch (e)`.
class ExportCancelledException implements Exception {
  const ExportCancelledException();

  @override
  String toString() => kExportCancelledMessage;
}

/// Lets the user choose exactly where a user-facing exported file (a
/// `.bubimo` backup, a PDF export) is saved, via the OS's native
/// save-file dialog, and writes [bytes] there.
///
/// # Why a picker dialog instead of a fixed Downloads folder
/// On Android (API 29+, scoped storage), there is no `dart:io`/`File`
/// path that reaches the device's real, public Downloads folder
/// directly — `path_provider`'s `getDownloadsDirectory()` silently
/// resolves to an app-private directory under
/// `Android/data/<package>/files/`, invisible to the Files app since
/// Android 11. Rather than reaching for `MediaStore` (native code,
/// always-Downloads, zero user choice) or `MANAGE_EXTERNAL_STORAGE`
/// (heavyweight, Play-Store-scrutinized), this uses `file_picker`'s
/// `saveFile` — already a dependency for backup import's file picker —
/// which opens Android's Storage Access Framework save dialog (backed
/// by MediaStore under the hood) and writes [bytes] to wherever the
/// user picks, no native code needed.
///
/// # Android/iOS ("mobile") vs. desktop
/// On Android and iOS, `file_picker` writes [bytes] to the chosen
/// location itself once [bytes] is passed to `saveFile`. On desktop
/// platforms, `saveFile` only returns the chosen (as yet non-existent)
/// path — the caller has to write the bytes there itself, which this
/// function does via `dart:io`.
///
/// Throws [ExportCancelledException] if the user dismisses the dialog
/// without choosing a location.
///
/// Returns the saved file's path, and `true` for
/// `savedToPublicDownloads` — always `true` on success now, since the
/// user explicitly chose an accessible location themselves rather than
/// this function silently falling back to an app-private folder. The
/// field is kept (rather than dropped) purely so [ExportResult] and
/// [PdfExportResult] don't need their shape changed.
Future<(String filePath, bool savedToPublicDownloads)> saveToDownloads({
  required Uint8List bytes,
  required String fileName,
  required List<String> allowedExtensions,
  String dialogTitle = 'Save export',
}) async {
  final isMobile = Platform.isAndroid || Platform.isIOS;

  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    // Only mobile platforms write [bytes] to the chosen location
    // themselves; passing it on desktop is harmless (ignored there)
    // but keeps this one call identical across every platform.
    bytes: bytes,
  );

  if (path == null) {
    throw const ExportCancelledException();
  }

  if (!isMobile) {
    // Desktop's saveFile only reserves the chosen path — the actual
    // write is on the caller, per file_picker's own documented
    // behavior for non-mobile platforms.
    await File(path).writeAsBytes(bytes);
  }

  return (path, true);
}