// lib/features/diary_entry/presentation/widgets/overlay/transformable_item.dart
//
// Ported from the old project's canvas-editor implementation. Fully
// generic — no coupling to any domain entity — so it's reused as-is to
// drive drag / pinch / rotate / resize for overlay images in the new
// flutter_quill-based editor.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dashed_border_painter.dart';

typedef ItemTransformUpdate =
    void Function({
      required String id,
      required double x,
      required double y,
      required double scale,
      required double rotation,
    });

class TransformableItem extends StatefulWidget {
  final String id;
  final Widget child;
  final Offset initialPosition;
  final double initialScale;
  final double initialRotation;
  final bool isSelected;
  final ItemTransformUpdate onUpdate;
  final VoidCallback onRemove;
  final VoidCallback onSelect;
  final double? baseWidth;
  final double? baseHeight;
  final ValueGetter<Rect?>? getBounds;

  static const double stickerBaseSize = 100.0;
  static const double handlePadding = 22.0;
  static const double _handleRadius = 15.0;

  const TransformableItem({
    super.key,
    required this.id,
    required this.child,
    required this.initialPosition,
    required this.initialScale,
    required this.initialRotation,
    required this.isSelected,
    required this.onUpdate,
    required this.onRemove,
    required this.onSelect,
    this.baseWidth,
    this.baseHeight,
    this.getBounds,
  });

  @override
  State<TransformableItem> createState() => _TransformableItemState();
}

class _TransformableItemState extends State<TransformableItem>
    with SingleTickerProviderStateMixin {
  late Offset _position;
  late double _scale;
  late double _rotation;

  bool _isDragging = false;
  bool _isHandleActive = false; // true while the combined handle is held

  // Main drag/pinch
  Offset? _lastFocalPoint;
  double _initialScaleOnGesture = 1.0;
  double _initialRotationOnGesture = 0.0;

  // Combined handle state
  // We record the finger's global position and the item's state at drag-start,
  // then each frame we:
  //   1. Compute angle from item-centre → finger  (→ drives rotation)
  //   2. Compute distance from item-centre → finger (→ drives scale)
  late Offset _handleDragStartGlobal;
  late double _handleStartScale;
  late double _handleStartRotation;
  late double
  _handleStartDistance; // distance at drag-start (divisor for scale)

  // Handle press animation
  late AnimationController _handleAnim;
  late Animation<double> _handleScale;

  // ── Geometry ───────────────────────────────────────────────────────────────

  double get _visualWidth =>
      (widget.baseWidth ?? TransformableItem.stickerBaseSize) * _scale;
  double get _visualHeight =>
      (widget.baseHeight ?? TransformableItem.stickerBaseSize) * _scale;

  Offset _clampToBounds(Offset pos) {
    final bounds = widget.getBounds?.call();
    if (bounds == null) return pos;
    return Offset(
      pos.dx.clamp(0.0, math.max(0.0, bounds.width - _visualWidth)),
      pos.dy.clamp(0.0, math.max(0.0, bounds.height - _visualHeight)),
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _scale = widget.initialScale;
    _rotation = widget.initialRotation;

    _handleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _handleScale = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _handleAnim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _handleAnim.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TransformableItem old) {
    super.didUpdateWidget(old);
    if (_isDragging || _isHandleActive) return;
    if (widget.initialPosition != old.initialPosition)
      _position = widget.initialPosition;
    if (widget.initialScale != old.initialScale) _scale = widget.initialScale;
    if (widget.initialRotation != old.initialRotation)
      _rotation = widget.initialRotation;
  }

  // ── Main drag / two-finger pinch ───────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    if (_isHandleActive) return;
    _isDragging = true;
    _lastFocalPoint = d.focalPoint;
    _initialScaleOnGesture = _scale;
    _initialRotationOnGesture = _rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_isHandleActive) return;
    final delta = d.focalPoint - _lastFocalPoint!;
    if (d.pointerCount == 1) {
      setState(() {
        _position = _clampToBounds(_position + delta);
        _lastFocalPoint = d.focalPoint;
      });
    } else {
      setState(() {
        _scale = (_initialScaleOnGesture * d.scale).clamp(0.2, 6.0);
        _rotation = _initialRotationOnGesture + d.rotation;
        _position = _clampToBounds(_position + delta);
        _lastFocalPoint = d.focalPoint;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails _) {
    if (_isHandleActive) return;
    _isDragging = false;
    _commit();
  }

  // ── Combined rotate + resize handle ────────────────────────────────────────
  //
  // UX model (same as PicsArt / Unfold / most diary sticker editors):
  //
  //   • The handle sits at the bottom-right corner.
  //   • On drag-start we record:
  //       – the vector from item-centre → handle position (gives start angle & distance)
  //   • Each frame we compute the vector from item-centre → current finger.
  //       – angleDelta  = currentAngle  - startAngle   → added to rotation
  //       – scaleFactor = currentDist   / startDist    → multiplied onto scale
  //
  // This feels exactly like you're physically spinning and stretching the item
  // from its corner — the same physical intuition as a real piece of paper.

  void _onHandleDragStart(DragStartDetails d) {
    _isHandleActive = true;
    _isDragging = true;
    _handleAnim.forward();
    HapticFeedback.lightImpact();

    _handleDragStartGlobal = d.globalPosition;
    _handleStartScale = _scale;
    _handleStartRotation = _rotation;

    // Convert global handle position to the coordinate space of the
    // description Stack (which is the parent of this Positioned widget).
    // We only need the start distance; the start angle is implicitly 0
    // (we measure all subsequent angles relative to the start vector).
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Item centre in global coordinates
    final centreGlobal = box.localToGlobal(
      Offset(
        TransformableItem.handlePadding + _visualWidth / 2,
        TransformableItem.handlePadding + _visualHeight / 2,
      ),
    );

    final startVec = d.globalPosition - centreGlobal;
    _handleStartDistance = startVec.distance.clamp(10.0, double.infinity);
  }

  void _onHandleDragUpdate(DragUpdateDetails d) {
    if (!_isHandleActive) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Item centre in global coords (recalculate each frame because scale changes)
    final centreGlobal = box.localToGlobal(
      Offset(
        TransformableItem.handlePadding + _visualWidth / 2,
        TransformableItem.handlePadding + _visualHeight / 2,
      ),
    );

    final startVec = _handleDragStartGlobal - centreGlobal;
    final currentVec = d.globalPosition - centreGlobal;

    // Rotation: signed angle between start vector and current vector
    final angleDelta = math.atan2(
      startVec.dx * currentVec.dy - startVec.dy * currentVec.dx, // cross
      startVec.dx * currentVec.dx + startVec.dy * currentVec.dy, // dot
    );

    // Scale: ratio of distances
    final currentDist = currentVec.distance.clamp(10.0, double.infinity);
    final scaleFactor = currentDist / _handleStartDistance;
    final newScale = (_handleStartScale * scaleFactor).clamp(0.2, 6.0);

    setState(() {
      _rotation = _handleStartRotation + angleDelta;
      _scale = newScale;
    });
  }

  void _onHandleDragEnd(DragEndDetails _) {
    _isHandleActive = false;
    _isDragging = false;
    _handleAnim.reverse();
    HapticFeedback.selectionClick();
    _commit();
  }

  void _commit() {
    widget.onUpdate(
      id: widget.id,
      x: _position.dx,
      y: _position.dy,
      scale: _scale,
      rotation: _rotation,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ── Content ────────────────────────────────────────────────────────────
    Widget content = widget.baseWidth != null && widget.baseHeight != null
        ? SizedBox(
            width: _visualWidth,
            height: _visualHeight,
            child: widget.child,
          )
        : Container(
            width: _visualWidth,
            height: _visualHeight,
            alignment: Alignment.center,
            child: FittedBox(fit: BoxFit.scaleDown, child: widget.child),
          );

    content = Transform.rotate(angle: _rotation, child: content);

    final paddedChild = Padding(
      padding: const EdgeInsets.all(TransformableItem.handlePadding),
      child: content,
    );

    Widget displayChild = widget.isSelected
        ? CustomPaint(
            painter: DashedBorderPainter(
              color: theme.colorScheme.primary,
              strokeWidth: 1.5,
              gap: 5,
            ),
            child: paddedChild,
          )
        : paddedChild;

    // ── Handles ────────────────────────────────────────────────────────────
    final handles = <Widget>[displayChild];

    if (widget.isSelected) {
      // ✕  Delete — top-left
      handles.add(
        Positioned(
          top: 0,
          left: 0,
          child: _HandleButton(
            onTap: widget.onRemove,
            backgroundColor: Colors.red,
            icon: Icons.close_rounded,
            tooltip: 'Remove',
          ),
        ),
      );

      handles.add(
        Positioned(
          bottom: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _handleScale,
            builder: (_, child) =>
                Transform.scale(scale: _handleScale.value, child: child),
            child: GestureDetector(
              onPanStart: _onHandleDragStart,
              onPanUpdate: _onHandleDragUpdate,
              onPanEnd: _onHandleDragEnd,
              child: _CombinedHandle(
                color: theme.colorScheme,
                isActive: _isHandleActive,
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: _position.dx - TransformableItem.handlePadding,
      top: _position.dy - TransformableItem.handlePadding,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Stack(clipBehavior: Clip.none, children: handles),
      ),
    );
  }
}

// ── Delete handle ──────────────────────────────────────────────────────────────

class _HandleButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final IconData icon;
  final String tooltip;

  const _HandleButton({
    required this.onTap,
    required this.backgroundColor,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: TransformableItem._handleRadius * 2,
          height: TransformableItem._handleRadius * 2,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}

// ── Combined rotate+resize handle ─────────────────────────────────────────────
// Shows a two-arrow arc icon (rotate) with a small resize pip — same visual

class _CombinedHandle extends StatelessWidget {
  final ColorScheme color;
  final bool isActive;

  const _CombinedHandle({required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final double r = TransformableItem._handleRadius;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(
        color: isActive ? color.primary.withValues(alpha: 0.85) : color.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.4 : 0.25),
            blurRadius: isActive ? 10 : 6,
            spreadRadius: isActive ? 1 : 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.open_in_full_rounded, color: color.onPrimary, size: 16),
    );
  }
}
