// lib/features/diary_entry/presentation/widgets/diary_bottom_toolbar.dart

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'font_picker.dart';

/// The single toolbar shown above the keyboard while editing a diary
/// entry's description.
///
/// Two rows, swapped based on whether the Quill selection is currently
/// collapsed (no text selected) or expanded (text selected):
///
/// - No selection → [_CommonToolsRow]: Undo, Redo, **T** (opens the
///   text-formatting panel: alignment / headings / bold+underline /
///   colors — colors here apply to the WHOLE document, since there's
///   no selection to scope them to), **Aa** (font family picker),
///   **Bullet** (opens the list panel: bullet / numbered / checklist),
///   Quote, Divider, then the image/sticker/background buttons.
/// - Text selected → [_SelectionToolsRow]: character-level formatting
///   for the selected run only (style, font color, highlight, clear
///   formatting) — these correctly use `formatSelection`, which is
///   scoped to the actual text selection.
///
/// EXACTLY ONE of {keyboard, an inline panel} is ever showing at a
/// time, enforced by [_ActivePanel] living in this single widget:
/// - Opening any panel (T, Bullet, Font, or the selection row's color
///   panel) unfocuses the editor, closing the keyboard.
/// - Regaining editor focus (the keyboard coming back, e.g. the user
///   tapped back into the text) force-closes whatever panel was open.
///
/// No panel is ever a modal `showModalBottomSheet` — a modal sheet
/// would cover the editor, so the person couldn't see what they're
/// formatting while picking it. Instead every panel (including the
/// font picker, previously its own separate modal sheet) expands
/// *above* this toolbar, like a tab bar's content area, sized to the
/// keyboard's own height so it visually "replaces" the keyboard rather
/// than adding extra space on top of it.
class DiaryBottomToolbar extends StatefulWidget {
  final quill.QuillController controller;
  final FocusNode editorFocusNode;
  final String? selectedFontFamily;
  final ValueChanged<String?> onFontSelected;
  final VoidCallback onBackgroundPressed;
  final VoidCallback onStickerPressed;
  final VoidCallback onOverlayImagePressed;
  final VoidCallback onInlineImagePressed;

  const DiaryBottomToolbar({
    super.key,
    required this.controller,
    required this.editorFocusNode,
    required this.selectedFontFamily,
    required this.onFontSelected,
    required this.onBackgroundPressed,
    required this.onStickerPressed,
    required this.onOverlayImagePressed,
    required this.onInlineImagePressed,
  });

  @override
  State<DiaryBottomToolbar> createState() => _DiaryBottomToolbarState();
}

/// Which inline panel (if any) is currently expanded above the toolbar
/// row. Only one can ever be active — opening a new one replaces
/// whichever was previously open (from either row), and tapping the
/// button that opened the currently-open panel closes it again.
enum _ActivePanel { none, textFormat, list, font, selectionColor }

class _DiaryBottomToolbarState extends State<DiaryBottomToolbar> {
  static const double _barHeight = 48;

  /// Remembers the largest `viewInsets.bottom` seen while the keyboard
  /// was actually up, so an open panel can keep using that height even
  /// after the keyboard is dismissed (dismissing it is exactly what
  /// `_openPanel` does the instant a panel opens, so `viewInsets.bottom`
  /// collapses to 0 within a frame or two and can't be read fresh at
  /// panel-build time).
  double _lastKnownKeyboardHeight = 0;

  /// Fallback used only if a panel is opened before the keyboard has
  /// ever appeared in this session.
  static const double _fallbackPanelHeight = 280;

  _ActivePanel _activePanel = _ActivePanel.none;

  /// Whether the selection row's color panel should show highlight
  /// swatches instead of text-color swatches. Only meaningful while
  /// `_activePanel == _ActivePanel.selectionColor`.
  bool _selectionColorIsHighlight = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.editorFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant DiaryBottomToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.editorFocusNode != widget.editorFocusNode) {
      oldWidget.editorFocusNode.removeListener(_onFocusChanged);
      widget.editorFocusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.editorFocusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  // Only selection changes (collapsed <-> expanded) need to rebuild
  // this widget to swap rows; every other controller change (typing,
  // formatting) is handled by the individual buttons re-reading style
  // state directly, so this listener is intentionally the only thing
  // that calls setState here for controller changes.
  bool _lastHadSelection = false;

  void _onControllerChanged() {
    final hasSelection = !widget.controller.selection.isCollapsed;
    if (hasSelection != _lastHadSelection) {
      // Only swap which row shows (common vs selection tools) — do NOT
      // close whatever panel is open. A panel should only ever close
      // because the user explicitly closes it (tapping its own button
      // again) or because the keyboard comes back (see
      // `_onFocusChanged` below), not as a side effect of the
      // selection collapsing/expanding, which can happen for reasons
      // unrelated to the person wanting the panel gone (e.g. Quill's
      // own internal bookkeeping around a formatting action).
      setState(() => _lastHadSelection = hasSelection);
    }
  }

  /// The editor regaining focus USUALLY means the on-screen keyboard is
  /// (re)appearing (e.g. the user tapped back into the text). But
  /// `QuillController.formatText`/`formatSelection` can also silently
  /// re-focus the editor's own FocusNode internally as part of applying
  /// a format — even while a panel is open and the real on-screen
  /// keyboard is nowhere in sight — which was incorrectly closing the
  /// panel on every Bold/Alignment/etc. tap. Checking
  /// `viewInsets.bottom` alongside `hasFocus` distinguishes "the
  /// keyboard is genuinely up" from "the controller/editor's internal
  /// focus bookkeeping fired" — only the former should close a panel.
  void _onFocusChanged() {
    if (!widget.editorFocusNode.hasFocus || _activePanel == _ActivePanel.none) {
      return;
    }
    // Defer to the next frame: `viewInsets.bottom` at the exact instant
    // focus changes can still reflect the PREVIOUS frame's keyboard
    // state (e.g. still 0 right as a genuine keyboard-driven focus
    // event fires, before the keyboard has animated in) — checking a
    // frame later reads the settled value instead of a transient one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.editorFocusNode.hasFocus || _activePanel == _ActivePanel.none) {
        return;
      }
      final keyboardIsVisible = MediaQuery.of(context).viewInsets.bottom > 100;
      if (keyboardIsVisible) {
        setState(() => _activePanel = _ActivePanel.none);
      }
    });
  }

  /// Opens [panel], or closes it if it's already the one open
  /// (toggle). Always closes the keyboard first when opening, since
  /// keyboard and panel never show at the same time.
  void _openPanel(_ActivePanel panel) {
    final opening = _activePanel != panel;
    if (opening) {
      // Capture the keyboard's current height BEFORE dismissing it, so
      // the panel that's about to open can reuse exactly that height.
      final currentInset = MediaQuery.of(context).viewInsets.bottom;
      if (currentInset > 100) {
        _lastKnownKeyboardHeight = currentInset;
      }
      // Closing the keyboard is what actually removes the on-screen
      // keyboard — losing focus on the Quill editor. This alone would
      // normally re-trigger `_onFocusChanged`, but that listener only
      // acts when focus is GAINED, not lost, so no feedback loop here.
      widget.editorFocusNode.unfocus();
    }
    setState(() {
      _activePanel = opening ? panel : _ActivePanel.none;
    });
  }

  void _openSelectionColorPanel({required bool isHighlight}) {
    final reopeningSamePanel = _activePanel == _ActivePanel.selectionColor &&
        _selectionColorIsHighlight == isHighlight;
    if (reopeningSamePanel) {
      _openPanel(_ActivePanel.selectionColor); // toggles it closed
      return;
    }
    // Opening fresh, or switching between text-color and highlight
    // while already open — either way capture keyboard height /
    // unfocus via the same path as every other panel.
    final currentInset = MediaQuery.of(context).viewInsets.bottom;
    if (currentInset > 100) {
      _lastKnownKeyboardHeight = currentInset;
    }
    widget.editorFocusNode.unfocus();
    setState(() {
      _selectionColorIsHighlight = isHighlight;
      _activePanel = _ActivePanel.selectionColor;
    });
  }

  /// Height used for whichever panel is currently open: the keyboard's
  /// last known height while it was up, or a fixed fallback if the
  /// keyboard hasn't appeared yet this session. Deliberately NOT read
  /// from live `viewInsets.bottom` at build time, since by the time a
  /// panel is visible the keyboard has already been dismissed and that
  /// value would just be 0.
  double get _panelHeight => _lastKnownKeyboardHeight > 100
      ? _lastKnownKeyboardHeight
      : _fallbackPanelHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = !widget.controller.selection.isCollapsed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Inline panel area — sits ABOVE the toolbar row, like a tab
        // bar's content pane, rather than as a modal overlay on top of
        // the editor. AnimatedSize smooths the height change as panels
        // open/close/swap instead of an abrupt jump.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: _activePanel == _ActivePanel.none
              ? const SizedBox(width: double.infinity, height: 0)
              : SizedBox(
                  height: _panelHeight,
                  child: _buildActivePanel(context),
                ),
        ),
        Container(
          height: _barHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: hasSelection
                ? _SelectionToolsRow(
                    key: const ValueKey('selection'),
                    controller: widget.controller,
                    activePanel: _activePanel,
                    onOpenColorPanel: _openSelectionColorPanel,
                  )
                : _CommonToolsRow(
                    key: const ValueKey('common'),
                    controller: widget.controller,
                    activePanel: _activePanel,
                    onOpenPanel: _openPanel,
                    onBackgroundPressed: widget.onBackgroundPressed,
                    onStickerPressed: widget.onStickerPressed,
                    onOverlayImagePressed: widget.onOverlayImagePressed,
                    onInlineImagePressed: widget.onInlineImagePressed,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivePanel(BuildContext context) {
    switch (_activePanel) {
      case _ActivePanel.textFormat:
        return _TextFormatPanel(controller: widget.controller);
      case _ActivePanel.list:
        return _ListPanel(controller: widget.controller);
      case _ActivePanel.font:
        return FontPicker(
          selectedFontFamily: widget.selectedFontFamily,
          onFontSelected: widget.onFontSelected,
        );
      case _ActivePanel.selectionColor:
        return _FontColorPanel(
          controller: widget.controller,
          isHighlight: _selectionColorIsHighlight,
          onDone: () => _openPanel(_ActivePanel.selectionColor),
        );
      case _ActivePanel.none:
        return const SizedBox.shrink();
    }
  }
}

/// Shared small icon-button look used by every button in every row, so
/// spacing/size/ripple stay visually identical throughout the toolbar.
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
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: icon != null
              ? Icon(icon, size: 22, color: color)
              : Text(
                  textLabel!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// Section label used inside the inline panels (e.g. "Alignment",
/// "Headings") to visually group related controls.
class _PanelSectionLabel extends StatelessWidget {
  final String label;

  const _PanelSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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

// ---------------------------------------------------------------------------
// Common tools row (no text selected)
// ---------------------------------------------------------------------------

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

class _CommonToolsRow extends StatefulWidget {
  final quill.QuillController controller;
  final _ActivePanel activePanel;
  final ValueChanged<_ActivePanel> onOpenPanel;
  final VoidCallback onBackgroundPressed;
  final VoidCallback onStickerPressed;
  final VoidCallback onOverlayImagePressed;
  final VoidCallback onInlineImagePressed;

  const _CommonToolsRow({
    super.key,
    required this.controller,
    required this.activePanel,
    required this.onOpenPanel,
    required this.onBackgroundPressed,
    required this.onStickerPressed,
    required this.onOverlayImagePressed,
    required this.onInlineImagePressed,
  });

  @override
  State<_CommonToolsRow> createState() => _CommonToolsRowState();
}

class _CommonToolsRowState extends State<_CommonToolsRow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool _isBlockActive(quill.Attribute attribute) {
    final style = widget.controller.getSelectionStyle();
    final current = style.attributes[attribute.key];
    return current?.value == attribute.value;
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

  bool get _isAnyListActive =>
      _isBlockActive(quill.Attribute.ul) ||
      _isBlockActive(quill.Attribute.ol) ||
      _isBlockActive(quill.Attribute.unchecked) ||
      _isBlockActive(quill.Attribute.checked);

  bool get _isAnyTextFormatActive {
    final style = widget.controller.getSelectionStyle();
    final List<quill.Attribute> tracked = [
      quill.Attribute.align,
      quill.Attribute.header,
      quill.Attribute.bold,
      quill.Attribute.underline,
      quill.Attribute.color,
      quill.Attribute.background,
    ];
    return tracked.any((a) => style.attributes.containsKey(a.key));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarIconButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            onPressed: widget.controller.hasUndo
                ? widget.controller.undo
                : null,
          ),
          _ToolbarIconButton(
            icon: Icons.redo_rounded,
            tooltip: 'Redo',
            onPressed: widget.controller.hasRedo
                ? widget.controller.redo
                : null,
          ),
          const _ToolbarDivider(),
          // T — opens the text-formatting panel (alignment, headings,
          // bold/underline, colors) above this toolbar.
          _ToolbarIconButton(
            textLabel: 'T',
            tooltip: 'Text formatting',
            isActive: widget.activePanel == _ActivePanel.textFormat ||
                _isAnyTextFormatActive,
            onPressed: () => widget.onOpenPanel(_ActivePanel.textFormat),
          ),
          // Aa — font family picker, now an inline panel like T/Bullet
          // instead of its own modal sheet.
          _ToolbarIconButton(
            textLabel: 'Aa',
            tooltip: 'Font',
            isActive: widget.activePanel == _ActivePanel.font,
            onPressed: () => widget.onOpenPanel(_ActivePanel.font),
          ),
          // Bullet — opens the list panel (bullet / numbered /
          // checklist) above this toolbar.
          _ToolbarIconButton(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: 'Lists',
            isActive: widget.activePanel == _ActivePanel.list ||
                _isAnyListActive,
            onPressed: () => widget.onOpenPanel(_ActivePanel.list),
          ),
          _ToolbarIconButton(
            icon: Icons.format_quote_rounded,
            tooltip: 'Quote',
            isActive: _isBlockActive(quill.Attribute.blockQuote),
            onPressed: () {
              final isActive = _isBlockActive(quill.Attribute.blockQuote);
              widget.controller.formatSelection(
                isActive
                    ? quill.Attribute.clone(quill.Attribute.blockQuote, null)
                    : quill.Attribute.blockQuote,
              );
            },
          ),
          _ToolbarIconButton(
            icon: Icons.horizontal_rule_rounded,
            tooltip: 'Divider',
            onPressed: _insertDivider,
          ),
          const _ToolbarDivider(),
          _ToolbarIconButton(
            icon: Icons.image_outlined,
            tooltip: 'Insert photo',
            onPressed: widget.onInlineImagePressed,
          ),
          _ToolbarIconButton(
            icon: Icons.add_photo_alternate_outlined,
            tooltip: 'Floating photo',
            onPressed: widget.onOverlayImagePressed,
          ),
          _ToolbarIconButton(
            icon: Icons.emoji_emotions_outlined,
            tooltip: 'Sticker',
            onPressed: widget.onStickerPressed,
          ),
          _ToolbarIconButton(
            icon: Icons.wallpaper_rounded,
            tooltip: 'Background',
            onPressed: widget.onBackgroundPressed,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text-format panel (opened by "T") — Alignment / Headings / Bold+Underline
// / Colors, sectioned, scrollable, sized to keyboard height by the parent.
//
// Colors in THIS panel apply to the WHOLE document (there's no text
// selection to scope them to when this panel is reachable at all — it
// only shows in the no-selection common row), matching the "set this
// entry's overall text color" intent, distinct from the selection
// row's font-color panel which colors only the selected run.
// ---------------------------------------------------------------------------

class _TextFormatPanel extends StatefulWidget {
  final quill.QuillController controller;

  const _TextFormatPanel({required this.controller});

  @override
  State<_TextFormatPanel> createState() => _TextFormatPanelState();
}

class _TextFormatPanelState extends State<_TextFormatPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String get _currentAlignment {
    final style = widget.controller.getSelectionStyle();
    final value = style.attributes[quill.Attribute.align.key]?.value as String?;
    return value ?? 'left';
  }

  void _setAlignment(quill.Attribute alignment) {
    if (alignment == quill.Attribute.leftAlignment) {
      widget.controller.formatSelection(
        quill.Attribute.clone(quill.Attribute.align, null),
      );
    } else {
      widget.controller.formatSelection(alignment);
    }
  }

  int? get _currentHeaderLevel {
    final style = widget.controller.getSelectionStyle();
    final value = style.attributes[quill.Attribute.header.key]?.value as int?;
    return value;
  }

  void _toggleHeader(int level, quill.Attribute headerAttribute) {
    final isActive = _currentHeaderLevel == level;
    widget.controller.formatSelection(
      isActive
          ? quill.Attribute.clone(quill.Attribute.header, null)
          : headerAttribute,
    );
  }

  bool _isActive(quill.Attribute attribute) {
    final style = widget.controller.getSelectionStyle();
    return style.attributes.containsKey(attribute.key);
  }

  /// Toggles [attribute] across the WHOLE document, not just from the
  /// cursor onward. Same root cause as the color pickers below:
  /// `formatSelection` with a collapsed cursor (always the case here,
  /// since this panel only shows when nothing is selected) only affects
  /// text typed AFTER this point — it never touches text that already
  /// exists, which is why Bold/Underline appeared to do nothing.
  void _toggle(quill.Attribute attribute) {
    final isActive = _isActive(attribute);
    final length = widget.controller.document.length;
    if (length == 0) return;
    widget.controller.formatText(
      0,
      length,
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
  }

  static const List<String> _colorSwatches = [
    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
    '#009688', '#4CAF50', '#FFC107', '#795548',
  ];

  /// Applies [hex] to the WHOLE document, not just the cursor — with a
  /// collapsed selection (no text highlighted, which is always the
  /// case while this panel is even reachable), `formatSelection` only
  /// affects text typed AFTER this point, leaving everything already
  /// written unchanged. Explicitly formatting the full range
  /// (`0` to `document.length`) is what actually recolors existing
  /// text, matching "set this entry's whole-document color".
  void _applyColorToWholeDocument(String hex, {required bool isHighlight}) {
    final length = widget.controller.document.length;
    if (length == 0) return;
    widget.controller.formatText(
      0,
      length,
      isHighlight ? quill.BackgroundAttribute(hex) : quill.ColorAttribute(hex),
    );
  }

  void _clearColorFromWholeDocument({required bool isHighlight}) {
    final length = widget.controller.document.length;
    if (length == 0) return;
    final attribute =
        isHighlight ? quill.Attribute.background : quill.Attribute.color;
    widget.controller.formatText(
      0,
      length,
      quill.Attribute.clone(attribute, null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
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
                      isActive: (alignment.value ?? 'left') ==
                          _currentAlignment,
                      onPressed: () => _setAlignment(alignment),
                    ),
                  ),
              ],
            ),
          ),
          const _PanelSectionLabel('Headings'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _ToolbarIconButton(
                  textLabel: 'H1',
                  tooltip: 'Heading 1',
                  isActive: _currentHeaderLevel == 1,
                  onPressed: () => _toggleHeader(1, quill.Attribute.h1),
                ),
                const SizedBox(width: 4),
                _ToolbarIconButton(
                  textLabel: 'H2',
                  tooltip: 'Heading 2',
                  isActive: _currentHeaderLevel == 2,
                  onPressed: () => _toggleHeader(2, quill.Attribute.h2),
                ),
                const SizedBox(width: 4),
                _ToolbarIconButton(
                  textLabel: 'H3',
                  tooltip: 'Heading 3',
                  isActive: _currentHeaderLevel == 3,
                  onPressed: () => _toggleHeader(3, quill.Attribute.h3),
                ),
              ],
            ),
          ),
          const _PanelSectionLabel('Style'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _ToolbarIconButton(
                  icon: Icons.format_bold_rounded,
                  tooltip: 'Bold',
                  isActive: _isActive(quill.Attribute.bold),
                  onPressed: () => _toggle(quill.Attribute.bold),
                ),
                const SizedBox(width: 4),
                _ToolbarIconButton(
                  icon: Icons.format_underline_rounded,
                  tooltip: 'Underline',
                  isActive: _isActive(quill.Attribute.underline),
                  onPressed: () => _toggle(quill.Attribute.underline),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Colors below apply to the whole entry',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const _PanelSectionLabel('Text color'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _colorSwatches)
                  _ColorSwatch(
                    hex: hex,
                    onTap: () =>
                        _applyColorToWholeDocument(hex, isHighlight: false),
                  ),
                _ClearColorSwatch(
                  onTap: () =>
                      _clearColorFromWholeDocument(isHighlight: false),
                ),
              ],
            ),
          ),
          const _PanelSectionLabel('Highlight color'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _colorSwatches)
                  _ColorSwatch(
                    hex: hex,
                    onTap: () =>
                        _applyColorToWholeDocument(hex, isHighlight: true),
                  ),
                _ClearColorSwatch(
                  onTap: () =>
                      _clearColorFromWholeDocument(isHighlight: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String hex;
  final VoidCallback onTap;

  const _ColorSwatch({required this.hex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000),
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
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
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
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

// ---------------------------------------------------------------------------
// List panel (opened by the bullet button) — Bullet / Numbered / Checklist
// ---------------------------------------------------------------------------

class _ListPanel extends StatefulWidget {
  final quill.QuillController controller;

  const _ListPanel({required this.controller});

  @override
  State<_ListPanel> createState() => _ListPanelState();
}

class _ListPanelState extends State<_ListPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool _isActive(quill.Attribute attribute) {
    final style = widget.controller.getSelectionStyle();
    final current = style.attributes[attribute.key];
    return current?.value == attribute.value;
  }

  void _toggle(quill.Attribute attribute) {
    final isActive = _isActive(attribute);
    widget.controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.format_list_bulleted_rounded),
            title: const Text('Bullet list'),
            trailing: _isActive(quill.Attribute.ul)
                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                : null,
            onTap: () => _toggle(quill.Attribute.ul),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered_rounded),
            title: const Text('Numbered list'),
            trailing: _isActive(quill.Attribute.ol)
                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                : null,
            onTap: () => _toggle(quill.Attribute.ol),
          ),
          ListTile(
            leading: const Icon(Icons.checklist_rounded),
            title: const Text('Checklist'),
            trailing: (_isActive(quill.Attribute.unchecked) ||
                    _isActive(quill.Attribute.checked))
                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                : null,
            onTap: () => _toggle(quill.Attribute.unchecked),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selection tools row (text selected)
// ---------------------------------------------------------------------------

class _SelectionToolsRow extends StatefulWidget {
  final quill.QuillController controller;
  final _ActivePanel activePanel;
  final void Function({required bool isHighlight}) onOpenColorPanel;

  const _SelectionToolsRow({
    super.key,
    required this.controller,
    required this.activePanel,
    required this.onOpenColorPanel,
  });

  @override
  State<_SelectionToolsRow> createState() => _SelectionToolsRowState();
}

class _SelectionToolsRowState extends State<_SelectionToolsRow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _hasAnyCharacterStyle {
    final style = widget.controller.getSelectionStyle();
    final List<quill.Attribute> characterAttributes = [
      quill.Attribute.bold,
      quill.Attribute.italic,
      quill.Attribute.underline,
      quill.Attribute.strikeThrough,
      quill.Attribute.color,
      quill.Attribute.background,
    ];
    return characterAttributes.any(
      (a) => style.attributes.containsKey(a.key),
    );
  }

  void _clearFormatting() {
    final style = widget.controller.getSelectionStyle();
    final List<quill.Attribute> characterAttributes = [
      quill.Attribute.bold,
      quill.Attribute.italic,
      quill.Attribute.underline,
      quill.Attribute.strikeThrough,
      quill.Attribute.color,
      quill.Attribute.background,
    ];
    for (final attribute in characterAttributes) {
      if (style.attributes.containsKey(attribute.key)) {
        widget.controller.formatSelection(quill.Attribute.clone(attribute, null));
      }
    }
  }

  Future<void> _openStylePicker() async {
    final style = widget.controller.getSelectionStyle();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return _StylePickerSheet(
          controller: widget.controller,
          initialStyle: style,
        );
      },
    );
  }

  bool get _hasAnyCharacterStyleExcludingColor {
    final style = widget.controller.getSelectionStyle();
    final List<quill.Attribute> boolAttributes = [
      quill.Attribute.bold,
      quill.Attribute.italic,
      quill.Attribute.underline,
      quill.Attribute.strikeThrough,
    ];
    return boolAttributes.any((a) => style.attributes.containsKey(a.key));
  }

  @override
  Widget build(BuildContext context) {
    final colorPanelOpen = widget.activePanel == _ActivePanel.selectionColor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarIconButton(
            icon: Icons.text_format_rounded,
            tooltip: 'Text style (bold, italic, underline, strikethrough)',
            isActive: _hasAnyCharacterStyleExcludingColor,
            onPressed: _openStylePicker,
          ),
          const _ToolbarDivider(),
          _ToolbarIconButton(
            icon: Icons.format_color_text_rounded,
            tooltip: 'Text color',
            isActive: colorPanelOpen,
            onPressed: () => widget.onOpenColorPanel(isHighlight: false),
          ),
          _ToolbarIconButton(
            icon: Icons.format_color_fill_rounded,
            tooltip: 'Highlight color',
            isActive: colorPanelOpen,
            onPressed: () => widget.onOpenColorPanel(isHighlight: true),
          ),
          const _ToolbarDivider(),
          _ToolbarIconButton(
            icon: Icons.format_clear_rounded,
            tooltip: 'Clear formatting',
            onPressed: _hasAnyCharacterStyle ? _clearFormatting : null,
          ),
        ],
      ),
    );
  }
}

/// Small bottom sheet listing Bold/Italic/Underline/Strikethrough as
/// checkable rows — the selection row's style-picker button. Each row
/// toggles independently and applies immediately.
///
/// This one remains a real `showModalBottomSheet`, unlike every other
/// panel in this file — it's reached only while text IS selected, and
/// covering the editor briefly here doesn't lose the selection (Quill
/// keeps the selection alive under a modal), so there's no "can't see
/// what I'm formatting" problem the inline-panel approach exists to
/// solve for T/Bullet/Font/the-other-color-panel.
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
    return SafeArea(
      child: Padding(
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

/// Font color / highlight color panel for the SELECTION row — applies
/// only to the actual text selection via `formatSelection`, unlike the
/// common toolbar's T-panel colors (which apply document-wide, since
/// no selection exists in that context). Sized to keyboard height by
/// the parent, same as every other panel.
class _FontColorPanel extends StatelessWidget {
  final quill.QuillController controller;
  final bool isHighlight;
  final VoidCallback onDone;

  const _FontColorPanel({
    required this.controller,
    this.isHighlight = false,
    required this.onDone,
  });

  static const List<String> _swatches = [
    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
    '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
    '#FFEB3B', '#FFC107', '#FF9800', '#795548',
    '#9E9E9E', '#607D8B', '#000000', '#FFFFFF',
  ];

  void _apply(String hex) {
    controller.formatSelection(
      isHighlight ? quill.BackgroundAttribute(hex) : quill.ColorAttribute(hex),
    );
  }

  void _clear() {
    final attribute = isHighlight ? quill.Attribute.background : quill.Attribute.color;
    controller.formatSelection(quill.Attribute.clone(attribute, null));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isHighlight ? 'Highlight color' : 'Text color',
                  style: theme.textTheme.titleMedium,
                ),
                TextButton(onPressed: onDone, child: const Text('Done')),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final hex in _swatches)
                      _ColorSwatch(hex: hex, onTap: () => _apply(hex)),
                    _ClearColorSwatch(onTap: _clear),
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

// ---------------------------------------------------------------------------
// Divider embed
// ---------------------------------------------------------------------------

/// A single custom block embed representing a horizontal-rule divider
/// line. Carries no data (`''`) since a divider has no configurable
/// content.
///
/// REQUIRED WIRING: register [DividerEmbedBuilder] in
/// `diary_form_page.dart`'s `_quillEditorConfig.embedBuilders` list:
/// ```dart
/// embedBuilders: [
///   ResizableImageEmbedBuilder(),
///   DividerEmbedBuilder(),
///   ...FlutterQuillEmbeds.editorBuilders(),
/// ],
/// ```
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
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
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