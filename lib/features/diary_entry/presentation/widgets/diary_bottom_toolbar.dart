// lib/features/diary_entry/presentation/widgets/diary_bottom_toolbar.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../theme/domain/entities/rgba_color.dart';
import 'font_picker.dart';

/// A request from [DiaryBottomToolbar] to its host page to show one of
/// its panels — Font, Text color, Lists, Text formatting, or the
/// selection-scoped style/color panels.
///
/// This toolbar does not present any UI for these panels itself
/// (no `showModalBottomSheet`, no route of any kind). Routed sheets
/// necessarily animate in *after* the keyboard has started closing —
/// there's no way to make a `Navigator` push and a platform keyboard's
/// own close animation land in the same frame, so there's always a
/// visible beat where the keyboard is still partially up while the
/// sheet is already sliding in.
///
/// Instead, the toolbar hands the host page a [content] builder plus
/// [refocusOnClose], and the host page is responsible for rendering it
/// in-place — same screen, same frame as the unfocus, replacing the
/// keyboard's own footprint rather than animating a new route over
/// top of it. See `_DiaryFormViewState`'s handling of
/// `onPanelRequested` in diary_form_page.dart for the actual overlay.
class DiaryPanelRequest {
  final WidgetBuilder content;

  /// Whether the editor should regain keyboard focus once this panel
  /// is dismissed. `true` for panels where the user is likely
  /// mid-composition and about to keep typing (text formatting,
  /// selection-scoped style/color). `false` for preview/apply panels
  /// (Font, Text color, Lists) where forcing the keyboard back open
  /// would undo the point of having closed it.
  final bool refocusOnClose;

  const DiaryPanelRequest({
    required this.content,
    required this.refocusOnClose,
  });
}

/// The single toolbar shown above the keyboard while editing a diary
/// entry's description.
///
/// Two rows, swapped based on whether the Quill selection is currently
/// collapsed (no text selected) or expanded (text selected):
///
/// - No selection → [_CommonToolsRow]: Undo, Redo, **T** (opens the
///   text-formatting panel: alignment / font size / bold / italic /
///   underline — nothing else lives in it anymore), **Aa** (font
///   family picker), **A with a color swatch** (text color — its own
///   dedicated toolbar item, applying to the whole document),
///   **Bullet** (opens the list panel: bullet / numbered / checklist),
///   Quote, Divider, then the image/sticker/background buttons.
/// - Text selected → [_SelectionToolsRow]: character-level formatting
///   for the selected run only (style, font color, highlight) — these
///   correctly use `formatSelection`, which is scoped to the actual
///   text selection.
///
/// Every panel (T, Font, Text color, Lists, and the selection row's
/// color panel and style picker) is requested via [onPanelRequested]
/// and rendered by the host page — see [DiaryPanelRequest] for why.
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

  /// Fired whenever Bold/Italic/Underline are toggled from the T
  /// panel. Same "whole entry" reasoning as [onAlignmentChanged] — the
  /// title field can't carry a Quill attribute of its own, so the
  /// parent form page mirrors these onto the title's `TextStyle` in
  /// addition to whatever this toolbar already applied to the Quill
  /// description.
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<bool> onUnderlineChanged;

  /// Fired when a font size is picked in the T panel. `null` means
  /// "Normal" (clear back to default). Value is a numeric point-size
  /// string (see `_fontSizeOptions`) — the parent parses it to a
  /// `double` for the title's `TextStyle.fontSize`.
  final ValueChanged<String?> onFontSizeChanged;

  /// Fired when a color is picked (or cleared, passing `null`) in the
  /// dedicated "Text color" panel. Value is a `#RRGGBB` hex string.
  final ValueChanged<String?> onTextColorChanged;

  final VoidCallback onBackgroundPressed;
  final VoidCallback onStickerPressed;
  final VoidCallback onOverlayImagePressed;
  final VoidCallback onInlineImagePressed;

  /// Called with a [DiaryPanelRequest] when a toolbar button wants to
  /// open a panel, and with `null` when the toolbar wants it closed
  /// (e.g. the List panel closes itself right after a tap — see
  /// `_ListPanel._toggleAndClose`). The host page owns actually
  /// rendering/dismissing the panel; this toolbar only ever reports
  /// open/close intent.
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

/// Which panel (if any) is currently open — drives both the relevant
/// toolbar button's active/highlighted state and, via
/// [DiaryBottomToolbarState.closeActivePanel], tells the host page to
/// dismiss whatever it's currently showing.
enum _ActivePanel { none, textFormat, list, font, textColor, selectionColor }

class DiaryBottomToolbarState extends State<DiaryBottomToolbar> {
  static const double _barHeight = 60;

  /// This toolbar's total vertical footprint — the fixed `10`-logical-pixel
  /// top/bottom padding plus the bar itself — *excluding* the device's own
  /// bottom safe-area inset, since that's consumed by this widget's own
  /// [SafeArea] and isn't something the host page needs to additionally
  /// account for. Exposed so [DiaryFormPage]'s description scroll view can
  /// reserve exactly this much space (via `scrollBottomInset`/scroll
  /// padding) so the last line of a long entry is never hidden behind this
  /// always-visible bar.
  static const double totalHeight = _barHeight + 20;

  _ActivePanel _activePanel = _ActivePanel.none;

  // Only selection changes (collapsed <-> expanded) need to rebuild
  // this widget to swap rows; every other controller change (typing,
  // formatting) is handled by the individual buttons re-reading style
  // state directly, so this listener is intentionally the only thing
  // that calls setState here for controller changes.
  bool _lastHadSelection = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant DiaryBottomToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final hasSelection = !widget.controller.selection.isCollapsed;
    if (hasSelection != _lastHadSelection) {
      if (hasSelection) {
        widget.editorFocusNode.unfocus();
      }
      setState(() => _lastHadSelection = hasSelection);
    }
  }

  /// Tells the host page to show [content], tracking [panel] as the
  /// active one for this toolbar's own button-highlight state.
  ///
  /// Unlike the previous `showModalBottomSheet`-based implementation,
  /// this does no unfocus ing itself — the host page's overlay handles
  /// capturing the keyboard height and unfocus ing, since it needs to
  /// do that *before* this is even called (the height has to be read
  /// while the keyboard is still up). See
  /// `_DiaryFormViewState._openPanel` in diary_form_page.dart.
  void _requestPanel(
    _ActivePanel panel,
    WidgetBuilder builder, {
    required bool refocusOnClose,
  }) {
    setState(() => _activePanel = panel);
    widget.onPanelRequested(
      DiaryPanelRequest(content: builder, refocusOnClose: refocusOnClose),
    );
  }

  /// Tells the host page to dismiss whatever panel is currently open,
  /// clearing this toolbar's own active-panel tracking to match.
  /// Safe to call even when nothing is open.
  void closeActivePanel() {
    if (_activePanel == _ActivePanel.none) return;
    setState(() => _activePanel = _ActivePanel.none);
    widget.onPanelRequested(null);
  }

  /// Kept as a distinct method so existing call sites that reference
  /// it by name don't need to change. Focus restoration on close is
  /// entirely up to the host page now (driven by the
  /// [DiaryPanelRequest.refocusOnClose] flag that was passed in when
  /// the panel was opened), so this is equivalent to
  /// [closeActivePanel] — kept only for call-site compatibility.
  void closeActivePanelAndRestoreFocus() => closeActivePanel();

  /// Refocus policy: **on**. The T panel includes Bold/Italic/
  /// Underline alongside alignment and font size — attributes people
  /// commonly keep toggling while they continue composing, so
  /// snapping the keyboard back open matches what they're likely to
  /// do next.
  void _openTextFormatPanel() {
    _requestPanel(
      _ActivePanel.textFormat,
      (panelContext) => _TextFormatPanel(
        controller: widget.controller,
        onAlignmentChanged: widget.onAlignmentChanged,
        onBoldChanged: widget.onBoldChanged,
        onItalicChanged: widget.onItalicChanged,
        onUnderlineChanged: widget.onUnderlineChanged,
        onFontSizeChanged: widget.onFontSizeChanged,
      ),
      refocusOnClose: true,
    );
  }

  /// Refocus policy: **off**. Picking a list style is a single
  /// preview/apply action (the panel closes itself right after, see
  /// `_ListPanel._toggleAndClose`) — there's no implied "now keep
  /// typing", so leave the keyboard closed.
  void _openListPanel() {
    _requestPanel(
      _ActivePanel.list,
      (panelContext) =>
          _ListPanel(controller: widget.controller, onDone: closeActivePanel),
      refocusOnClose: false,
    );
  }

  /// Refocus policy: **off**. Choosing a font is a preview action —
  /// the user wants to see how the entry looks, not resume typing
  /// immediately.
  void _openFontPanel() {
    _requestPanel(
      _ActivePanel.font,
      (panelContext) => FontPicker(
        selectedFontFamily: widget.selectedFontFamily,
        onFontSelected: widget.onFontSelected,
      ),
      refocusOnClose: false,
    );
  }

  /// Refocus policy: **off**. Same reasoning as the font panel —
  /// applying a document-wide text color is a preview/apply action.
  void _openTextColorPanel() {
    _requestPanel(
      _ActivePanel.textColor,
      (panelContext) => _DocumentColorPanel(
        controller: widget.controller,
        onTextColorChanged: widget.onTextColorChanged,
      ),
      refocusOnClose: false,
    );
  }

  /// Refocus policy: **on**. This panel only opens while there's an
  /// active text *selection* (it's part of [_SelectionToolsRow]),
  /// which only exists while the user is actively mid-edit — so
  /// unlike the document-wide Font/Text-color panels, returning here
  /// implies they're about to keep working in the editor, most likely
  /// with the same selection still in play.
  void _openSelectionColorPanel({required bool isHighlight}) {
    _requestPanel(
      _ActivePanel.selectionColor,
      (panelContext) => _FontColorPanel(
        controller: widget.controller,
        isHighlight: isHighlight,
      ),
      refocusOnClose: true,
    );
  }

  /// Refocus policy: **on**. Same reasoning as the selection color
  /// panel — only reachable while a selection is active.
  void _openStylePicker() {
    final style = widget.controller.getSelectionStyle();
    _requestPanel(
      _ActivePanel.selectionColor, // shares the row's single "active" slot
      (panelContext) =>
          _StylePickerSheet(controller: widget.controller, initialStyle: style),
      refocusOnClose: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = !widget.controller.selection.isCollapsed;

    // The bar itself still reads as a lifted, rounded card — that part
    // of the earlier redesign holds regardless of how its panels are
    // presented.
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(left: 10.0, top: 10.0, bottom: 10.0),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(ThemeRadii.xxl),
              bottomLeft: Radius.circular(ThemeRadii.xxl),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.onPrimary,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SizedBox(
                height: _barHeight,
        
                child: AnimatedSwitcher(
                  duration: ThemeDurations.fast,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: hasSelection
                      ? _SelectionToolsRow(
                          key: const ValueKey('selection'),
                          controller: widget.controller,
                          activePanel: _activePanel,
                          onOpenStylePicker: _openStylePicker,
                          onOpenColorPanel: _openSelectionColorPanel,
                        )
                      : _CommonToolsRow(
                          key: const ValueKey('common'),
                          controller: widget.controller,
                          activePanel: _activePanel,
                          onOpenTextFormatPanel: _openTextFormatPanel,
                          onOpenListPanel: _openListPanel,
                          onOpenFontPanel: _openFontPanel,
                          onOpenTextColorPanel: _openTextColorPanel,
                          onBackgroundPressed: widget.onBackgroundPressed,
                          onStickerPressed: widget.onStickerPressed,
                          onOverlayImagePressed: widget.onOverlayImagePressed,
                          onInlineImagePressed: widget.onInlineImagePressed,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    final color = theme.colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(ThemeRadii.sm),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: ThemeDurations.fast,
          curve: Curves.easeOut,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(ThemeRadii.sm),
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
      margin: const EdgeInsets.symmetric(horizontal: ThemeSpacing.xs),
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}

/// Section label used inside the panels (e.g. "Alignment", "Font
/// size") to visually group related controls.
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
  final VoidCallback onOpenTextFormatPanel;
  final VoidCallback onOpenListPanel;
  final VoidCallback onOpenFontPanel;
  final VoidCallback onOpenTextColorPanel;
  final VoidCallback onBackgroundPressed;
  final VoidCallback onStickerPressed;
  final VoidCallback onOverlayImagePressed;
  final VoidCallback onInlineImagePressed;

  const _CommonToolsRow({
    super.key,
    required this.controller,
    required this.activePanel,
    required this.onOpenTextFormatPanel,
    required this.onOpenListPanel,
    required this.onOpenFontPanel,
    required this.onOpenTextColorPanel,
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

  void _toggleQuote() {
    final isActive = _isBlockActive(quill.Attribute.blockQuote);
    widget.controller.formatSelection(
      isActive
          ? quill.Attribute.clone(quill.Attribute.blockQuote, null)
          : quill.Attribute.blockQuote,
    );
  }

  void _undo() {
    widget.controller.undo();
  }

  void _redo() {
    widget.controller.redo();
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
            onPressed: widget.controller.hasUndo ? _undo : null,
          ),
          _ToolbarIconButton(
            icon: Icons.redo_rounded,
            tooltip: 'Redo',
            onPressed: widget.controller.hasRedo ? _redo : null,
          ),
          const _ToolbarDivider(),
          _ToolbarIconButton(
            textLabel: 'T',
            tooltip: 'Text formatting',
            isActive:
                widget.activePanel == _ActivePanel.textFormat ||
                _isAnyTextFormatActive,
            onPressed: widget.onOpenTextFormatPanel,
          ),
          _ToolbarIconButton(
            textLabel: 'Aa',
            tooltip: 'Font',
            isActive: widget.activePanel == _ActivePanel.font,
            onPressed: widget.onOpenFontPanel,
          ),
          _ToolbarIconButton(
            icon: Icons.format_color_text_rounded,
            tooltip: 'Text color',
            isActive:
                widget.activePanel == _ActivePanel.textColor ||
                _hasDocumentTextColor,
            onPressed: widget.onOpenTextColorPanel,
          ),
          _ToolbarIconButton(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: 'Lists',
            isActive:
                widget.activePanel == _ActivePanel.list || _isAnyListActive,
            onPressed: widget.onOpenListPanel,
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
            icon: Icons.photo_size_select_large_sharp,
            tooltip: 'Floating photo',
            onPressed: widget.onOverlayImagePressed,
          ),
          _ToolbarIconButton(
            icon: Icons.auto_awesome_outlined,
            tooltip: 'Sticker',
            onPressed: widget.onStickerPressed,
          ),
          _ToolbarIconButton(
            icon: CupertinoIcons.layers,
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
// / Underline ONLY.
// ---------------------------------------------------------------------------

const List<({String label, String? value})> _fontSizeOptions = [
  (label: 'S', value: '12'),
  (label: 'M', value: null), // Normal / default
  (label: 'L', value: '20'),
  (label: 'XL', value: '28'),
];

class _TextFormatPanel extends StatefulWidget {
  final quill.QuillController controller;
  final ValueChanged<String> onAlignmentChanged;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<bool> onUnderlineChanged;
  final ValueChanged<String?> onFontSizeChanged;

  const _TextFormatPanel({
    required this.controller,
    required this.onAlignmentChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onUnderlineChanged,
    required this.onFontSizeChanged,
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

  void _toggle(quill.Attribute attribute) {
    final isActive = _isActive(attribute);
    final length = widget.controller.document.length;
    final nowActive = !isActive;
    if (length > 0) {
      widget.controller.formatText(
        0,
        length,
        isActive ? quill.Attribute.clone(attribute, null) : attribute,
      );
    }
    if (attribute.key == quill.Attribute.bold.key) {
      widget.onBoldChanged(nowActive);
    } else if (attribute.key == quill.Attribute.italic.key) {
      widget.onItalicChanged(nowActive);
    } else if (attribute.key == quill.Attribute.underline.key) {
      widget.onUnderlineChanged(nowActive);
    }
  }

  void _applyFontSizeToWholeDocument(String? value) {
    final length = widget.controller.document.length;
    if (length > 0) {
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
    widget.onFontSizeChanged(value);
  }

  @override
  Widget build(BuildContext context) {
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
                      icon:
                          _alignmentIcons[(alignment.value as String?) ??
                              'left'],
                      tooltip: (alignment.value as String?) ?? 'left',
                      isActive:
                          (alignment.value ?? 'left') == _currentAlignment,
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
// Text color panel - applies to the WHOLE document
// ---------------------------------------------------------------------------

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
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
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
    if (length > 0) {
      widget.controller.formatText(0, length, quill.ColorAttribute(hex));
    }
    widget.onTextColorChanged(hex);
  }

  void _clearFromWholeDocument() {
    final length = widget.controller.document.length;
    if (length > 0) {
      widget.controller.formatText(
        0,
        length,
        quill.Attribute.clone(quill.Attribute.color, null),
      );
    }
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
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 4,
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
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
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
// List panel (opened by the bullet button)
// ---------------------------------------------------------------------------

class _ListPanel extends StatefulWidget {
  final quill.QuillController controller;

  /// Called once a list style has been applied, so the host page
  /// knows to dismiss the panel — mirrors how this panel used to call
  /// `Navigator.of(context).pop()` on itself when it was a routed
  /// sheet. Since this panel is no longer hosted inside its own route,
  /// it has no `Navigator` of its own to pop; closing is entirely the
  /// host page's call now.
  final VoidCallback onDone;

  const _ListPanel({required this.controller, required this.onDone});

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

  /// Applies the style then tells the host page to dismiss the panel
  /// — unlike the T/Font/Text-color panels (which stay open across
  /// several taps), picking a list style is a single, complete action,
  /// so closing right away matches how Quote/Divider already behave.
  void _toggleAndClose(quill.Attribute attribute) {
    final isActive = _isActive(attribute);
    widget.controller.formatSelection(
      isActive ? quill.Attribute.clone(attribute, null) : attribute,
    );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThemeSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ListOptionRow(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Bullet list',
            isActive: _isActive(quill.Attribute.ul),
            onTap: () => _toggleAndClose(quill.Attribute.ul),
          ),
          _ListOptionRow(
            icon: Icons.format_list_numbered_rounded,
            label: 'Numbered list',
            isActive: _isActive(quill.Attribute.ol),
            onTap: () => _toggleAndClose(quill.Attribute.ol),
          ),
          _ListOptionRow(
            icon: Icons.checklist_rounded,
            label: 'Checklist',
            isActive:
                _isActive(quill.Attribute.unchecked) ||
                _isActive(quill.Attribute.checked),
            onTap: () => _toggleAndClose(quill.Attribute.unchecked),
          ),
        ],
      ),
    );
  }
}

/// A single selectable row inside [_ListPanel] — a rounded, softly
/// highlighted card when active rather than a flat, full-bleed
/// [ListTile], matching the pill-shaped active state every other
/// button in this toolbar uses.
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

// ---------------------------------------------------------------------------
// Selection tools row (text selected)
// ---------------------------------------------------------------------------

class _SelectionToolsRow extends StatefulWidget {
  final quill.QuillController controller;
  final _ActivePanel activePanel;
  final VoidCallback onOpenStylePicker;
  final void Function({required bool isHighlight}) onOpenColorPanel;

  const _SelectionToolsRow({
    super.key,
    required this.controller,
    required this.activePanel,
    required this.onOpenStylePicker,
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
            onPressed: widget.onOpenStylePicker,
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

// ---------------------------------------------------------------------------
// Divider embed
// ---------------------------------------------------------------------------

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