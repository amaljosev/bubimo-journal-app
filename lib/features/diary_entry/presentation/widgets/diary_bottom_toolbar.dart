// lib/features/diary_entry/presentation/widgets/diary_bottom_toolbar.dart

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/theme/app_colors.dart';
import '../../../theme/domain/entities/rgba_color.dart';
import 'font_picker.dart';

/// The single toolbar shown above the keyboard while editing a diary
/// entry's description.
///
/// Two rows, swapped based on whether the Quill selection is currently
/// collapsed (no text selected) or expanded (text selected):
///
/// - No selection → [_CommonToolsRow]: Undo, Redo, **T** (opens the
///   text-formatting panel: alignment / font size / bold / italic /
///   underline — nothing else lives in this sheet anymore), **Aa**
///   (font family picker), **A with a color swatch** (text color —
///   its own dedicated toolbar item, applying to the whole document),
///   **Bullet** (opens the list panel: bullet / numbered / checklist),
///   Quote, Divider, then the image/sticker/background buttons.
/// - Text selected → [_SelectionToolsRow]: character-level formatting
///   for the selected run only (style, font color, highlight) — these
///   correctly use `formatSelection`, which is scoped to the actual
///   text selection. The old trailing "Clear formatting" button has
///   been removed — it never worked (there's no reliable way to know
///   the pre-formatting state to clear back to from this row), and its
///   job is already covered by toggling each active style off
///   individually.
///
/// EXACTLY ONE of {keyboard, an inline panel, the native text-selection
/// toolbar} is ever showing at a time, enforced by [_ActivePanel] living
/// in this single widget:
/// - Opening any panel (T, Bullet, Font, Text color, or the selection
///   row's color panel) unfocuses the editor, closing the keyboard.
/// - Regaining editor focus (the keyboard coming back, e.g. the user
///   tapped back into the text) force-closes whatever panel was open.
/// - The Quill selection becoming non-collapsed (the user selected
///   text, which is about to show the native text-selection toolbar)
///   also unfocuses the editor first, so the on-screen keyboard never
///   overlaps that native toolbar.
///
/// No panel is ever a modal `showModalBottomSheet` — a modal sheet
/// would cover the editor, so the person couldn't see what they're
/// formatting while picking it. Instead every panel (including the
/// font picker and the new text-color panel) expands *above* this
/// toolbar, like a tab bar's content area, sized to the keyboard's own
/// height so it visually "replaces" the keyboard rather than adding
/// extra space on top of it. Tapping the editor area above dismisses
/// whichever panel is open (the parent form page calls
/// [DiaryBottomToolbarState.closeActivePanel] via a `GlobalKey` from a
/// `GestureDetector` wrapping the editor), giving inline panels the
/// same "tap outside to dismiss" feel a modal sheet would have had.
class DiaryBottomToolbar extends StatefulWidget {
  final quill.QuillController controller;
  final FocusNode editorFocusNode;
  final String? selectedFontFamily;
  final ValueChanged<String?> onFontSelected;

  /// Fired whenever the user changes alignment from the T panel.
  /// [alignment] is `'left'`, `'center'`, `'right'`, or `'justify'` —
  /// the parent form page is responsible for both applying it to the
  /// title field (as `TextAlign`) and dispatching it to
  /// `DiaryFormBloc`, since alignment is meant to apply to the whole
  /// entry, not just the Quill description this toolbar sits under.
  final ValueChanged<String> onAlignmentChanged;

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
    required this.onAlignmentChanged,
    required this.onBackgroundPressed,
    required this.onStickerPressed,
    required this.onOverlayImagePressed,
    required this.onInlineImagePressed,
  });

  @override
  State<DiaryBottomToolbar> createState() => DiaryBottomToolbarState();
}

/// Which inline panel (if any) is currently expanded above the toolbar
/// row. Only one can ever be active — opening a new one replaces
/// whichever was previously open (from either row), and tapping the
/// button that opened the currently-open panel closes it again.
enum _ActivePanel { none, textFormat, list, font, textColor, selectionColor }

class DiaryBottomToolbarState extends State<DiaryBottomToolbar> {
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
      // A fresh text selection is about to show the native
      // text-selection toolbar (copy/cut/paste bubble). Unfocus the
      // editor's FocusNode right away so the on-screen keyboard drops
      // before that native toolbar appears — the two must never be on
      // screen together. This does NOT clear the Quill selection
      // itself (selection state lives in `controller.selection`, not
      // in focus), so the selected text and its native toolbar are
      // unaffected; only the software keyboard goes away.
      if (hasSelection) {
        widget.editorFocusNode.unfocus();
      }
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

  /// Closes whatever panel is currently open, if any — used before
  /// performing an action that doesn't itself open a panel (Quote,
  /// Divider) so a stale panel doesn't linger on screen once the
  /// editor content has changed underneath it, and used by the
  /// "tap the editor to dismiss" gesture the parent form page wires up
  /// via [DiaryBottomToolbarState.closeActivePanel].
  void closeActivePanel() {
    if (_activePanel != _ActivePanel.none) {
      setState(() => _activePanel = _ActivePanel.none);
    }
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
                    onClosePanel: closeActivePanel,
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
        return _TextFormatPanel(
          controller: widget.controller,
          onAlignmentChanged: widget.onAlignmentChanged,
        );
      case _ActivePanel.list:
        return _ListPanel(
          controller: widget.controller,
          onStyleSelected: () => _openPanel(_ActivePanel.list),
        );
      case _ActivePanel.font:
        return FontPicker(
          selectedFontFamily: widget.selectedFontFamily,
          onFontSelected: widget.onFontSelected,
        );
      case _ActivePanel.textColor:
        return _DocumentColorPanel(controller: widget.controller);
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
/// "Font size") to visually group related controls.
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
  final VoidCallback onClosePanel;
  final VoidCallback onBackgroundPressed;
  final VoidCallback onStickerPressed;
  final VoidCallback onOverlayImagePressed;
  final VoidCallback onInlineImagePressed;

  const _CommonToolsRow({
    super.key,
    required this.controller,
    required this.activePanel,
    required this.onOpenPanel,
    required this.onClosePanel,
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
    // Quote/Divider both act immediately on the document rather than
    // opening a panel of their own — but a DIFFERENT panel (T, Bullet,
    // Font, Text color) might already be open from a previous tap.
    // Close it first so the toolbar doesn't end up showing a stale
    // panel above content that's just changed underneath it.
    widget.onClosePanel();
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

  void _toggleQuote() {
    // Same reasoning as `_insertDivider` — close any open panel before
    // toggling the block quote.
    widget.onClosePanel();
    final isActive = _isBlockActive(quill.Attribute.blockQuote);
    widget.controller.formatSelection(
      isActive
          ? quill.Attribute.clone(quill.Attribute.blockQuote, null)
          : quill.Attribute.blockQuote,
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
      quill.Attribute.size,
      quill.Attribute.bold,
      quill.Attribute.italic,
      quill.Attribute.underline,
    ];
    return tracked.any((a) => style.attributes.containsKey(a.key));
  }

  bool get _hasDocumentTextColor {
    final style = widget.controller.getSelectionStyle();
    return style.attributes.containsKey(quill.Attribute.color.key);
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
          // T — opens the text-formatting panel: alignment, font size,
          // bold, italic, underline. Nothing else lives here anymore —
          // headings and both color sections have their own entry
          // points (colors moved to the dedicated "Text color" button
          // below; there's no headings button in this redesign).
          _ToolbarIconButton(
            textLabel: 'T',
            tooltip: 'Text formatting',
            isActive: widget.activePanel == _ActivePanel.textFormat ||
                _isAnyTextFormatActive,
            onPressed: () => widget.onOpenPanel(_ActivePanel.textFormat),
          ),
          // Aa — font family picker, an inline panel like T/Bullet.
          _ToolbarIconButton(
            textLabel: 'Aa',
            tooltip: 'Font',
            isActive: widget.activePanel == _ActivePanel.font,
            onPressed: () => widget.onOpenPanel(_ActivePanel.font),
          ),
          // Text color — its own dedicated toolbar item (previously
          // buried inside the T panel). Applies to the whole document,
          // since this button only appears in the no-selection row.
          _ToolbarIconButton(
            icon: Icons.format_color_text_rounded,
            tooltip: 'Text color',
            isActive: widget.activePanel == _ActivePanel.textColor ||
                _hasDocumentTextColor,
            onPressed: () => widget.onOpenPanel(_ActivePanel.textColor),
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
            onPressed: _toggleQuote,
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
// Text-format panel (opened by "T") — Alignment / Font size / Bold / Italic
// / Underline ONLY. Headings and colors have both been removed from this
// sheet: headings had no home elsewhere in this redesign's requirements and
// are dropped; colors now live in the dedicated "Text color" toolbar button
// (see `_DocumentColorPanel`) and the selection row's existing color panel.
// ---------------------------------------------------------------------------

/// Font sizes offered in the T panel. `flutter_quill`'s `SizeAttribute`
/// takes a numeric point-size string (e.g. `'20'`), NOT the
/// `small`/`large`/`huge` CSS-class keywords from Quill.js on the web —
/// those keywords are a different (web-only) attributor convention and
/// aren't what this package's own editor/toolbar renders by default.
/// "Normal" clears the attribute back to the document's base font size
/// rather than setting an explicit value.
const List<({String label, String? value})> _fontSizeOptions = [
  (label: 'S', value: '12'),
  (label: 'M', value: null), // Normal / default
  (label: 'L', value: '20'),
  (label: 'XL', value: '28'),
];

class _TextFormatPanel extends StatefulWidget {
  final quill.QuillController controller;
  final ValueChanged<String> onAlignmentChanged;

  const _TextFormatPanel({
    required this.controller,
    required this.onAlignmentChanged,
  });

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
    final value = (alignment.value as String?) ?? 'left';
    if (alignment == quill.Attribute.leftAlignment) {
      widget.controller.formatSelection(
        quill.Attribute.clone(quill.Attribute.align, null),
      );
    } else {
      widget.controller.formatSelection(alignment);
    }
    // Alignment applies to the whole entry, not just this Quill
    // description — the title field is plain text, so it can't carry
    // a Quill attribute. The parent form page listens for this and
    // both dispatches `DiaryFormAlignmentChanged` to the bloc and
    // applies the resulting `TextAlign` to the title's `TextField`.
    widget.onAlignmentChanged(value);
  }

  String? get _currentFontSize {
    final style = widget.controller.getSelectionStyle();
    return style.attributes[quill.Attribute.size.key]?.value as String?;
  }

  bool _isActive(quill.Attribute attribute) {
    final style = widget.controller.getSelectionStyle();
    return style.attributes.containsKey(attribute.key);
  }

  /// Toggles [attribute] across the WHOLE document, not just from the
  /// cursor onward. With a collapsed cursor (always the case here,
  /// since this panel only shows when nothing is selected),
  /// `formatSelection` only affects text typed AFTER this point — it
  /// never touches text that already exists, which is why Bold/Italic/
  /// Underline would otherwise appear to do nothing.
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

  /// Applies [value] (a numeric point-size string, or `null` to clear
  /// back to the default size) across the WHOLE document — same
  /// collapsed-cursor reasoning as `_toggle` above: this panel only
  /// shows with nothing selected, so `formatSelection` alone would
  /// only affect text typed from here on, not what's already written.
  void _applyFontSizeToWholeDocument(String? value) {
    final length = widget.controller.document.length;
    if (length == 0) return;
    widget.controller.formatText(
      0,
      length,
      value == null
          ? quill.Attribute.clone(quill.Attribute.size, null)
          : quill.Attribute(
              quill.Attribute.size.key,
              quill.AttributeScope.inline,
              value,
            ),
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
                      isActive: option.value == _currentFontSize,
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
                  isActive: _isActive(quill.Attribute.bold),
                  onPressed: () => _toggle(quill.Attribute.bold),
                ),
                const SizedBox(width: 4),
                _ToolbarIconButton(
                  icon: Icons.format_italic_rounded,
                  tooltip: 'Italic',
                  isActive: _isActive(quill.Attribute.italic),
                  onPressed: () => _toggle(quill.Attribute.italic),
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text color panel (opened by the new dedicated "Text color" toolbar
// button) — applies to the WHOLE document, same scoping rule the old
// in-T-panel color sections used, since this button only ever appears
// in the no-selection common row. Swatches are sourced from
// `AppColors.forRole(AppColorRole.text, ...)` rather than a hardcoded
// hex list, per the app's single-source-of-truth palette rule.
// ---------------------------------------------------------------------------

class _DocumentColorPanel extends StatefulWidget {
  final quill.QuillController controller;

  const _DocumentColorPanel({required this.controller});

  @override
  State<_DocumentColorPanel> createState() => _DocumentColorPanelState();
}

class _DocumentColorPanelState extends State<_DocumentColorPanel> {
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

  void _applyToWholeDocument(String hex) {
    final length = widget.controller.document.length;
    if (length == 0) return;
    widget.controller.formatText(0, length, quill.ColorAttribute(hex));
  }

  void _clearFromWholeDocument() {
    final length = widget.controller.document.length;
    if (length == 0) return;
    widget.controller.formatText(
      0,
      length,
      quill.Attribute.clone(quill.Attribute.color, null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final swatches =
        AppColors.forRole(AppColorRole.text, isDark: isDark);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Text color', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
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
      ),
    );
  }
}

/// Converts an [RgbaColor] to the `#RRGGBB` hex string Quill's
/// `ColorAttribute`/`BackgroundAttribute` expect. `RgbaColor` only
/// exposes `.toColor()` (a Flutter `Color`), not a hex string directly,
/// so this small helper bridges the two at the one place in the
/// toolbar that needs it. Opacity is intentionally dropped — Quill's
/// color attributes are opaque RGB hex only.
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.toColor(),
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
// List panel (opened by the bullet button) — Bullet / Numbered / Checklist.
// Selecting any style now closes the panel automatically afterward.
// ---------------------------------------------------------------------------

class _ListPanel extends StatefulWidget {
  final quill.QuillController controller;

  /// Called right after a style is applied, so the parent can close
  /// this panel — the list panel is a one-shot picker (per req #7:
  /// "after the user selects a bullet style, automatically close the
  /// bottom sheet"), unlike T/Font/Text-color which stay open for
  /// multiple adjustments.
  final VoidCallback onStyleSelected;

  const _ListPanel({required this.controller, required this.onStyleSelected});

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
    widget.onStyleSelected();
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
          // The old trailing "Clear formatting" button has been
          // removed entirely (req #9) — it was the last button in this
          // row and didn't work reliably, and toggling each active
          // style back off individually (via the style picker or these
          // color buttons' own "clear" swatch) already covers the same
          // need.
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
/// solve for T/Bullet/Font/Text-color/the-selection-color-panel.
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
/// common toolbar's dedicated "Text color" button (which applies
/// document-wide, since no selection exists in that context). Sized to
/// keyboard height by the parent, same as every other panel. Swatches
/// are sourced from `AppColors` rather than a hardcoded hex list, same
/// as `_DocumentColorPanel` — text color uses the text role for both;
/// highlight reuses the same text-role palette since there's no
/// dedicated "highlight" role in `AppColors`.
class _FontColorPanel extends StatelessWidget {
  final quill.QuillController controller;
  final bool isHighlight;
  final VoidCallback onDone;

  const _FontColorPanel({
    required this.controller,
    this.isHighlight = false,
    required this.onDone,
  });

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
    final isDark = theme.brightness == Brightness.dark;
    final swatches = AppColors.forRole(AppColorRole.text, isDark: isDark);

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