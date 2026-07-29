// lib/features/diary_entry/presentation/widgets/overlay/resizable_image_embed_builder.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../full_screen_image_viewer.dart';

/// Custom image `EmbedBuilder` with a real drag-to-resize handle and a
/// remove handle.
///
/// `flutter_quill_extensions`' built-in [quill.EmbedBuilder] for images
/// only exposes resizing through a desktop-only context menu (right
/// click / long press → menu → pick a size) and reads/writes the
/// `width`/`height`/`margin` CSS-style attributes on the embed node —
/// there is no drag handle, so on mobile it's effectively impossible
/// for a user to resize an inline image at all. This builder replaces
/// it with a widget that renders the image at its stored width/height
/// (falling back to a sensible default) and exposes a bottom-right
/// resize handle and a top-left remove handle, matching the same
/// physical drag-to-resize feel as the overlay images
/// ([TransformableItem]) elsewhere in this feature.
///
/// Register this in place of the extension's image builder:
/// ```dart
/// embedBuilders: [
///   ResizableImageEmbedBuilder(),
///   ...FlutterQuillEmbeds.editorBuilders(), // video, formula, etc.
/// ],
/// ```
/// List order matters — Quill uses the first builder whose `key`
/// matches, so this must come before the extension's own image builder
/// if both are present.
class ResizableImageEmbedBuilder extends quill.EmbedBuilder {
  static const double _defaultWidth = 220;
  static const double _defaultHeight = 220;
  static const double _minSize = 80;
  static const double _maxSize = 600;

  @override
  String get key => quill.BlockEmbed.imageType;

  /// Finds the current offset of the embed node whose image data
  /// matches [imageSource], by scanning the live document rather than
  /// trusting [controller]'s current selection.
  ///
  /// The previous implementation resolved the node via
  /// `controller.selection.start`, which is the cursor position — not
  /// necessarily this embed's position. If the selection had moved
  /// elsewhere by the time a drag gesture finished (e.g. the user
  /// scrolled, tapped away, or another embed took focus), that offset
  /// pointed at unrelated content or past the end of the document, and
  /// `quill.getEmbedNode` threw `ArgumentError: Embed node not found by
  /// offset`. Scanning for the node by its own image data is immune to
  /// selection changes entirely. Returns `null` if the node can no
  /// longer be found (e.g. it was already deleted).
  int? _findOffset(quill.QuillController controller, String imageSource) {
    final root = controller.document.root;
    for (final node in root.children) {
      if (node is quill.Line) {
        for (final leaf in node.children) {
          if (leaf is quill.Embed &&
              leaf.value.type == quill.BlockEmbed.imageType &&
              leaf.value.data == imageSource) {
            return leaf.documentOffset;
          }
        }
      }
    }
    return null;
  }

  /// Parses the CSS-like value stored under the embed's `style`
  /// attribute (e.g. `'width: 220; height: 340;'`) back into numeric
  /// width/height.
  ///
  /// This is the read-side counterpart of the string [onResizeEnd]
  /// builds below — `Attribute.fromKeyValue('style', 'width: ...;
  /// height: ...;')` writes ONE attribute keyed `'style'` whose value
  /// is that whole composite string. There is no separate `'width'` or
  /// `'height'` key ever written (those are different, unrelated
  /// attributes in flutter_quill's own registry — see `WidthAttribute`/
  /// `HeightAttribute` vs `StyleAttribute` in `attribute.dart`), so
  /// reading `style.attributes['width']` / `style.attributes['height']`
  /// directly — which the previous implementation did — always misses:
  /// those keys are never present, only `'style'` is. That mismatch is
  /// why a resize would apply live in the editor (pure widget state,
  /// see `_ResizableImageState`) but silently revert to the
  /// [_defaultWidth]/[_defaultHeight] fallback every time the entry was
  /// reloaded, even though the correct value was already being saved
  /// to disk correctly the whole time.
  static Map<String, double> _parseStyleSize(String? styleValue) {
    if (styleValue == null || styleValue.isEmpty) return const {};
    final result = <String, double>{};
    for (final pair in styleValue.split(';')) {
      final colon = pair.indexOf(':');
      if (colon < 0) continue;
      final key = pair.substring(0, colon).trim();
      if (key != 'width' && key != 'height') continue;
      final value = double.tryParse(pair.substring(colon + 1).trim());
      if (value != null) result[key] = value;
    }
    return result;
  }

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final imageSource = embedContext.node.value.data as String;
    final style = embedContext.node.style;

    final storedSize = _parseStyleSize(
      style.attributes['style']?.value?.toString(),
    );
    final storedWidth = storedSize['width'];
    final storedHeight = storedSize['height'];

    return _ResizableImage(
      key: ValueKey(imageSource),
      imageSource: imageSource,
      initialWidth: storedWidth ?? _defaultWidth,
      initialHeight: storedHeight ?? _defaultHeight,
      minSize: _minSize,
      maxSize: _maxSize,
      readOnly: embedContext.readOnly,
      onResizeEnd: (width, height) {
        if (embedContext.readOnly) return;
        final controller = embedContext.controller;
        final offset = _findOffset(controller, imageSource);
        if (offset == null) return;
        controller.formatText(
          offset,
          1,
          quill.Attribute.fromKeyValue(
            'style',
            'width: ${width.round()}; height: ${height.round()};',
          ),
        );
      },
      onRemove: () {
        if (embedContext.readOnly) return;
        final controller = embedContext.controller;
        final offset = _findOffset(controller, imageSource);
        if (offset == null) return;
        controller.replaceText(
          offset,
          1,
          '',
          TextSelection.collapsed(offset: offset),
        );
      },
    );
  }
}

/// Renders [imageSource] (local file path or network URL) at
/// [initialWidth]x[initialHeight], with an optional bottom-right drag
/// handle to resize it in place and a top-left handle to remove it.
/// Reports the final size via [onResizeEnd] once the user lifts their
/// finger, rather than on every frame, to avoid spamming `formatText`
/// calls into the Quill document history.
class _ResizableImage extends StatefulWidget {
  final String imageSource;
  final double initialWidth;
  final double initialHeight;
  final double minSize;
  final double maxSize;
  final bool readOnly;
  final void Function(double width, double height) onResizeEnd;
  final VoidCallback onRemove;

  const _ResizableImage({
    super.key,
    required this.imageSource,
    required this.initialWidth,
    required this.initialHeight,
    required this.minSize,
    required this.maxSize,
    required this.readOnly,
    required this.onResizeEnd,
    required this.onRemove,
  });

  @override
  State<_ResizableImage> createState() => _ResizableImageState();
}

class _ResizableImageState extends State<_ResizableImage> {
  late double _width;
  late double _height;
  late double _aspectRatio;

  bool _isResizing = false;
  Offset? _dragStartGlobal;
  double _widthAtDragStart = 0;
  int? _activePointer;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
    _height = widget.initialHeight;
    _aspectRatio = _height == 0 ? 1 : _width / _height;
  }

  @override
  void didUpdateWidget(covariant _ResizableImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // `initState` only runs once per `State` lifetime, but this widget
    // is NOT guaranteed to get a fresh `State` every time its embed's
    // saved size actually changes. `ResizableImageEmbedBuilder.build`
    // keys `_ResizableImage` on `imageSource` alone (the image's own
    // file path/URL) — deliberately, so remove/reinsert of a
    // *different* image is treated as a different widget. But that
    // also means resizing the SAME image (same `imageSource`, only
    // its `style` attribute's width/height changed) keeps the exact
    // same key, and Flutter's default widget-diffing has no other
    // reason to tear down a `TextLine`/embed subtree that sits at the
    // same position in the tree either (`RawEditorState` doesn't key
    // its `TextLine`s — see `_getEditableTextLineFromNode` — so it's
    // reused by position, not recreated, whenever a *new*
    // `QuillController` is swapped in wholesale, e.g. `DiaryEntryViewPage`
    // building a fresh controller in `_loadEntry` after returning from
    // an edit). Net effect: this exact `_ResizableImageState` instance
    // survives the round trip, `initState` never re-runs, and without
    // this override it would keep showing whatever `_width`/`_height`
    // it originally initialized with — stale by exactly one edit,
    // which is why the fix only ever seemed to "catch up" a screen
    // later. Re-deriving state here on every rebuild where the
    // incoming size actually differs closes that gap.
    if (widget.initialWidth != oldWidget.initialWidth ||
        widget.initialHeight != oldWidget.initialHeight) {
      _width = widget.initialWidth;
      _height = widget.initialHeight;
      _aspectRatio = _height == 0 ? 1 : _width / _height;
    }
  }

  ImageProvider _resolveProvider(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return NetworkImage(source);
    }
    if (source.startsWith('assets/')) {
      return AssetImage(source);
    }
    return FileImage(File(source));
  }

  // Raw pointer handling instead of a pan `GestureDetector`.
  //
  // The handle sits inside a Quill embed, which is itself inside a
  // scrollable editor (and, on the form page, inside a
  // `SingleChildScrollView` on top of that). A pan `GestureDetector`
  // has to win the gesture arena against those ancestor scroll/drag
  // recognizers before it receives any events — and it was silently
  // losing, which is why dragging the handle appeared to do nothing.
  // `Listener` receives every raw pointer event unconditionally, with
  // no arena negotiation, so the handle is guaranteed first access to
  // the touch that started on it.
  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _isResizing = true;
      _activePointer = event.pointer;
      _dragStartGlobal = event.position;
      _widthAtDragStart = _width;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _dragStartGlobal == null) return;
    final delta = event.position - _dragStartGlobal!;

    // Drive resize off horizontal drag distance, keep aspect ratio
    // locked — predictable single-axis resizing rather than free-form
    // stretch, which reads as more intentional for photo embeds.
    final newWidth =
        (_widthAtDragStart + delta.dx).clamp(widget.minSize, widget.maxSize);
    final newHeight = newWidth / _aspectRatio;

    setState(() {
      _width = newWidth;
      _height = newHeight;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    setState(() {
      _isResizing = false;
      _activePointer = null;
      _dragStartGlobal = null;
    });
    widget.onResizeEnd(_width, _height);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    setState(() {
      _isResizing = false;
      _activePointer = null;
      _dragStartGlobal = null;
    });
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove image?'),
        content: const Text('This will remove the image from your entry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image(
        image: _resolveProvider(widget.imageSource),
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: _width,
          height: _height,
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image, color: Colors.white54),
        ),
      ),
    );

    if (widget.readOnly) {
      // View mode: no resize/remove handles (the saved entry is final
      // once it's no longer being edited) — instead, tapping the image
      // opens it full-screen via `FullScreenImageViewer`, matching how
      // overlay/sticker images and gallery photos elsewhere in the app
      // are viewed. The `Hero` tag is derived from `imageSource` itself
      // (unique per embed), so the fly-in animation targets exactly
      // this image.
      final heroTag = 'inline_image_${widget.imageSource}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: () => FullScreenImageViewer.show(
            context,
            imagePath: widget.imageSource,
            heroTag: heroTag,
          ),
          child: Hero(
            tag: heroTag,
            child: image,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: _width,
        height: _height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            image,
            if (_isResizing)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            // Remove handle — top-left, mirrors the resize handle's
            // bottom-right placement so the two never overlap.
            Positioned(
              left: -6,
              top: -6,
              child: GestureDetector(
                onTap: _confirmRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Resize handle — bottom-right. `Listener` (not
            // `GestureDetector`) so the drag is guaranteed to reach
            // this widget instead of being claimed by an ancestor
            // scroll view or the editor's own gesture handling.
            Positioned(
              right: -6,
              bottom: -6,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.open_in_full_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}