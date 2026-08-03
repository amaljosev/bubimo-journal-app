// lib/features/diary_entry/presentation/pages/diary_form_page.dart

import 'dart:async';

import 'package:bubimo/core/utils/background_image_utils.dart';
import 'package:bubimo/core/utils/overlay_tint_utils.dart';
import 'package:bubimo/core/utils/quill_document_utils.dart';
import 'package:bubimo/features/diary_entry/presentation/widgets/diary_bottom_toolbar.dart';
import 'package:bubimo/features/diary_entry/presentation/widgets/diary_form/date_picker_widget.dart';
import 'package:bubimo/features/diary_entry/presentation/widgets/diary_form/diary_form_header.dart';
import 'package:bubimo/features/diary_entry/presentation/widgets/diary_form/diary_form_overlay_settings_sheet.dart';
import 'package:bubimo/features/diary_entry/presentation/widgets/mood_popover.dart';
import 'package:bubimo/features/diary_entry/presentation/widgets/overlay/overlay_layer.dart';
import 'package:bubimo/features/diary_entry/presentation/widgets/overlay/resizable_image_embed_builder.dart';
import 'package:bubimo/features/diary_entry/presentation/widgets/overlay/sticker_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/widgets/error_screen.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../backgrounds/presentation/widgets/background_picker_widget.dart';
import '../../domain/entities/mood.dart';
import '../../domain/entities/overlay_image.dart';
import '../../domain/entities/sticker.dart';
import '../bloc/diary_form/diary_form_bloc.dart';
import '../bloc/diary_form/diary_form_event.dart';
import '../bloc/diary_form/diary_form_state.dart';
import '../bloc/sticker_picker/sticker_picker_bloc.dart';

/// Create or edit a diary entry. Pass [entryId] to edit an existing
/// entry, or omit it to create a new one.
///
/// On successful save, pops with `true` so the calling screen (Home, or
/// Entry View when editing) knows to refresh its data.
class DiaryFormPage extends StatelessWidget {
  final String? entryId;

  const DiaryFormPage({super.key, this.entryId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<DiaryFormBloc>()..add(DiaryFormInitialized(entryId: entryId)),
      child: const _DiaryFormView(),
    );
  }
}

class _DiaryFormView extends StatefulWidget {
  const _DiaryFormView();

  @override
  State<_DiaryFormView> createState() => _DiaryFormViewState();
}

class _DiaryFormViewState extends State<_DiaryFormView> {
  final TextEditingController _titleController = TextEditingController();

  // Explicit, stable focus nodes for the title field and the Quill
  // editor. Without these, Flutter falls back to implicit/ambient
  // focus behavior, which — combined with this screen rebuilding on
  // every keystroke (each Quill content change dispatches to the bloc,
  // which emits a new state and rebuilds the whole tree) — was causing
  // focus to jump from the description back to the title field mid-typing.
  // Keeping these nodes alive across rebuilds (they're fields, not
  // rebuilt in `build`) anchors focus to whichever field the user
  // actually tapped.
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  // Marks the fixed-size viewport of the description area (sized by
  // the surrounding LayoutBuilder's constraints, not the scrollable
  // content inside it). Used only to compute "the currently visible
  // area" when placing a newly added overlay item/sticker — drag
  // clamping itself uses `OverlayLayer`'s own content-sized bounds
  // internally, since the overlay layer now scrolls together with the
  // Quill editor and can be taller than this viewport for a long entry.
  final GlobalKey _editorBoundsKey = GlobalKey();

  // Tracks the description area's scroll position so newly added
  // overlay items/stickers can be placed relative to the currently
  // *visible* region of a long entry, not just the top of the document.
  final ScrollController _descriptionScrollController = ScrollController();

  // Anchors the mood popover so it appears directly below the mood
  // avatar in the header, like a speech bubble pointing back up at it.
  final GlobalKey _moodAvatarKey = GlobalKey();

  // Lets the editor-area GestureDetector below reach into
  // `DiaryBottomToolbarState.closeActivePanel()` — tapping the editor
  // area is this app's equivalent of "tap outside to dismiss" for the
  // toolbar's inline panels (T/Font/Text color/Bullet aren't modal
  // sheets, so there's no real "outside" a modal-dismiss gesture could
  // attach to; this recreates that feel without covering the editor).
  final GlobalKey<DiaryBottomToolbarState> _toolbarKey =
      GlobalKey<DiaryBottomToolbarState>();

  // Created once the entry (or blank create form) has finished loading,
  // since Quill's controller needs its initial document up front rather
  // than being reassigned later.
  quill.QuillController? _quillController;
  bool _controllersSynced = false;

  // Coalesces rapid keystrokes within the same frame into a single
  // deferred bloc dispatch — see `_onQuillContentChanged`.
  bool _contentChangeScheduled = false;

  // A stable key for the live `QuillEditor` widget — see its usage
  // below for why. Doesn't need to vary per entry: this whole `State`
  // is recreated (new `_DiaryFormViewState`) whenever `DiaryFormPage`
  // itself is rebuilt with a different `entryId`, via
  // `DiaryFormPage`'s own key/route identity, so one fixed key here is
  // sufficient.
  final GlobalKey _quillEditorKey = GlobalKey();

  // Built once rather than as a fresh object literal inside `build` —
  // `embedBuilders` used to be reconstructed (`ResizableImageEmbedBuilder()`
  // plus a new list) on every keystroke, which is wasteful even though
  // it wasn't the root cause of the unmounted-context crash (see
  // `_onQuillContentChanged`). Hoisting it removes one more source of
  // unnecessary rebuilding of the editor's config on every rebuild.
  late final quill.QuillEditorConfig _quillEditorConfig =
      quill.QuillEditorConfig(
        placeholder: "What's on your mind?",
        padding: EdgeInsets.zero,
        scrollable: false,
        embedBuilders: [
          ResizableImageEmbedBuilder(),
          DividerEmbedBuilder(),
          ...FlutterQuillEmbeds.editorBuilders(),
        ],
      );

  // Captured once so listeners registered outside `build` (Quill
  // content changes) can dispatch bloc events without needing a
  // BuildContext at call time.
  late final DiaryFormBloc _bloc;
  bool _blocCaptured = false;

  // Tracks the currently in-flight sticker download subscription (see
  // `_downloadSticker`), if any, so it can be cancelled in `dispose`.
  // Without this, a sticker download that completes (or errors) after
  // the user has already navigated away from this screen fires its
  // listener against a defunct `State` — its `context` getter throws
  // ("This widget has been unmounted") the moment anything tries to
  // use it, which is exactly the crash this guards against.
  StreamSubscription<StickerPickerState>? _stickerDownloadSubscription;

  // The panel currently requested by DiaryBottomToolbar (Font, Text
  // color, Lists, Text formatting, or a selection-scoped style/color
  // panel), or null when none is open. Rendered by `_buildPanelOverlay`
  // below as a full-screen Stack layered over the rest of this page's
  // body — see that method's doc comment for why this replaced the
  // previous `showModalBottomSheet`-based approach.
  DiaryPanelRequest? _activePanelRequest;

  // The keyboard's height at the moment a panel was opened, captured
  // via `MediaQuery.viewInsetsOf(context).bottom` *before* unfocus
  // in `_onPanelRequested`. This has to be captured synchronously right then
  // — reading MediaQuery again after unfocus would see the
  // keyboard already animating back toward 0, which is exactly the
  // value we need the panel to hold steady at instead of following.
  //
  // Also drives the scroll view's extra bottom padding while a panel
  // is open (mirrors what `_bottomPanelHeight`/`onPanelHeightChanged`
  // used to do, back when the toolbar's panels were sheets that could
  // report their own height).
  double _panelHeight = 0;

  @override
  void initState() {
    super.initState();
    // Defense-in-depth against the editor/title field reclaiming
    // focus while a panel is open — see `_onDescriptionFocusChanged`
    // for the full explanation of why this is needed on top of the
    // `canRequestFocus` gating in `_onPanelRequested`/`_closePanel`.
    _descriptionFocusNode.addListener(_onDescriptionFocusChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_blocCaptured) {
      _bloc = context.read<DiaryFormBloc>();
      _blocCaptured = true;
    }
  }

  @override
  void dispose() {
    _descriptionFocusNode.removeListener(_onDescriptionFocusChanged);
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _descriptionScrollController.dispose();
    _stickerDownloadSubscription?.cancel();
    _quillController?.removeListener(_onQuillContentChanged);
    _quillController?.dispose();
    super.dispose();
  }

  void _initQuillController(String rawContent) {
    final document = QuillDocumentUtils.documentFromContent(rawContent);
    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillController!.addListener(_onQuillContentChanged);
  }

  void _onQuillContentChanged() {
    // `QuillController.notifyListeners()` fires synchronously, from
    // *inside* Quill's own text-editing pipeline, mid-keystroke —
    // before that frame's layout/paint for the editor has finished.
    // Dispatching straight to the bloc here used to rebuild the whole
    // `BlocConsumer` subtree (this screen has no per-field
    // granularity — every keystroke rebuilds `QuillEditor.basic(...)`
    // itself, `OverlayLayer`, the header, etc.) re-entrant ly, while
    // Quill's own render objects for the very editor being typed into
    // were still mid-frame. That's what caused "This widget has been
    // unmounted... defunct" while actively typing in the description
    // field — the rebuild could tear down/recreate pieces of the
    // editor's element tree out from under a callback Quill itself had
    // already scheduled for later in the same frame.
    //
    // Deferring the actual bloc dispatch to the next frame (via
    // `addPostFrameCallback`) lets Quill finish everything it scheduled
    // for *this* frame first, so the resulting rebuild starts cleanly
    // on the next frame instead of interrupting the one already in
    // progress. `mounted` is checked at the point the callback actually
    // runs (not just when it's scheduled), since the widget may have
    // been disposed in the interim (e.g. the user saved/navigated away
    // between keystrokes).
    if (_contentChangeScheduled) return;
    _contentChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentChangeScheduled = false;
      if (!mounted || _quillController == null) return;
      final deltaJson = QuillDocumentUtils.contentFromController(
        _quillController!,
      );
      _bloc.add(DiaryFormContentChanged(deltaJson));
    });
  }

  /// Whether the Quill document currently has any non-whitespace text.
  /// Used for the "at least one of title/description" save validation.
  bool get _hasDescriptionText =>
      _quillController != null &&
      _quillController!.document.toPlainText().trim().isNotEmpty;

  /// Per-entry caps on media the user can add. Checked at the top of
  /// each picker method below, before anything (gallery, sticker
  /// sheet) even opens — rejecting up front reads better than letting
  /// the user pick/download something only to have it refused.
  static const int _maxInlineImages = 5;
  static const int _maxOverlayImages = 10;
  static const int _maxStickers = 15;

  /// Number of image embeds currently in the Quill document, found by
  /// scanning the live document rather than trusting
  /// `DiaryFormState.images`. That list only ever grows —
  /// `DiaryFormBloc._onImageAdded` appends to it and nothing ever
  /// removes from it, since deleting an inline image via its own
  /// remove handle (`ResizableImageEmbedBuilder.onRemove`) edits the
  /// document directly through the controller and never reports back
  /// to the bloc. Walking the document instead mirrors
  /// `ResizableImageEmbedBuilder._findOffset`'s own approach, so the
  /// count always reflects what's actually in the entry right now.
  int get _inlineImageCount {
    final controller = _quillController;
    if (controller == null) return 0;
    var count = 0;
    for (final node in controller.document.root.children) {
      if (node is quill.Line) {
        for (final leaf in node.children) {
          if (leaf is quill.Embed &&
              leaf.value.type == quill.BlockEmbed.imageType) {
            count++;
          }
        }
      }
    }
    return count;
  }

  /// Shown when a media button is tapped after its cap has already
  /// been reached. The button itself is never disabled — this message
  /// is the only feedback the user gets that nothing happened.
  void _showLimitReachedSnackBar(String message, ColorScheme theme) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: theme.onSecondary)),
        backgroundColor: theme.secondary,
      ),
    );
  }

  /// Inserts an image embed (gallery photos only — stickers never go
  /// into the Quill document, they're floating overlays) at the
  /// current cursor position.
  void _insertImageEmbed(String path) {
    final controller = _quillController!;
    final index = controller.selection.baseOffset.clamp(
      0,
      controller.document.length,
    );
    controller.replaceText(
      index,
      0,
      quill.BlockEmbed.image(path),
      TextSelection.collapsed(offset: index + 1),
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime current) async {
    // Dismiss keyboard before showing date picker
    FocusScope.of(context).unfocus();
    _toolbarKey.currentState?.closeActivePanel();

    final picked = await showBubimoDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && context.mounted) {
      context.read<DiaryFormBloc>().add(DiaryFormDateChanged(picked));
    }
  }

  Future<void> _openMoodPopover(BuildContext context, Mood? currentMood) async {
    final result = await showMoodPopover(
      context,
      anchorKey: _moodAvatarKey,
      selectedMood: currentMood,
    );
    if (result != null && context.mounted) {
      context.read<DiaryFormBloc>().add(DiaryFormMoodChanged(result.mood));
    }
  }

  /// Computes the rect (in `OverlayLayer`/document coordinate space)
  /// corresponding to whatever portion of the description area is
  /// currently scrolled into view, so a newly added sticker/overlay
  /// image lands where the user is actually looking rather than always
  /// at the top of a long entry.
  ///
  /// The overlay Stack now scrolls together with the Quill editor
  /// (both are children of the same `SingleChildScrollView`), so its
  /// coordinate space is the *whole document's* space, not just the
  /// viewport's — offsetting by the current scroll position translates
  /// "top-left of the visible viewport" into that shared space. Falls
  /// back to a `0,0`-origin rect of the viewport's own size if the
  /// bounds box isn't laid out yet (e.g. very first frame).
  Rect? _visibleBoundsForPlacement() {
    final box =
        _editorBoundsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final scrollOffset = _descriptionScrollController.hasClients
        ? _descriptionScrollController.offset
        : 0.0;
    return Rect.fromLTWH(0, scrollOffset, box.size.width, box.size.height);
  }

  /// Opens the sticker picker sheet. Unlike gallery overlay photos
  /// (already a local file the moment they're picked), a sticker must
  /// be downloaded from Supabase first — so that download happens here,
  /// before the item ever reaches [DiaryFormBloc]. This keeps
  /// `DiaryFormBloc` free of any network/IO concerns, matching how it
  /// never talks to Supabase directly for backgrounds either.
  Future<void> _openStickerPicker(
    BuildContext context,
    ColorScheme colorScheme,
  ) async {
    if (_bloc.state.stickers.length >= _maxStickers) {
      _showLimitReachedSnackBar(
        'You can only add up to $_maxStickers stickers per entry.',
        colorScheme,
      );
      return;
    }

    // Dismiss keyboard before showing sticker picker
    FocusScope.of(context).unfocus();
    _toolbarKey.currentState?.closeActivePanel();

    final url = await showStickerPickerSheet(context);
    if (url == null || !context.mounted) return;

    final pickerBloc = getIt<StickerPickerBloc>();
    try {
      final localPath = await _downloadSticker(pickerBloc, url);
      if (localPath == null || !mounted) return;

      final position = OverlayLayer.findFreePosition(
        bounds: _visibleBoundsForPlacement(),
        existingImages: _bloc.state.overlayImages,
        existingStickers: _bloc.state.stickers,
        width: Sticker.baseWidth,
        height: Sticker.baseHeight,
      );

      _bloc.add(
        DiaryFormStickerAdded(
          id: IdGenerator.generate(),
          url: url,
          localPath: localPath,
          x: position.dx,
          y: position.dy,
        ),
      );
    } finally {
      pickerBloc.close();
    }
  }

  /// Drives [StickerPickerBloc] for a single download-and-return flow,
  /// outside of any widget tree — the picker sheet itself has already
  /// closed by this point, so there's nowhere to put a `BlocListener`.
  ///
  /// The subscription is stored on [_stickerDownloadSubscription] (and
  /// cancelled in [dispose]) rather than a local variable, so a
  /// download that's still in flight when the user navigates away from
  /// this screen never fires its callback against a defunct `State` —
  /// touching `context` (even just reading it, let alone calling
  /// `ScaffoldMessenger.of(context)`) after this widget is unmounted is
  /// what throws "This widget has been unmounted" from the scheduler.
  Future<String?> _downloadSticker(
    StickerPickerBloc pickerBloc,
    String url,
  ) async {
    final completer = Completer<String?>();
    _stickerDownloadSubscription?.cancel();
    _stickerDownloadSubscription = pickerBloc.stream.listen((state) {
      if (state.lastDownloaded?.url == url) {
        _stickerDownloadSubscription?.cancel();
        _stickerDownloadSubscription = null;
        completer.complete(state.lastDownloaded!.localPath);
      } else if (state.downloadError != null && !state.isDownloading) {
        _stickerDownloadSubscription?.cancel();
        _stickerDownloadSubscription = null;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.downloadError!)));
        }
        completer.complete(null);
      }
    });
    pickerBloc.add(StickerSelected(url));
    return completer.future;
  }

  void _onImagePicked(String path) {
    _insertImageEmbed(path);
    _bloc.add(DiaryFormImageAdded(path));
  }

  /// Picks a photo for inline insertion into the Quill document body.
  Future<void> _pickInlineImage(ColorScheme colorScheme) async {
    if (_inlineImageCount >= _maxInlineImages) {
      _showLimitReachedSnackBar(
        'You can only add up to $_maxInlineImages photos in the text.',
        colorScheme,
      );
      return;
    }

    // Dismiss keyboard before showing image picker
    FocusScope.of(context).unfocus();
    _toolbarKey.currentState?.closeActivePanel();

    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        _onImagePicked(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  /// Picks a photo for a free-floating overlay on top of the entry.
  Future<void> _pickOverlayImage(ColorScheme colorScheme) async {
    if (_bloc.state.overlayImages.length >= _maxOverlayImages) {
      _showLimitReachedSnackBar(
        'You can only add up to $_maxOverlayImages floating photos per entry.',
        colorScheme,
      );
      return;
    }

    // Dismiss keyboard before showing image picker
    FocusScope.of(context).unfocus();
    _toolbarKey.currentState?.closeActivePanel();

    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        _onOverlayImagePicked(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  /// Adds a new floating overlay photo — entirely separate from
  /// [_onImagePicked]'s inline Quill embed. Finds an unoccupied spot
  /// within the editor bounds so new photos don't stack directly on top
  /// of each other, existing overlay images, or stickers.
  void _onOverlayImagePicked(String path) {
    final position = OverlayLayer.findFreePosition(
      bounds: _visibleBoundsForPlacement(),
      existingImages: _bloc.state.overlayImages,
      existingStickers: _bloc.state.stickers,
      width: OverlayImage.baseWidth,
      height: OverlayImage.baseHeight,
    );
    _bloc.add(
      DiaryFormOverlayImageAdded(
        id: IdGenerator.generate(),
        path: path,
        x: position.dx,
        y: position.dy,
      ),
    );
  }

  void _onOverlayImageSelect(String id) {
    _descriptionFocusNode.unfocus();
    _bloc.add(DiaryFormOverlayImageSelected(id));
  }

  void _onOverlayImageDeselect() {
    if (_bloc.state.selectedOverlayImageId == null &&
        _bloc.state.selectedStickerId == null) {
      return;
    }
    _bloc.add(const DiaryFormOverlayImageSelected(null));
    _bloc.add(const DiaryFormStickerSelected(null));
  }

  void _onOverlayImageTransform({
    required String id,
    required double x,
    required double y,
    required double scale,
    required double rotation,
  }) {
    _bloc.add(
      DiaryFormOverlayImageTransformed(
        id: id,
        x: x,
        y: y,
        scale: scale,
        rotation: rotation,
      ),
    );
  }

  void _onOverlayImageRemove(String id) {
    _bloc.add(DiaryFormOverlayImageRemoved(id));
  }

  void _onStickerSelect(String id) {
    _descriptionFocusNode.unfocus();
    _bloc.add(DiaryFormStickerSelected(id));
  }

  void _onStickerTransform({
    required String id,
    required double x,
    required double y,
    required double scale,
    required double rotation,
  }) {
    _bloc.add(
      DiaryFormStickerTransformed(
        id: id,
        x: x,
        y: y,
        scale: scale,
        rotation: rotation,
      ),
    );
  }

  void _onStickerRemove(String id) {
    _bloc.add(DiaryFormStickerRemoved(id));
  }

  void _applyFontFamily(String? fontFamily) {
    final controller = _quillController!;
    controller.formatText(
      0,
      controller.document.length,
      quill.Attribute.fromKeyValue('font', fontFamily),
    );
    _bloc.add(DiaryFormFontFamilyChanged(fontFamily));
  }

  TextAlign _textAlignFor(String alignment) {
    switch (alignment) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      case 'left':
      default:
        return TextAlign.left;
    }
  }

  Color? _colorFromHex(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  void _onAlignmentChanged(String alignment) {
    _bloc.add(DiaryFormAlignmentChanged(alignment));
  }

  /// Handles [DiaryBottomToolbar.onPanelRequested] — `request` is the
  /// panel to show, or `null` to close whatever's currently open.
  ///
  /// This is the actual fix for the keyboard-flicker/double-back-button
  /// issue the sheet-based approach had. The problem with
  /// `showModalBottomSheet` was structural, not a matter of timing it
  /// better: a modal sheet is a *route*, and a route's entrance
  /// transition is driven by the `Navigator`, which has no way to
  /// synchronize with the platform IME's own close animation — that's
  /// a separate OS-owned surface, not something Flutter's frame
  /// scheduler has authority over. Any `unfocus()` + `await` sequence
  /// before pushing the route can reduce the race but can't eliminate
  /// it, because the two animations are driven by two different
  /// systems that were never going to line up perfectly.
  ///
  /// So instead of animating a new surface in over a closing keyboard,
  /// this replaces the keyboard's own footprint directly: capture its
  /// current height, take focus away (which starts it closing), and
  /// immediately render the panel at that exact height in the same
  /// frame. There's no route transition to race against — the panel
  /// occupies the space the keyboard is vacating rather than sliding
  /// in over top of it, which is what actually removes the visible gap
  /// rather than just narrowing it.
  void _onPanelRequested(DiaryPanelRequest? request) {
    if (request == null) {
      _closePanel();
      return;
    }

    // Order matters: read the keyboard's current height *before*
    // unfocus ing. The instant focus leaves the editor, the platform
    // keyboard starts animating toward 0 height — reading MediaQuery
    // after that point would capture a value already partway through
    // that animation, not the full height we want the panel to hold.
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    FocusManager.instance.primaryFocus?.unfocus();

    // The actual fix for keyboard reclaiming focus mid-panel (e.g. on
    // every alignment/bold/italic/underline/font-size tap in the T
    // panel): the still-mounted QuillEditor underneath reacts to its
    // own controller changing and can request focus back on its own.
    // Setting `canRequestFocus = false` makes any such `requestFocus()`
    // call a structural no-op — the request never takes effect in the
    // first place — rather than relying only on catching and reversing
    // a grant after the fact. See `_onDescriptionFocusChanged` for the
    // backstop that also catches this, kept as a second layer since
    // this bug has now shown up via more than one path.
    _descriptionFocusNode.canRequestFocus = false;
    _titleFocusNode.canRequestFocus = false;

    setState(() {
      _activePanelRequest = request;
      // Fall back to a sane minimum on the rare frame where the
      // keyboard genuinely wasn't up yet (e.g. a panel opened via
      // some path that doesn't start from the editor having focus) —
      // 0 would collapse the panel to nothing.
      _panelHeight = keyboardHeight > 100 ? keyboardHeight : 320;
    });
  }

  /// Closes whatever panel is open, honoring its
  /// [DiaryPanelRequest.refocusOnClose] flag before clearing state.
  /// Safe to call when nothing is open (checked here, rather than
  /// only in the toolbar's `closeActivePanel`, since this is also
  /// reached from the overlay's own tap-outside-to-close gesture).
  void _closePanel() {
    if (_activePanelRequest == null) return;
    final shouldRefocus = _activePanelRequest!.refocusOnClose;

    // Reset unconditionally — both fields should always go back to
    // normally-focusable once no panel is open, independent of
    // whether *this particular* close should also immediately
    // request focus (that's the separate `shouldRefocus` check below).
    _descriptionFocusNode.canRequestFocus = true;
    _titleFocusNode.canRequestFocus = true;

    setState(() {
      _activePanelRequest = null;
      _panelHeight = 0;
    });

    // Keep the toolbar's own active-panel highlight state in sync,
    // for the case where this was triggered by the overlay's
    // tap-outside gesture rather than the toolbar itself requesting
    // the close (e.g. `_ListPanel.onDone`, which already goes through
    // the toolbar — this covers the outside-tap path, where the
    // toolbar wouldn't otherwise know to clear its highlight).
    _toolbarKey.currentState?.closeActivePanel();

    if (shouldRefocus) {
      _descriptionFocusNode.requestFocus();
    }
  }

  /// Actively rejects focus landing back on the description field
  /// while a panel is open — the backstop layer alongside
  /// `canRequestFocus` gating in [_onPanelRequested]/[_closePanel].
  ///
  /// `canRequestFocus = false` should already prevent this structurally,
  /// but this listener catches it too: if focus lands back on the
  /// editor for *any* reason while a panel is open, hand it straight
  /// back rather than trying to enumerate every possible code path
  /// that could grant it. Cheap to keep — `FocusNode` listeners only
  /// fire on actual focus changes, not on rebuilds, so this adds no
  /// per-frame or per-rebuild cost.
  void _onDescriptionFocusChanged() {
    if (_activePanelRequest != null && _descriptionFocusNode.hasFocus) {
      _descriptionFocusNode.unfocus();
    }
  }

  /// Same guard as [_onDescriptionFocusChanged], for the title field.
  void _onTitleFocusChanged() {
    if (_activePanelRequest != null && _titleFocusNode.hasFocus) {
      _titleFocusNode.unfocus();
    }
  }

  /// The full-screen overlay hosting whatever panel
  /// [_activePanelRequest] currently holds. Structured as:
  ///
  /// - A transparent, full-bleed tap layer (`Positioned.fill`) that
  ///   closes the panel on tap — this is the "half the screen is
  ///   transparent so you can still see it, tapping there closes the
  ///   sheet" behavior.
  /// - The panel itself, anchored to the bottom, height fixed to
  ///   [_panelHeight] (the keyboard height captured when it opened) —
  ///   not animated, since the goal is an instant swap into the
  ///   keyboard's former footprint, not a sheet growing into view.
  ///
  /// Returns an empty, zero-size widget when no panel is requested,
  /// so this can sit unconditionally in the `Stack` below without an
  /// `if` at the call site — cheaper to reason about, and avoids
  /// rebuilding the `Stack`'s child list shape on every open/close.
  Widget _buildPanelOverlay() {
    final request = _activePanelRequest;
    if (request == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closePanel,
            // Fully transparent — this is deliberately *not* a
            // scrim/barrier color. The whole point is that the user
            // can still see the entry behind the panel, which is what
            // makes this read as "preview" rather than "a dialog
            // opened over your work".
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _panelHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.14),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              // A drag handle purely as a visual affordance (this
              // overlay has no drag-to-dismiss gesture of its own —
              // dismissal is tap-outside or the panel's own "done"
              // action) — kept because every panel here used to be a
              // `showModalBottomSheet` with `showDragHandle: true`,
              // and dropping it would be a visible regression in feel
              // for no functional reason.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(child: Builder(builder: request.content)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openBackgroundPicker(BuildContext context) async {
    // Dismiss keyboard before showing background picker
    FocusScope.of(context).unfocus();
    _toolbarKey.currentState?.closeActivePanel();

    final selection = await showBackgroundPickerSheet(
      context,
      currentPresetPath: _bloc.state.bgLocalPath,
    );
    if (selection == null) return;

    switch (selection.type) {
      case BackgroundSourceType.presetRemote:
        _bloc.add(DiaryFormBackgroundChanged(bgLocalPath: selection.path));
      case BackgroundSourceType.gallery:
        _bloc.add(
          DiaryFormBackgroundChanged(bgGalleryImagePath: selection.path),
        );
      case BackgroundSourceType.none:
        // User explicitly cleared the background. NOTE: whether this
        // actually clears a previously-set path depends on how
        // DiaryFormBloc's handler applies these fields — if it uses a
        // `value ?? state.value` copyWith (common, and indistinguishable
        // here from "field simply not provided"), passing null won't
        // overwrite an existing one. Worth a quick manual check
        // (set a gallery photo, reopen the picker, tap None) since I
        // don't have diary_form_bloc.dart/diary_form_state.dart to
        // confirm either way.
        _bloc.add(
          DiaryFormBackgroundChanged(bgLocalPath: null, bgGalleryImagePath: null),
        );
    }
  }

  /// Opens the bottom sheet for adjusting the background overlay tint's
  /// opacity and color. Only meaningful when a background image is set,
  /// so the caller only shows the settings icon in that case.
  Future<void> _openOverlaySettingsSheet(BuildContext context) async {
    // Dismiss keyboard before showing overlay settings
    FocusScope.of(context).unfocus();
    _toolbarKey.currentState?.closeActivePanel();

    final bloc = _bloc;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: bloc,
          child: const DiaryFormOverlaySettingsSheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DiaryFormBloc, DiaryFormState>(
      listener: (context, state) {
        if (state.status == DiaryFormStatus.success) {
          context.pop(true);
        }
        if (state.status == DiaryFormStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }

        if (state.status == DiaryFormStatus.ready && !_controllersSynced) {
          _titleController.text = state.title;
          _initQuillController(state.content);
          _controllersSynced = true;
        }
      },
      builder: (context, state) {
        if (state.status == DiaryFormStatus.loadingEntry) {
          return const Scaffold(body: LoadingScreen());
        }

        if (state.status == DiaryFormStatus.failure && !_controllersSynced) {
          return Scaffold(
            body: ErrorScreen(
              message: state.errorMessage ?? 'Something went wrong.',
              onRetry: () => context.read<DiaryFormBloc>().add(
                DiaryFormInitialized(entryId: state.entryId),
              ),
            ),
          );
        }

        if (_quillController == null) {
          return const Scaffold(body: LoadingScreen());
        }

        final backgroundImage = BackgroundImageUtils.resolveProvider(
          bgGalleryImagePath: state.bgGalleryImagePath,
          bgImagePath: state.bgImagePath,
          bgLocalPath: state.bgLocalPath,
        );

        final canSave = state.title.trim().isNotEmpty || _hasDescriptionText;
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(state.isEditMode ? 'Edit Entry' : 'New Entry'),
            actions: [
              if (backgroundImage != null)
                IconButton(
                  tooltip: 'Background overlay settings',
                  icon: const Icon(Icons.tune),
                  onPressed: () => _openOverlaySettingsSheet(context),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: FilledButton(
                    onPressed: (canSave && !state.isSubmitting)
                        ? () => context.read<DiaryFormBloc>().add(
                            const DiaryFormSubmitted(),
                          )
                        : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ),
            ],
          ),
          body: Container(
            decoration: backgroundImage != null
                ? BoxDecoration(
                    image: DecorationImage(
                      image: backgroundImage,
                      fit: BoxFit.cover,
                      colorFilter: OverlayTintUtils.resolveColorFilter(
                        bgOverlayColor: state.bgOverlayColor,
                        themeBrightness: Theme.of(context).brightness,
                        opacity: state.bgOverlayOpacity,
                      ),
                    ),
                  )
                : null,
            // A Stack rather than plain SafeArea/Column now, so the
            // panel overlay (`_buildPanelOverlay`) can be layered as a
            // second, full-screen child above the editor/toolbar/
            // header — it needs to cover the whole page, which it
            // couldn't do if it were hosted inside DiaryBottomToolbar
            // itself (that widget is a fixed-height bar at the bottom
            // of this Column, with no way to paint outside its own
            // bounds). The original content below is unchanged, just
            // now the Stack's first child instead of the Container's
            // direct child.
            child: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Column(
                          children: [
                            Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (_) => _toolbarKey.currentState
                                  ?.closeActivePanelAndRestoreFocus(),
                              child: DiaryFormHeaderRow(
                                date: state.date,
                                mood: state.mood,
                                moodAvatarKey: _moodAvatarKey,
                                onDateTap: () => _pickDate(context, state.date),
                                onMoodTap: () =>
                                    _openMoodPopover(context, state.mood),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (_) =>
                                  _toolbarKey.currentState?.closeActivePanel(),
                              child: DiaryFormTitleField(
                                controller: _titleController,
                                focusNode: _titleFocusNode,
                                nextFocusNode: _descriptionFocusNode,
                                textAlign: _textAlignFor(state.alignment),
                                isBold: state.isBold,
                                isItalic: state.isItalic,
                                isUnderlined: state.isUnderline,
                                fontSize: state.fontSize != null
                                    ? double.tryParse(state.fontSize!)
                                    : null,
                                textColor: _colorFromHex(state.textColorHex),
                                onChanged: (value) => context
                                    .read<DiaryFormBloc>()
                                    .add(DiaryFormTitleChanged(value)),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (_) => _toolbarKey.currentState
                                  ?.closeActivePanelAndRestoreFocus(),
                              child: Container(
                                key: _editorBoundsKey,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  16,
                                ),
                                child: SingleChildScrollView(
                                  controller: _descriptionScrollController,
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.only(
                                    // Extra bottom padding while a panel
                                    // is open, so the last line of the
                                    // entry isn't hidden behind it.
                                    bottom: _panelHeight + 16,
                                  ),
                                  child: OverlayLayer(
                                    boundsKey: _editorBoundsKey,
                                    images: state.overlayImages,
                                    stickers: state.stickers,
                                    selectedImageId:
                                        state.selectedOverlayImageId,
                                    selectedStickerId: state.selectedStickerId,
                                    onSelectImage: _onOverlayImageSelect,
                                    onSelectSticker: _onStickerSelect,
                                    onDeselect: _onOverlayImageDeselect,
                                    onImageTransform: _onOverlayImageTransform,
                                    onStickerTransform: _onStickerTransform,
                                    onRemoveImage: _onOverlayImageRemove,
                                    onRemoveSticker: _onStickerRemove,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: quill.QuillEditor.basic(
                                        key: _quillEditorKey,
                                        controller: _quillController!,
                                        focusNode: _descriptionFocusNode,
                                        config: _quillEditorConfig,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      DiaryBottomToolbar(
                        key: _toolbarKey,
                        controller: _quillController!,
                        editorFocusNode: _descriptionFocusNode,
                        selectedFontFamily: state.fontFamily,
                        onFontSelected: _applyFontFamily,
                        onAlignmentChanged: _onAlignmentChanged,
                        onBoldChanged: (value) =>
                            _bloc.add(DiaryFormBoldChanged(value)),
                        onItalicChanged: (value) =>
                            _bloc.add(DiaryFormItalicChanged(value)),
                        onUnderlineChanged: (value) =>
                            _bloc.add(DiaryFormUnderlineChanged(value)),
                        onFontSizeChanged: (value) =>
                            _bloc.add(DiaryFormFontSizeChanged(value)),
                        onTextColorChanged: (value) =>
                            _bloc.add(DiaryFormTextColorChanged(value)),
                        onBackgroundPressed: () =>
                            _openBackgroundPicker(context),
                        onStickerPressed: () =>
                            _openStickerPicker(context, colorScheme),
                        onOverlayImagePressed: () =>
                            _pickOverlayImage(colorScheme),
                        onInlineImagePressed: () =>
                            _pickInlineImage(colorScheme),
                        onPanelRequested: _onPanelRequested,
                      ),
                    ],
                  ),
                ),
                _buildPanelOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }
}