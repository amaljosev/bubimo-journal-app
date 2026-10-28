// lib/features/diary_entry/presentation/widgets/diary_bottom_toolbar.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../theme/domain/entities/rgba_color.dart';
import 'font_picker.dart';

class DiaryPanelRequest {
  final WidgetBuilder content;
  final bool refocusOnClose;

  const DiaryPanelRequest({
    required this.content,
    required this.refocusOnClose,
  });
}

enum _ActiveSlider { none, text, image }

enum _ActivePanel { none, textFormat, list, font, textColor, selectionColor }

@immutable
class _ToolbarSnapshot {
  final bool hasSelection;
  final bool hasUndo;
  final bool hasRedo;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikeThrough;
  final String alignment;
  final String? fontSize;
  final bool hasColor;
  final bool isUl;
  final bool isOl;
  final bool isChecklist;
  final bool isQuote;

  const _ToolbarSnapshot({
    this.hasSelection = false,
    this.hasUndo = false,
    this.hasRedo = false,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikeThrough = false,
    this.alignment = 'left',
    this.fontSize,
    this.hasColor = false,
    this.isUl = false,
    this.isOl = false,
    this.isChecklist = false,
    this.isQuote = false,
  });

  factory _ToolbarSnapshot.fromController(quill.QuillController controller) {
    final style = controller.getSelectionStyle();
    final attrs = style.attributes;

    bool isAttrActive(quill.Attribute attr) {
      final current = attrs[attr.key];
      return current?.value == attr.value;
    }

    return _ToolbarSnapshot(
      hasSelection: !controller.selection.isCollapsed,
      hasUndo: controller.hasUndo,
      hasRedo: controller.hasRedo,
      isBold: attrs.containsKey(quill.Attribute.bold.key),
      isItalic: attrs.containsKey(quill.Attribute.italic.key),
      isUnderline: attrs.containsKey(quill.Attribute.underline.key),
      isStrikeThrough: attrs.containsKey(quill.Attribute.strikeThrough.key),
      alignment:
          (attrs[quill.Attribute.align.key]?.value as String?) ?? 'left',
      fontSize: attrs[quill.Attribute.size.key]?.value as String?,
      hasColor: attrs.containsKey(quill.Attribute.color.key),
      isUl: isAttrActive(quill.Attribute.ul),
      isOl: isAttrActive(quill.Attribute.ol),
      isChecklist:
          isAttrActive(quill.Attribute.unchecked) ||
          isAttrActive(quill.Attribute.checked),
      isQuote: isAttrActive(quill.Attribute.blockQuote),
    );
  }

  bool get isAnyListActive => isUl || isOl || isChecklist;

  bool get isAnyTextFormatActive =>
      isBold ||
      isItalic ||
      isUnderline ||
      alignment != 'left' ||
      fontSize != null ||
      hasColor ||
      isAnyListActive ||
      isQuote;

  bool get hasAnyCharacterStyleExcludingColor =>
      isBold || isItalic || isUnderline || isStrikeThrough;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ToolbarSnapshot &&
          hasSelection == other.hasSelection &&
          hasUndo == other.hasUndo &&
          hasRedo == other.hasRedo &&
          isBold == other.isBold &&
          isItalic == other.isItalic &&
          isUnderline == other.isUnderline &&
          isStrikeThrough == other.isStrikeThrough &&
          alignment == other.alignment &&
          fontSize == other.fontSize &&
          hasColor == other.hasColor &&
          isUl == other.isUl &&
          isOl == other.isOl &&
          isChecklist == other.isChecklist &&
          isQuote == other.isQuote;

  @override
  int get hashCode => Object.hash(
    hasSelection,
    hasUndo,
    hasRedo,
    isBold,
    isItalic,
    isUnderline,
    isStrikeThrough,
    alignment,
    fontSize,
    hasColor,
    isUl,
    isOl,
    isChecklist,
    isQuote,
  );
}

/// Applies paragraph alignment across all lines/blocks in [controller]
/// as well as the current selection, then notifies [onAlignmentChanged]
/// so the title field stays in sync.
void _applyAlignmentToWholeDocument(
  quill.QuillController controller,
  quill.Attribute alignment,
  ValueChanged<String> onAlignmentChanged,
) {
  final value = (alignment.value as String?) ?? 'left';
  final targetAttr = alignment == quill.Attribute.leftAlignment
      ? quill.Attribute.clone(quill.Attribute.align, null)
      : alignment;

  final length = controller.document.length;
  if (length > 0) {
    controller.formatText(0, length, targetAttr);
  }
  controller.formatSelection(targetAttr);
  onAlignmentChanged(value);
}

class DiaryBottomToolbar extends StatefulWidget {
  final quill.QuillController controller;
  final FocusNode editorFocusNode;
  final String? selectedFontFamily;
  final ValueChanged<String?> onFontSelected;
  final ValueChanged<String> onAlignmentChanged;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<bool> onUnderlineChanged;
  final ValueChanged<String?> onFontSizeChanged;
  final ValueChanged<String?> onTextColorChanged;
  final VoidCallback onBackgroundPressed;
  final VoidCallback onStickerPressed;
  final VoidCallback onOverlayImagePressed;
  final VoidCallback onInlineImagePressed;
  final ValueChanged<DiaryPanelRequest?> onPanelRequested;

  const DiaryBottomToolbar({
    super.key,
    required this.controller,
    required this.editorFocusNode,
    required this.selectedFontFamily,
    required this.onFontSelected,
    required this.onAlignmentChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onUnderlineChanged,
    required this.onFontSizeChanged,
    required this.onTextColorChanged,
    required this.onBackgroundPressed,
    required this.onStickerPressed,
    required this.onOverlayImagePressed,
    required this.onInlineImagePressed,
    required this.onPanelRequested,
  });

  @override
  State<DiaryBottomToolbar> createState() => DiaryBottomToolbarState();
}

class DiaryBottomToolbarState extends State<DiaryBottomToolbar> {
  static const double _barHeight = 56;
  static const double _sliderHeight = 48;

  static const double totalHeight = _barHeight + 28;

  static const Duration _tapLockDuration = Duration(milliseconds: 500);

  late final ValueNotifier<_ToolbarSnapshot> _snapshotNotifier;

  _ActiveSlider _activeSlider = _ActiveSlider.none;
  _ActivePanel _activePanel = _ActivePanel.none;

  Timer? _tapLockTimer;
  bool get _isTapLocked => _tapLockTimer?.isActive ?? false;

  @override
  void initState() {
    super.initState();
    _snapshotNotifier = ValueNotifier(
      _ToolbarSnapshot.fromController(widget.controller),
    );
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant DiaryBottomToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _snapshotNotifier.value = _ToolbarSnapshot.fromController(
        widget.controller,
      );
    }
  }

  @override
  void dispose() {
    _tapLockTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    _snapshotNotifier.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final next = _ToolbarSnapshot.fromController(widget.controller);
    final previousHadSelection = _snapshotNotifier.value.hasSelection;

    if (next.hasSelection != previousHadSelection && next.hasSelection) {
      widget.editorFocusNode.unfocus();
      if (_activeSlider != _ActiveSlider.none) {
        setState(() => _activeSlider = _ActiveSlider.none);
      }
    }
    _snapshotNotifier.value = next;
  }

  void _guardedTap(VoidCallback action) {
    if (_isTapLocked) return;
    _tapLockTimer = Timer(_tapLockDuration, () {});
    action();
  }

  void _toggleSlider(_ActiveSlider slider) {
    if (_activePanel != _ActivePanel.none) {
      _activePanel = _ActivePanel.none;
      widget.onPanelRequested(null);
    }

    setState(() {
      _activeSlider = (_activeSlider == slider) ? _ActiveSlider.none : slider;
    });
  }

  void _requestPanel(
    _ActivePanel panel,
    WidgetBuilder builder, {
    required bool refocusOnClose,
  }) {
    _guardedTap(() {
      setState(() => _activePanel = panel);
      widget.onPanelRequested(
        DiaryPanelRequest(content: builder, refocusOnClose: refocusOnClose),
      );
    });
  }

  void closeActivePanel() {
    if (_activePanel == _ActivePanel.none &&
        _activeSlider == _ActiveSlider.none) {
      return;
    }
    final hadPanel = _activePanel != _ActivePanel.none;
    setState(() {
      _activePanel = _ActivePanel.none;
      _activeSlider = _ActiveSlider.none;
    });
    if (hadPanel) {
      widget.onPanelRequested(null);
    }
  }

  void closeActivePanelAndRestoreFocus() => closeActivePanel();

  void _openTextFormatPanel() {
    _requestPanel(
      _ActivePanel.textFormat,
      (_) => _TextFormatPanel(
        controller: widget.controller,
        snapshotListenable: _snapshotNotifier,
        onAlignmentChanged: widget.onAlignmentChanged,
        onBoldChanged: widget.onBoldChanged,
        onItalicChanged: widget.onItalicChanged,
        onUnderlineChanged: widget.onUnderlineChanged,
        onFontSizeChanged: widget.onFontSizeChanged,
      ),
      refocusOnClose: true,
    );
  }

  void _openListPanel() {
    _requestPanel(
      _ActivePanel.list,
      (_) => _ListPanel(
        controller: widget.controller,
        snapshotListenable: _snapshotNotifier,
        onDone: () {
          setState(() => _activePanel = _ActivePanel.none);
          widget.onPanelRequested(null);
        },
      ),
      refocusOnClose: false,
    );
  }

  void _openFontPanel() {
    _requestPanel(
      _ActivePanel.font,
      (_) => FontPicker(
        selectedFontFamily: widget.selectedFontFamily,
        onFontSelected: widget.onFontSelected,
      ),
      refocusOnClose: false,
    );
  }

  void _openTextColorPanel() {
    _requestPanel(
      _ActivePanel.textColor,
      (_) => _DocumentColorPanel(
        controller: widget.controller,
        onTextColorChanged: widget.onTextColorChanged,
      ),
      refocusOnClose: false,
    );
  }

  void _openSelectionColorPanel({required bool isHighlight}) {
    _requestPanel(
      _ActivePanel.selectionColor,
      (_) => _FontColorPanel(
        controller: widget.controller,
        isHighlight: isHighlight,
      ),
      refocusOnClose: true,
    );
  }

  void _openStylePicker() {
    final style = widget.controller.getSelectionStyle();
    _requestPanel(
      _ActivePanel.selectionColor,
      (_) => _StylePickerSheet(
        controller: widget.controller,
        initialStyle: style,
      ),
      refocusOnClose: true,
    );
  }

  void _toggleWholeDocAttribute(
    quill.Attribute attribute,
    bool currentlyActive,
    ValueChanged<bool> onChanged,
  ) {
    final length = widget.controller.document.length;
    final nowActive = !currentlyActive;
    final targetAttr =
        currentlyActive ? quill.Attribute.clone(attribute, null) : attribute;

    if (length > 0) {
      widget.controller.formatText(0, length, targetAttr);
    }
    widget.controller.formatSelection(targetAttr);
    onChanged(nowActive);
  }

  void _cycleAlignment(String currentAlignment) {
    final nextIndex = switch (currentAlignment) {
      'left' => 1,
      'center' => 2,
      'right' => 3,
      _ => 0,
    };
    _applyAlignmentToWholeDocument(
      widget.controller,
      _alignmentCycle[nextIndex],
      widget.onAlignmentChanged,
    );
  }

  void _cycleFontSize(String? currentFontSize) {
    final currentIndex = _fontSizeOptions.indexWhere(
      (o) => o.value == currentFontSize,
    );
    final nextIndex = (currentIndex + 1) % _fontSizeOptions.length;
    final nextValue = _fontSizeOptions[nextIndex].value;

    final length = widget.controller.document.length;
    final attr = nextValue == null
        ? quill.Attribute.clone(quill.Attribute.size, null)
        : quill.Attribute(
            quill.Attribute.size.key,
            quill.AttributeScope.inline,
            nextValue,
          );
    if (length > 0) {
      widget.controller.formatText(0, length, attr);
    }
    widget.controller.formatSelection(attr);
    widget.onFontSizeChanged(nextValue);
  }

  void _toggleQuote(bool currentlyActive) {
    widget.controller.formatSelection(
      currentlyActive
          ? quill.Attribute.clone(quill.Attribute.blockQuote, null)
          : quill.Attribute.blockQuote,
    );
  }

  void _insertDivider() {
    final index = widget.controller.selection.baseOffset.clamp(
      0,
      widget.controller.document.length,
    );
    widget.controller.replaceText(
      index,
      0,
      DividerEmbed.instance,
      TextSelection.collapsed(offset: index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              // Borderless floating elevation using dual ambient + contact shadows
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: isDark ? 0.38 : 0.14,
                  ),
                  blurRadius: 28,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: isDark ? 0.22 : 0.06,
                  ),
                  blurRadius: 8,
                  spreadRadius: -1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: ValueListenableBuilder<_ToolbarSnapshot>(
                valueListenable: _snapshotNotifier,
                builder: (context, snapshot, _) {
                  final showSlider =
                      !snapshot.hasSelection &&
                      _activeSlider != _ActiveSlider.none;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hide-and-Seek Sliding Tray (Borderless soft floating inner pill)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.bottomCenter,
                        child: showSlider
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: isDark ? 0.12 : 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: SizedBox(
                                    height: _sliderHeight,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) {
                                        final slide = Tween<Offset>(
                                          begin: const Offset(0.06, 0.22),
                                          end: Offset.zero,
                                        ).animate(animation);
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: slide,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _activeSlider == _ActiveSlider.text
                                          ? _TextOptionsSlider(
                                              key: const ValueKey('slider_t'),
                                              snapshot: snapshot,
                                              activePanel: _activePanel,
                                              selectedFontFamily:
                                                  widget.selectedFontFamily,
                                              onOpenFontPanel: _openFontPanel,
                                              onOpenTextColorPanel:
                                                  _openTextColorPanel,
                                              onOpenTextFormatPanel:
                                                  _openTextFormatPanel,
                                              onOpenListPanel: _openListPanel,
                                              onToggleBold: () =>
                                                  _toggleWholeDocAttribute(
                                                    quill.Attribute.bold,
                                                    snapshot.isBold,
                                                    widget.onBoldChanged,
                                                  ),
                                              onToggleItalic: () =>
                                                  _toggleWholeDocAttribute(
                                                    quill.Attribute.italic,
                                                    snapshot.isItalic,
                                                    widget.onItalicChanged,
                                                  ),
                                              onToggleUnderline: () =>
                                                  _toggleWholeDocAttribute(
                                                    quill.Attribute.underline,
                                                    snapshot.isUnderline,
                                                    widget.onUnderlineChanged,
                                                  ),
                                              onCycleAlignment: () =>
                                                  _cycleAlignment(
                                                    snapshot.alignment,
                                                  ),
                                              onCycleFontSize: () =>
                                                  _cycleFontSize(
                                                    snapshot.fontSize,
                                                  ),
                                              onToggleQuote: () => _toggleQuote(
                                                snapshot.isQuote,
                                              ),
                                              onInsertDivider: _insertDivider,
                                            )
                                          : _ImageOptionsSlider(
                                              key: const ValueKey('slider_img'),
                                              onInlineImagePressed: () {
                                                setState(
                                                  () => _activeSlider =
                                                      _ActiveSlider.none,
                                                );
                                                _guardedTap(
                                                  widget.onInlineImagePressed,
                                                );
                                              },
                                              onOverlayImagePressed: () {
                                                setState(
                                                  () => _activeSlider =
                                                      _ActiveSlider.none,
                                                );
                                                _guardedTap(
                                                  widget.onOverlayImagePressed,
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Primary Floating Bar
                      SizedBox(
                        height: _barHeight,
                        child: AnimatedSwitcher(
                          duration: ThemeDurations.fast,
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: snapshot.hasSelection
                              ? _SelectionToolsRow(
                                  key: const ValueKey('row_selection'),
                                  snapshot: snapshot,
                                  activePanel: _activePanel,
                                  onOpenStylePicker: _openStylePicker,
                                  onOpenColorPanel: _openSelectionColorPanel,
                                )
                              : _PrimaryCategoryRow(
                                  key: const ValueKey('row_primary'),
                                  snapshot: snapshot,
                                  activeSlider: _activeSlider,
                                  onUndo: snapshot.hasUndo
                                      ? widget.controller.undo
                                      : null,
                                  onRedo: snapshot.hasRedo
                                      ? widget.controller.redo
                                      : null,
                                  onToggleTextSlider: () =>
                                      _toggleSlider(_ActiveSlider.text),
                                  onToggleImageSlider: () =>
                                      _toggleSlider(_ActiveSlider.image),
                                  onStickerPressed: () {
                                    closeActivePanel();
                                    _guardedTap(widget.onStickerPressed);
                                  },
                                  onBackgroundPressed: () {
                                    closeActivePanel();
                                    _guardedTap(widget.onBackgroundPressed);
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryCategoryRow extends StatelessWidget {
  final _ToolbarSnapshot snapshot;
  final _ActiveSlider activeSlider;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onToggleTextSlider;
  final VoidCallback onToggleImageSlider;
  final VoidCallback onStickerPressed;
  final VoidCallback onBackgroundPressed;

  const _PrimaryCategoryRow({
    super.key,
    required this.snapshot,
    required this.activeSlider,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleTextSlider,
    required this.onToggleImageSlider,
    required this.onStickerPressed,
    required this.onBackgroundPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isTextOpen = activeSlider == _ActiveSlider.text;
    final isImageOpen = activeSlider == _ActiveSlider.image;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarIconButton(
                icon: Icons.undo_rounded,
                tooltip: 'Undo',
                onPressed: onUndo,
              ),
              const SizedBox(width: 2),
              _ToolbarIconButton(
                icon: Icons.redo_rounded,
                tooltip: 'Redo',
                onPressed: onRedo,
              ),
            ],
          ),
          const _ToolbarDotSeparator(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CategoryToggleButton(
                  textLabel: 'T',
                  tooltip: 'Text options',
                  isOpen: isTextOpen,
                  hasActiveDot: !isTextOpen && snapshot.isAnyTextFormatActive,
                  onPressed: onToggleTextSlider,
                ),
                _CategoryToggleButton(
                  icon: Icons.image_outlined,
                  tooltip: 'Photo options',
                  isOpen: isImageOpen,
                  onPressed: onToggleImageSlider,
                ),
                _ToolbarIconButton(
                  icon: Icons.auto_awesome_outlined,
                  tooltip: 'Stickers',
                  onPressed: onStickerPressed,
                ),
                _ToolbarIconButton(
                  icon: CupertinoIcons.layers,
                  tooltip: 'Background',
                  onPressed: onBackgroundPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextOptionsSlider extends StatelessWidget {
  final _ToolbarSnapshot snapshot;
  final _ActivePanel activePanel;
  final String? selectedFontFamily;
  final VoidCallback onOpenFontPanel;
  final VoidCallback onOpenTextColorPanel;
  final VoidCallback onOpenTextFormatPanel;
  final VoidCallback onOpenListPanel;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final VoidCallback onCycleAlignment;
  final VoidCallback onCycleFontSize;
  final VoidCallback onToggleQuote;
  final VoidCallback onInsertDivider;

  const _TextOptionsSlider({
    super.key,
    required this.snapshot,
    required this.activePanel,
    required this.selectedFontFamily,
    required this.onOpenFontPanel,
    required this.onOpenTextColorPanel,
    required this.onOpenTextFormatPanel,
    required this.onOpenListPanel,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onCycleAlignment,
    required this.onCycleFontSize,
    required this.onToggleQuote,
    required this.onInsertDivider,
  });

  String get _fontSizeLabel {
    for (final option in _fontSizeOptions) {
      if (option.value == snapshot.fontSize) return option.label;
    }
    return 'M';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarIconButton(
            textLabel: 'Aa',
            tooltip: 'Font family',
            isActive:
                activePanel == _ActivePanel.font || selectedFontFamily != null,
            onPressed: onOpenFontPanel,
          ),
          _ToolbarIconButton(
            icon: Icons.format_color_text_rounded,
            tooltip: 'Text color',
            isActive: activePanel == _ActivePanel.textColor || snapshot.hasColor,
            onPressed: onOpenTextColorPanel,
          ),
          _ToolbarIconButton(
            textLabel: _fontSizeLabel,
            tooltip: 'Cycle font size ($_fontSizeLabel)',
            isActive: snapshot.fontSize != null,
            onPressed: onCycleFontSize,
          ),
          const _ToolbarDotSeparator(),
          _ToolbarIconButton(
            icon: Icons.format_bold_rounded,
            tooltip: 'Bold',
            isActive: snapshot.isBold,
            onPressed: onToggleBold,
          ),
          _ToolbarIconButton(
            icon: Icons.format_italic_rounded,
            tooltip: 'Italic',
            isActive: snapshot.isItalic,
            onPressed: onToggleItalic,
          ),
          _ToolbarIconButton(
            icon: Icons.format_underline_rounded,
            tooltip: 'Underline',
            isActive: snapshot.isUnderline,
            onPressed: onToggleUnderline,
          ),
          _ToolbarIconButton(
            icon: _alignmentIcons[snapshot.alignment] ??
                Icons.format_align_left_rounded,
            tooltip: 'Alignment (${snapshot.alignment})',
            isActive: snapshot.alignment != 'left',
            onPressed: onCycleAlignment,
          ),
          const _ToolbarDotSeparator(),
          _ToolbarIconButton(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: 'Lists',
            isActive:
                activePanel == _ActivePanel.list || snapshot.isAnyListActive,
            onPressed: onOpenListPanel,
          ),
          _ToolbarIconButton(
            icon: Icons.format_quote_rounded,
            tooltip: 'Quote',
            isActive: snapshot.isQuote,
            onPressed: onToggleQuote,
          ),
          _ToolbarIconButton(
            icon: Icons.horizontal_rule_rounded,
            tooltip: 'Divider',
            onPressed: onInsertDivider,
          ),
          _ToolbarIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'All text format options',
            isActive: activePanel == _ActivePanel.textFormat,
            onPressed: onOpenTextFormatPanel,
          ),
        ],
      ),
    );
  }
}

class _ImageOptionsSlider extends StatelessWidget {
  final VoidCallback onInlineImagePressed;
  final VoidCallback onOverlayImagePressed;

  const _ImageOptionsSlider({
    super.key,
    required this.onInlineImagePressed,
    required this.onOverlayImagePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: _SlideActionPill(
              icon: Icons.art_track_rounded,
              label: 'Inline Photo',
              onTap: onInlineImagePressed,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SlideActionPill(
              icon: Icons.filter_none_rounded,
              label: 'Sticky Photo',
              onTap: onOverlayImagePressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SlideActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryToggleButton extends StatelessWidget {
  final IconData? icon;
  final String? textLabel;
  final String tooltip;
  final bool isOpen;
  final bool hasActiveDot;
  final VoidCallback onPressed;

  const _CategoryToggleButton({
    this.icon,
    this.textLabel,
    required this.tooltip,
    required this.isOpen,
    this.hasActiveDot = false,
    required this.onPressed,
  }) : assert(icon != null || textLabel != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fgColor = isOpen ? colorScheme.onPrimary : colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: isOpen ? 14 : 10),
          decoration: BoxDecoration(
            color: isOpen ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (icon != null)
                    Icon(icon, size: 22, color: fgColor)
                  else
                    Text(
                      textLabel!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: fgColor,
                      ),
                    ),
                  if (hasActiveDot)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: isOpen
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: fgColor,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData? icon;
  final String? textLabel;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;

  const _ToolbarIconButton({
    this.icon,
    this.textLabel,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  }) : assert(
         icon != null || textLabel != null,
         'Provide either icon or textLabel',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null;
    final color = isEnabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.28);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: ThemeDurations.fast,
          curve: Curves.easeOut,
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: icon != null
              ? Icon(icon, size: 21, color: color)
              : Text(
                  textLabel!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Subtle dot separator instead of a hard vertical line, preserving the
/// borderless floating feel.
class _ToolbarDotSeparator extends StatelessWidget {
  const _ToolbarDotSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PanelSectionLabel extends StatelessWidget {
  final String label;

  const _PanelSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ThemeSpacing.lg,
        ThemeSpacing.md,
        ThemeSpacing.lg,
        ThemeSpacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

const List<quill.Attribute> _alignmentCycle = [
  quill.Attribute.leftAlignment,
  quill.Attribute.centerAlignment,
  quill.Attribute.rightAlignment,
  quill.Attribute.justifyAlignment,
];

const Map<String, IconData> _alignmentIcons = {
  'left': Icons.format_align_left_rounded,
  'center': Icons.format_align_center_rounded,
  'right': Icons.format_align_right_rounded,
  'justify': Icons.format_align_justify_rounded,
};

const List<({String label, String? value})> _fontSizeOptions = [
  (label: 'S', value: '12'),
  (label: 'M', value: null),
  (label: 'L', value: '20'),
  (label: 'XL', value: '28'),
];

class _TextFormatPanel extends StatelessWidget {
  final quill.QuillController controller;
  final ValueListenable<_ToolbarSnapshot> snapshotListenable;
  final ValueChanged<String> onAlignmentChanged;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<bool> onUnderlineChanged;
  final ValueChanged<String?> onFontSizeChanged;

  const _TextFormatPanel({
    required this.controller,
    required this.snapshotListenable,
    required this.onAlignmentChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onUnderlineChanged,
    required this.onFontSizeChanged,
  });

  void _toggle(quill.Attribute attribute, bool isActive) {
    final length = controller.document.length;
    final nowActive = !isActive;
    final targetAttr =
        isActive ? quill.Attribute.clone(attribute, null) : attribute;
    if (length > 0) {
      controller.formatText(0, length, targetAttr);
    }
    controller.formatSelection(targetAttr);

    if (attribute.key == quill.Attribute.bold.key) {
      onBoldChanged(nowActive);
    } else if (attribute.key == quill.Attribute.italic.key) {
      onItalicChanged(nowActive);
    } else if (attribute.key == quill.Attribute.underline.key) {
      onUnderlineChanged(nowActive);
    }
  }

  void _applyFontSizeToWholeDocument(String? value) {
    final length = controller.document.length;
    final attr = value == null
        ? quill.Attribute.clone(quill.Attribute.size, null)
        : quill.Attribute(
            quill.Attribute.size.key,
            quill.AttributeScope.inline,
            value,
          );
    if (length > 0) {
      controller.formatText(0, length, attr);
    }
    controller.formatSelection(attr);
    onFontSizeChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_ToolbarSnapshot>(
      valueListenable: snapshotListenable,
      builder: (context, snapshot, _) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelSectionLabel('Alignment'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final alignment in _alignmentCycle)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _ToolbarIconButton(
                          icon: _alignmentIcons[
                              (alignment.value as String?) ?? 'left'],
                          tooltip: (alignment.value as String?) ?? 'left',
                          isActive:
                              (alignment.value ?? 'left') == snapshot.alignment,
                          onPressed: () => _applyAlignmentToWholeDocument(
                            controller,
                            alignment,
                            onAlignmentChanged,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const _PanelSectionLabel('Font size'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final option in _fontSizeOptions)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _ToolbarIconButton(
                          textLabel: option.label,
                          tooltip: option.label,
                          isActive: option.value == snapshot.fontSize,
                          onPressed: () =>
                              _applyFontSizeToWholeDocument(option.value),
                        ),
                      ),
                  ],
                ),
              ),
              const _PanelSectionLabel('Style'),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Row(
                  children: [
                    _ToolbarIconButton(
                      icon: Icons.format_bold_rounded,
                      tooltip: 'Bold',
                      isActive: snapshot.isBold,
                      onPressed: () =>
                          _toggle(quill.Attribute.bold, snapshot.isBold),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarIconButton(
                      icon: Icons.format_italic_rounded,
                      tooltip: 'Italic',
                      isActive: snapshot.isItalic,
                      onPressed: () =>
                          _toggle(quill.Attribute.italic, snapshot.isItalic),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarIconButton(
                      icon: Icons.format_underline_rounded,
                      tooltip: 'Underline',
                      isActive: snapshot.isUnderline,
                      onPressed: () => _toggle(
                        quill.Attribute.underline,
                        snapshot.isUnderline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const List<(AppColorRole role, String label)> _colorRoleOptions = [
  (AppColorRole.text, 'Text'),
  (AppColorRole.primary, 'Primary'),
  (AppColorRole.secondary, 'Secondary'),
  (AppColorRole.surface, 'Surface'),
  (AppColorRole.background, 'Background'),
];

class _ColorRoleSelector extends StatelessWidget {
  final AppColorRole selectedRole;
  final ValueChanged<AppColorRole> onRoleChanged;

  const _ColorRoleSelector({
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in _colorRoleOptions)
            Padding(
              padding: const EdgeInsets.only(right: ThemeSpacing.sm),
              child: ChoiceChip(
                label: Text(option.$2),
                selected: selectedRole == option.$1,
                onSelected: (_) => onRoleChanged(option.$1),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: selectedRole == option.$1
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThemeRadii.sm),
                ),
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                side: BorderSide.none,
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentColorPanel extends StatefulWidget {
  final quill.QuillController controller;
  final ValueChanged<String?> onTextColorChanged;

  const _DocumentColorPanel({
    required this.controller,
    required this.onTextColorChanged,
  });

  @override
  State<_DocumentColorPanel> createState() => _DocumentColorPanelState();
}

class _DocumentColorPanelState extends State<_DocumentColorPanel> {
  AppColorRole _selectedRole = AppColorRole.text;

  void _applyToWholeDocument(String hex) {
    final length = widget.controller.document.length;
    final attr = quill.ColorAttribute(hex);
    if (length > 0) {
      widget.controller.formatText(0, length, attr);
    }
    widget.controller.formatSelection(attr);
    widget.onTextColorChanged(hex);
  }

  void _clearFromWholeDocument() {
    final length = widget.controller.document.length;
    final attr = quill.Attribute.clone(quill.Attribute.color, null);
    if (length > 0) {
      widget.controller.formatText(0, length, attr);
    }
    widget.controller.formatSelection(attr);
    widget.onTextColorChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final swatches = AppColors.forRole(_selectedRole, isDark: isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Text color', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _ColorRoleSelector(
            selectedRole: _selectedRole,
            onRoleChanged: (role) => setState(() => _selectedRole = role),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final swatch in swatches)
                    _RgbaColorSwatch(
                      color: swatch,
                      onTap: () => _applyToWholeDocument(_toHex(swatch)),
                    ),
                  _ClearColorSwatch(onTap: _clearFromWholeDocument),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _toHex(RgbaColor rgbaColor) {
  final r = rgbaColor.red.clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final g = rgbaColor.green.clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final b = rgbaColor.blue.clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

class _RgbaColorSwatch extends StatelessWidget {
  final RgbaColor color;
  final VoidCallback onTap;

  const _RgbaColorSwatch({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.toColor(),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.14),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearColorSwatch extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearColorSwatch({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.format_color_reset_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ListPanel extends StatelessWidget {
  final quill.QuillController controller;
  final ValueListenable<_ToolbarSnapshot> snapshotListenable;
  final VoidCallback onDone;

  const _ListPanel({
    required this.controller,
    required this.snapshotListenable,
    required this.onDone,
  });

  void _toggleAndClose(quill.Attribute attribute, bool isActive) {
    controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_ToolbarSnapshot>(
      valueListenable: snapshotListenable,
      builder: (context, snapshot, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: ThemeSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ListOptionRow(
                icon: Icons.format_list_bulleted_rounded,
                label: 'Bullet list',
                isActive: snapshot.isUl,
                onTap: () => _toggleAndClose(quill.Attribute.ul, snapshot.isUl),
              ),
              _ListOptionRow(
                icon: Icons.format_list_numbered_rounded,
                label: 'Numbered list',
                isActive: snapshot.isOl,
                onTap: () => _toggleAndClose(quill.Attribute.ol, snapshot.isOl),
              ),
              _ListOptionRow(
                icon: Icons.checklist_rounded,
                label: 'Checklist',
                isActive: snapshot.isChecklist,
                onTap: () => _toggleAndClose(
                  quill.Attribute.unchecked,
                  snapshot.isChecklist,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ListOptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ListOptionRow({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ThemeSpacing.xs / 2),
      child: Material(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ThemeRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ThemeSpacing.md,
              vertical: ThemeSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: ThemeSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isActive)
                  Icon(Icons.check_rounded, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionToolsRow extends StatelessWidget {
  final _ToolbarSnapshot snapshot;
  final _ActivePanel activePanel;
  final VoidCallback onOpenStylePicker;
  final void Function({required bool isHighlight}) onOpenColorPanel;

  const _SelectionToolsRow({
    super.key,
    required this.snapshot,
    required this.activePanel,
    required this.onOpenStylePicker,
    required this.onOpenColorPanel,
  });

  @override
  Widget build(BuildContext context) {
    final colorPanelOpen = activePanel == _ActivePanel.selectionColor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarIconButton(
            icon: Icons.text_format_rounded,
            tooltip: 'Text style (bold, italic, underline, strikethrough)',
            isActive: snapshot.hasAnyCharacterStyleExcludingColor,
            onPressed: onOpenStylePicker,
          ),
          const _ToolbarDotSeparator(),
          _ToolbarIconButton(
            icon: Icons.format_color_text_rounded,
            tooltip: 'Text color',
            isActive: colorPanelOpen,
            onPressed: () => onOpenColorPanel(isHighlight: false),
          ),
          _ToolbarIconButton(
            icon: Icons.format_color_fill_rounded,
            tooltip: 'Highlight color',
            isActive: colorPanelOpen,
            onPressed: () => onOpenColorPanel(isHighlight: true),
          ),
        ],
      ),
    );
  }
}

class _StylePickerSheet extends StatefulWidget {
  final quill.QuillController controller;
  final quill.Style initialStyle;

  const _StylePickerSheet({
    required this.controller,
    required this.initialStyle,
  });

  @override
  State<_StylePickerSheet> createState() => _StylePickerSheetState();
}

class _StylePickerSheetState extends State<_StylePickerSheet> {
  late quill.Style _style = widget.initialStyle;

  bool _isActive(quill.Attribute attribute) =>
      _style.attributes.containsKey(attribute.key);

  void _toggle(quill.Attribute attribute) {
    final isActive = _isActive(attribute);
    widget.controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
    setState(() => _style = widget.controller.getSelectionStyle());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StyleRow(
            icon: Icons.format_bold_rounded,
            label: 'Bold',
            isActive: _isActive(quill.Attribute.bold),
            onTap: () => _toggle(quill.Attribute.bold),
          ),
          _StyleRow(
            icon: Icons.format_italic_rounded,
            label: 'Italic',
            isActive: _isActive(quill.Attribute.italic),
            onTap: () => _toggle(quill.Attribute.italic),
          ),
          _StyleRow(
            icon: Icons.format_underline_rounded,
            label: 'Underline',
            isActive: _isActive(quill.Attribute.underline),
            onTap: () => _toggle(quill.Attribute.underline),
          ),
          _StyleRow(
            icon: Icons.format_strikethrough_rounded,
            label: 'Strikethrough',
            isActive: _isActive(quill.Attribute.strikeThrough),
            onTap: () => _toggle(quill.Attribute.strikeThrough),
          ),
        ],
      ),
    );
  }
}

class _StyleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _StyleRow({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurface),
      title: Text(label),
      trailing: isActive
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _FontColorPanel extends StatefulWidget {
  final quill.QuillController controller;
  final bool isHighlight;

  const _FontColorPanel({required this.controller, this.isHighlight = false});

  @override
  State<_FontColorPanel> createState() => _FontColorPanelState();
}

class _FontColorPanelState extends State<_FontColorPanel> {
  AppColorRole _selectedRole = AppColorRole.text;

  void _apply(String hex) {
    widget.controller.formatSelection(
      widget.isHighlight
          ? quill.BackgroundAttribute(hex)
          : quill.ColorAttribute(hex),
    );
  }

  void _clear() {
    final attribute = widget.isHighlight
        ? quill.Attribute.background
        : quill.Attribute.color;
    widget.controller.formatSelection(quill.Attribute.clone(attribute, null));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final swatches = AppColors.forRole(_selectedRole, isDark: isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isHighlight ? 'Highlight color' : 'Text color',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _ColorRoleSelector(
            selectedRole: _selectedRole,
            onRoleChanged: (role) => setState(() => _selectedRole = role),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final swatch in swatches)
                    _RgbaColorSwatch(
                      color: swatch,
                      onTap: () => _apply(_toHex(swatch)),
                    ),
                  _ClearColorSwatch(onTap: _clear),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DividerEmbed extends quill.CustomBlockEmbed {
  static const String dividerType = 'divider';

  const DividerEmbed() : super(dividerType, '');

  static quill.BlockEmbed get instance =>
      quill.BlockEmbed.custom(const DividerEmbed());
}

class DividerEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => DividerEmbed.dividerType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}