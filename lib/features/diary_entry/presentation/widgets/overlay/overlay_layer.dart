// lib/features/diary_entry/presentation/widgets/overlay/overlay_layer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/overlay_image.dart';
import '../../../domain/entities/sticker.dart';
import 'editable_overlay_image.dart';
import 'editable_sticker_overlay.dart';

class OverlayLayer extends StatefulWidget {
  final Widget child;
  final List<OverlayImage> images;
  final List<Sticker> stickers;
  final String? selectedImageId;
  final String? selectedStickerId;

  final ValueChanged<String> onSelectImage;
  final ValueChanged<String> onSelectSticker;
  final VoidCallback onDeselect;

  final void Function({
    required String id,
    required double x,
    required double y,
    required double scale,
    required double rotation,
  }) onImageTransform;
  final void Function({
    required String id,
    required double x,
    required double y,
    required double scale,
    required double rotation,
  }) onStickerTransform;

  final ValueChanged<String> onRemoveImage;
  final ValueChanged<String> onRemoveSticker;
  final GlobalKey boundsKey;

  const OverlayLayer({
    super.key,
    required this.child,
    required this.images,
    this.stickers = const [],
    required this.selectedImageId,
    this.selectedStickerId,
    required this.onSelectImage,
    required this.onSelectSticker,
    required this.onDeselect,
    required this.onImageTransform,
    required this.onStickerTransform,
    required this.onRemoveImage,
    required this.onRemoveSticker,
    required this.boundsKey,
  });

  static Offset findFreePosition({
    required Rect? bounds,
    required List<OverlayImage> existingImages,
    List<Sticker> existingStickers = const [],
    required double width,
    required double height,
  }) {
    if (bounds == null) return const Offset(20, 20);

    final existing = <Rect>[
      for (final img in existingImages)
        Rect.fromLTWH(
          img.x,
          img.y,
          OverlayImage.baseWidth * img.scale,
          OverlayImage.baseHeight * img.scale,
        ),
      for (final sticker in existingStickers)
        Rect.fromLTWH(
          sticker.x,
          sticker.y,
          Sticker.baseWidth * sticker.scale,
          Sticker.baseHeight * sticker.scale,
        ),
    ];

    bool isValid(Rect rect) {
      if (rect.left < bounds.left ||
          rect.top < bounds.top ||
          rect.right > bounds.right ||
          rect.bottom > bounds.bottom) {
        return false;
      }
      return existing.every((r) => !rect.overlaps(r));
    }

    final startTL = Offset(
      (bounds.left + (bounds.width - width) / 2).clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - width),
      ),
      (bounds.top + (bounds.height - height) / 2).clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - height),
      ),
    );
    if (isValid(Rect.fromLTWH(startTL.dx, startTL.dy, width, height))) {
      return startTL;
    }

    final searchCenter = bounds.center;
    for (double r = 20.0; r <= 500.0; r += 20.0) {
      for (int d = 0; d < 8; d++) {
        final angle = d * math.pi / 4;
        final candidateCenter =
            searchCenter + Offset(r * math.cos(angle), r * math.sin(angle));
        final tl = Offset(
          candidateCenter.dx - width / 2,
          candidateCenter.dy - height / 2,
        );
        if (isValid(Rect.fromLTWH(tl.dx, tl.dy, width, height))) {
          return tl;
        }
      }
    }
    return startTL;
  }

  @override
  State<OverlayLayer> createState() => _OverlayLayerState();
}

class _OverlayLayerState extends State<OverlayLayer> {
  final GlobalKey _contentBoundsKey = GlobalKey();

  Rect? _getContentBounds() {
    final box =
        _contentBoundsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return Rect.fromLTWH(0, 0, box.size.width, box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _contentBoundsKey,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDeselect,
            child: widget.child,
          ),
          for (final image in widget.images)
            EditableOverlayImage(
              key: ValueKey('image_\${image.id}'),
              image: image,
              isSelected: widget.selectedImageId == image.id,
              getBounds: _getContentBounds,
              onSelect: () => widget.onSelectImage(image.id),
              onUpdate: ({
                required id,
                required x,
                required y,
                required scale,
                required rotation,
              }) =>
                  widget.onImageTransform(
                id: id,
                x: x,
                y: y,
                scale: scale,
                rotation: rotation,
              ),
              onRemove: () => widget.onRemoveImage(image.id),
            ),
          for (final sticker in widget.stickers)
            EditableStickerOverlay(
              key: ValueKey('sticker_\${sticker.id}'),
              sticker: sticker,
              isSelected: widget.selectedStickerId == sticker.id,
              getBounds: _getContentBounds,
              onSelect: () => widget.onSelectSticker(sticker.id),
              onUpdate: ({
                required id,
                required x,
                required y,
                required scale,
                required rotation,
              }) =>
                  widget.onStickerTransform(
                id: id,
                x: x,
                y: y,
                scale: scale,
                rotation: rotation,
              ),
              onRemove: () => widget.onRemoveSticker(sticker.id),
            ),
        ],
      ),
    );
  }
}