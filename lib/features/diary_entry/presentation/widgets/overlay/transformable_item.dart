// lib/features/diary_entry/presentation/widgets/overlay/transformable_item.dart

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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

/// Claims victory in the Gesture Arena as soon as a pointer touches down on
/// the sticker/image body, preventing the ancestor [SingleChildScrollView]'s
/// [VerticalDragGestureRecognizer] from stealing upward/downward drags.
class _EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Claims victory in the Gesture Arena for the bottom-right rotate/resize
/// handle so vertical handle drags are never stolen by the scroll view.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

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
  bool _isHandleActive = false;
  bool _didTransform = false;

  Offset? _lastFocalPoint;
  double _initialScaleOnGesture = 1.0;
  double _initialRotationOnGesture = 0.0;

  late Offset _handleDragStartGlobal;
  late Offset _handleCentreGlobal;
  late double _handleStartScale;
  late double _handleStartRotation;
  late double _handleStartDistance;

  late final AnimationController _handleAnim;
  late final Animation<double> _handleScale;

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
    if (widget.initialPosition != old.initialPosition) {
      _position = widget.initialPosition;
    }
    if (widget.initialScale != old.initialScale) {
      _scale = widget.initialScale;
    }
    if (widget.initialRotation != old.initialRotation) {
      _rotation = widget.initialRotation;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (_isHandleActive) return;
    if (!widget.isSelected) {
      widget.onSelect();
    }
    _isDragging = true;
    _didTransform = false;
    _lastFocalPoint = d.focalPoint;
    _initialScaleOnGesture = _scale;
    _initialRotationOnGesture = _rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_isHandleActive || _lastFocalPoint == null) return;
    final delta = d.focalPoint - _lastFocalPoint!;
    _lastFocalPoint = d.focalPoint;

    if (d.pointerCount == 1) {
      if (delta == Offset.zero) return;
      final nextPos = _clampToBounds(_position + delta);
      if (nextPos != _position) {
        _didTransform = true;
        setState(() => _position = nextPos);
      }
    } else {
      final nextScale = (_initialScaleOnGesture * d.scale).clamp(0.2, 6.0);
      final nextRotation = _initialRotationOnGesture + d.rotation;
      final nextPos = _clampToBounds(_position + delta);
      _didTransform = true;
      setState(() {
        _scale = nextScale;
        _rotation = nextRotation;
        _position = nextPos;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails _) {
    if (_isHandleActive) return;
    _isDragging = false;
    _lastFocalPoint = null;
    if (_didTransform) {
      _didTransform = false;
      _commit();
    }
  }

  void _onHandleDragStart(DragStartDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    _isHandleActive = true;
    _isDragging = true;
    _handleAnim.forward();
    HapticFeedback.lightImpact();

    _handleDragStartGlobal = d.globalPosition;
    _handleStartScale = _scale;
    _handleStartRotation = _rotation;

    _handleCentreGlobal = box.localToGlobal(
      Offset(
        TransformableItem.handlePadding + _visualWidth / 2,
        TransformableItem.handlePadding + _visualHeight / 2,
      ),
    );

    final startVec = d.globalPosition - _handleCentreGlobal;
    _handleStartDistance = startVec.distance.clamp(10.0, double.infinity);
  }

  void _onHandleDragUpdate(DragUpdateDetails d) {
    if (!_isHandleActive) return;

    final startVec = _handleDragStartGlobal - _handleCentreGlobal;
    final currentVec = d.globalPosition - _handleCentreGlobal;

    final angleDelta = math.atan2(
      startVec.dx * currentVec.dy - startVec.dy * currentVec.dx,
      startVec.dx * currentVec.dx + startVec.dy * currentVec.dy,
    );

    final currentDist = currentVec.distance.clamp(10.0, double.infinity);
    final scaleFactor = currentDist / _handleStartDistance;
    final newScale = (_handleStartScale * scaleFactor).clamp(0.2, 6.0);

    setState(() {
      _rotation = _handleStartRotation + angleDelta;
      _scale = newScale;
      _position = _clampToBounds(_position);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

    final displayChild = widget.isSelected
        ? CustomPaint(
            painter: DashedBorderPainter(
              color: theme.colorScheme.primary,
              strokeWidth: 1.5,
              gap: 5,
            ),
            child: paddedChild,
          )
        : paddedChild;

    final bodyGesture = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _EagerScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerScaleGestureRecognizer>(
              _EagerScaleGestureRecognizer.new,
              (_EagerScaleGestureRecognizer instance) {
                instance
                  ..onStart = _onScaleStart
                  ..onUpdate = _onScaleUpdate
                  ..onEnd = _onScaleEnd;
              },
            ),
      },
      child: displayChild,
    );

    return Positioned(
      left: _position.dx - TransformableItem.handlePadding,
      top: _position.dy - TransformableItem.handlePadding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bodyGesture,
          if (widget.isSelected) ...[
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
            Positioned(
              bottom: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _handleScale,
                builder: (_, child) =>
                    Transform.scale(scale: _handleScale.value, child: child),
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: <Type, GestureRecognizerFactory>{
                    _EagerPanGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _EagerPanGestureRecognizer
                        >(_EagerPanGestureRecognizer.new, (
                          _EagerPanGestureRecognizer instance,
                        ) {
                          instance
                            ..onStart = _onHandleDragStart
                            ..onUpdate = _onHandleDragUpdate
                            ..onEnd = _onHandleDragEnd;
                        }),
                  },
                  child: _CombinedHandle(
                    color: theme.colorScheme,
                    isActive: _isHandleActive,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
        behavior: HitTestBehavior.opaque,
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

class _CombinedHandle extends StatelessWidget {
  final ColorScheme color;
  final bool isActive;

  const _CombinedHandle({required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    const double r = TransformableItem._handleRadius;
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