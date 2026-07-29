// lib/features/diary_entry/presentation/pages/diary_entry_view_page.dart

import 'package:bubimo/core/router/app_router.dart';
import 'package:bubimo/core/utils/background_image_utils.dart';
import 'package:bubimo/core/utils/overlay_tint_utils.dart';
import 'package:bubimo/core/utils/quill_document_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/error_screen.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/usecases/delete_diary_entry.dart';
import '../../domain/usecases/get_diary_entry_by_id.dart';
import '../../domain/usecases/update_diary_entry.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/overlay/overlay_image_view.dart';
import '../widgets/overlay/resizable_image_embed_builder.dart';
import '../widgets/overlay/sticker_overlay_view.dart';
import '../widgets/diary_bottom_toolbar.dart' show DividerEmbedBuilder;

/// Displays a single diary entry in full, with favorite toggle, edit,
/// and delete actions.
///
/// This screen has no dedicated bloc — it loads the entry directly via
/// [GetDiaryEntryById] and mutates it via the same generic
/// [UpdateDiaryEntry]/[DeleteDiaryEntry] use cases every other feature
/// uses, since its state is simple enough not to warrant one.
///
/// Pops with `true` if anything changed (favorite toggled, entry
/// edited, or entry deleted) so Home knows to refresh its list; pops
/// with `false` if the user just navigated back with no changes.
class DiaryEntryViewPage extends StatefulWidget {
  final String entryId;

  const DiaryEntryViewPage({super.key, required this.entryId});

  @override
  State<DiaryEntryViewPage> createState() => _DiaryEntryViewPageState();
}

class _DiaryEntryViewPageState extends State<DiaryEntryViewPage> {
  final GetDiaryEntryById _getDiaryEntryById = getIt<GetDiaryEntryById>();
  final UpdateDiaryEntry _updateDiaryEntry = getIt<UpdateDiaryEntry>();
  final DeleteDiaryEntry _deleteDiaryEntry = getIt<DeleteDiaryEntry>();

  DiaryEntry? _entry;
  quill.QuillController? _viewController;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isTogglingFavorite = false;
  bool _isDeleting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _viewController?.dispose();
    super.dispose();
  }

  /// Mirrors `_DiaryFormViewState._colorFromHex` in diary_form_page.dart.
  Color? _colorFromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  /// Mirrors `_DiaryFormViewState._textAlignFor` in diary_form_page.dart
  /// — keeps wrapped title text aligned the same way the form did.
  TextAlign _textAlignFor(String alignment) {
    switch (alignment) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  /// Positions the mood/title/date block as a whole — 'justify' has no
  /// positional equivalent, so it falls back to start like 'left'.
  CrossAxisAlignment _crossAxisFor(String alignment) {
    switch (alignment) {
      case 'center':
        return CrossAxisAlignment.center;
      case 'right':
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }

  Future<void> _loadEntry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _getDiaryEntryById(widget.entryId);

    if (!mounted) return;

    result.match(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (entry) => setState(() {
        _isLoading = false;
        _entry = entry;
        _viewController?.dispose();
        _viewController = quill.QuillController(
          document: QuillDocumentUtils.documentFromContent(entry.content ?? ''),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      }),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite || _entry == null) return;

    setState(() => _isTogglingFavorite = true);

    final updated = _entry!.copyWith(
      isFavorite: !_entry!.isFavorite,
      updatedAt: DateTime.now(),
    );
    final result = await _updateDiaryEntry(updated);

    if (!mounted) return;

    result.match(
      (failure) {
        setState(() => _isTogglingFavorite = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) => setState(() {
        _entry = updated;
        _isTogglingFavorite = false;
        _hasChanges = true;
      }),
    );
  }

  Future<void> _editEntry() async {
    final result = await context.push<bool>(
      AppRoutes.diaryForm,
      extra: widget.entryId,
    );

    if (result == true) {
      _hasChanges = true;
      await _loadEntry();
    }
  }

  Future<void> _deleteEntry() async {
    if (_isDeleting) return;

    final confirmed = await showConfirmDeleteDialog(context);
    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    final result = await _deleteDiaryEntry(widget.entryId);

    if (!mounted) return;

    result.match((failure) {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }, (_) => context.pop(true));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.pop(_hasChanges);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Diary Entry'),
          actions: _entry == null
              ? null
              : [
                  IconButton(
                    icon: _isTogglingFavorite
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _entry!.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                    onPressed: _isTogglingFavorite ? null : _toggleFavorite,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _editEntry,
                  ),
                  IconButton(
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    onPressed: _isDeleting ? null : _deleteEntry,
                  ),
                ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingScreen();

    if (_errorMessage != null) {
      return ErrorScreen(message: _errorMessage!, onRetry: _loadEntry);
    }

    final entry = _entry!;
    final backgroundImage = BackgroundImageUtils.resolveProvider(
      bgGalleryImagePath: entry.bgGalleryImagePath,
      bgImagePath: entry.bgImagePath,
      bgLocalPath: entry.bgLocalPath,
    );

    return Container(
      decoration: backgroundImage != null
          ? BoxDecoration(
              image: DecorationImage(
                image: backgroundImage,
                fit: BoxFit.cover,
                colorFilter: OverlayTintUtils.resolveColorFilter(
                  bgOverlayColor: entry.bgOverlayColor,
                  themeBrightness: Theme.of(context).brightness,
                  opacity: entry.bgOverlayOpacity,
                ),
              ),
            )
          : null,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // Fixed header: mood, title, date — positioned as a block
            // per the entry's alignment, with the title carrying the
            // entry's whole-entry text style (bold/italic/underline/
            // size/color), matching how the form's title field applies
            // the same state fields — see `DiaryFormTitleField`.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: _crossAxisFor(entry.alignment),
                  children: [
                  if (entry.mood != null)
                    Text(
                      entry.mood!.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final baseStyle =
                          Theme.of(context).textTheme.headlineSmall;
                      return Text(
                        entry.title?.isNotEmpty == true
                            ? entry.title!
                            : 'Untitled',
                        textAlign: _textAlignFor(entry.alignment),
                        style: baseStyle?.copyWith(
                          fontWeight: entry.isBold
                              ? FontWeight.w900
                              : baseStyle.fontWeight,
                          fontStyle: entry.isItalic
                              ? FontStyle.italic
                              : FontStyle.normal,
                          decoration: entry.isUnderline
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          fontSize: entry.fontSize != null
                              ? double.tryParse(entry.fontSize!)
                              : baseStyle.fontSize,
                          color: entry.textColorHex != null
                              ? _colorFromHex(entry.textColorHex!)
                              : baseStyle.color,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppDateUtils.toDisplayString(entry.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                ),
              ),
            ),
            // Description area: editor + sticker/overlay stack
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: _viewController == null
                    ? const SizedBox.shrink()
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          quill.QuillEditor.basic(
                            controller: _viewController!,
                            config: quill.QuillEditorConfig(
                              embedBuilders: [
                                ResizableImageEmbedBuilder(),
                                DividerEmbedBuilder(),
                                ...FlutterQuillEmbeds.editorBuilders(),
                              ],
                            ),
                          ),
                          for (final image in entry.overlayImages)
                            OverlayImageView(
                              key: ValueKey('image_${image.id}'),
                              image: image,
                            ),
                          for (final sticker in entry.stickers)
                            StickerOverlayView(
                              key: ValueKey('sticker_${sticker.id}'),
                              sticker: sticker,
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}