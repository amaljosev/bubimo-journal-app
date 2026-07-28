// lib/features/diary_entry/presentation/widgets/diary_bottom_toolbar.dart

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_tokens.dart';
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
/// in this single widget — and enforced DETERMINISTICALLY, not by
/// reacting to focus/keyboard-visibility after the fact:
/// - Opening any panel (T, Bullet, Font, Text color, or the selection
///   row's color panel) unfocuses the editor immediately, closing the
///   keyboard, and every formatting action taken inside an open panel
///   re-asserts that unfocus in the same frame afterward (some
///   `flutter_quill` formatting calls can otherwise silently reclaim
///   focus, which used to pop the keyboard back up over a still-open
///   panel — see `_reassertUnfocus`).
/// - The Quill selection becoming non-collapsed (the user selected
///   text, about to show the native text-selection toolbar) also
///   unfocuses the editor first, so the on-screen keyboard never
///   overlaps that native toolbar.
/// - Closing a panel is NEVER triggered by a focus-change listener
///   guessing whether the keyboard "really" came back — that approach
///   was fragile and caused exactly the flicker/both-visible bugs this
///   version fixes. Panels only close for one of two explicit,
///   synchronous reasons: the same toolbar button is tapped again
///   ([closeActivePanel], used internally by Quote/Divider/etc.), or
///   the person taps away from the toolbar entirely
///   ([closeActivePanelAndRestoreFocus], wired up by the parent form
///   page over the editor area, the title field, and the rest of the
///   screen), which both closes the panel AND explicitly requests
///   focus back so the keyboard reappears in the same motion.
///
/// No panel is ever a modal `showModalBottomSheet` — a modal sheet
/// would cover the editor, so the person couldn't see what they're
/// formatting while picking it. Instead every panel (including the
/// font picker and the text-color panels) expands *above* this
/// toolbar, like a tab bar's content area, sized to the keyboard's own
/// height so it visually "replaces" the keyboard rather than adding
/// extra space on top of it.
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

  /// Called whenever the inline panel height changes (0 when closed).
  /// The parent can use this to adjust bottom padding of the scroll view.
  final ValueChanged<double>? onPanelHeightChanged;

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
    this.onPanelHeightChanged,
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
      setState(() => _lastHadSelection = hasSelection);
    }
  }

  void _notifyPanelHeightChanged() {
    final height = _activePanel == _ActivePanel.none ? 0.0 : _panelHeight;
    widget.onPanelHeightChanged?.call(height);
  }

  /// Opens [panel], or closes it if it's already the one open
  /// (toggle). Always closes the keyboard first when opening, since
  /// keyboard and panel never show at the same time.
  ///
  /// Unlike the previous implementation, closing is now NEVER driven
  /// by reacting to focus/keyboard state after the fact (that
  /// reactive, heuristic-based approach — guessing whether a focus
  /// event was a genuine keyboard-driven one vs. Quill's internal
  /// bookkeeping by checking `viewInsets.bottom` a frame later — is
  /// exactly what caused the keyboard to flicker open/closed and,
  /// worse, occasionally left both the panel and keyboard visible at
  /// once). Every panel open/close now happens for one explicit,
  /// synchronous reason: a toolbar button was tapped, or the person
  /// tapped away from the toolbar (see [closeActivePanel] /
  /// [closeActivePanelAndRestoreFocus]). There is no listener that can
  /// second-guess that and reopen/reclose things on its own.
  void _openPanel(_ActivePanel panel) {
    final opening = _activePanel != panel;
    if (opening) {
      // Capture the keyboard's current height BEFORE dismissing it, so
      // the panel that's about to open can reuse exactly that height.
      final currentInset = MediaQuery.of(context).viewInsets.bottom;
      if (currentInset > 100) {
        _lastKnownKeyboardHeight = currentInset;
      }
      widget.editorFocusNode.unfocus();
      // Some `flutter_quill` formatting methods may refocus the editor
      // in a post-frame callback, so we schedule another unfocus to
      // catch it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activePanel != _ActivePanel.none) {
          widget.editorFocusNode.unfocus();
        }
      });
    }
    setState(() {
      _activePanel = opening ? panel : _ActivePanel.none;
    });
    _notifyPanelHeightChanged();
  }

  /// Closes whatever panel is currently open, if any — used before
  /// performing an action that doesn't itself open a panel (Quote,
  /// Divider), and by [closeActivePanelAndRestoreFocus] below. Does
  /// NOT touch focus — callers that also want the keyboard to
  /// reappear should use [closeActivePanelAndRestoreFocus] instead.
  void closeActivePanel() {
    if (_activePanel != _ActivePanel.none) {
      setState(() => _activePanel = _ActivePanel.none);
      _notifyPanelHeightChanged();
    }
  }

  /// Closes whatever panel is open AND brings the keyboard back by
  /// refocusing the description editor — this is what "tap outside the
  /// sheet" wires up to (via the parent form page's `GestureDetector`s
  /// over the editor area and any other non-toolbar part of the
  /// screen), so tapping away from an open panel both dismisses it and
  /// restores the keyboard in one motion, exactly like tapping outside
  /// a modal bottom sheet would, instead of leaving the person looking
  /// at neither.
  void closeActivePanelAndRestoreFocus() {
    final wasOpen = _activePanel != _ActivePanel.none;
    if (!wasOpen) return;
    setState(() => _activePanel = _ActivePanel.none);
    _notifyPanelHeightChanged();
    // Deferred one frame so the panel has actually collapsed out of
    // the layout before the keyboard starts animating in — requesting
    // focus in the very same frame the panel closes can make the two
    // animations visually fight each other.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.editorFocusNode.requestFocus();
    });
  }

  /// Called by every formatting action inside the open panels (T panel
  /// bold/italic/underline/alignment/font-size, the text-color panels)
  /// immediately after applying a Quill format. `QuillController.
  /// formatText`/`formatSelection` can, in some flutter_quill versions,
  /// silently reclaim focus on the editor's own `FocusNode` as a side
  /// effect of applying a format — even though the person never tapped
  /// back into the text and the panel is still meant to be open. Left
  /// unchecked, that stray refocus is exactly what made "changing
  /// alignment" (or any other panel action) pop the keyboard back up
  /// over the still-open panel. Re-asserting `unfocus()` synchronously
  /// as well as on the next frame closes that gap before it can ever
  /// paint.
  void _reassertUnfocus() {
    if (widget.editorFocusNode.hasFocus) {
      widget.editorFocusNode.unfocus();
    }
    // Also schedule a post-frame unfocus to catch any delayed focus
    // that might be scheduled by Quill's internal handlers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _activePanel != _ActivePanel.none) {
        if (widget.editorFocusNode.hasFocus) {
          widget.editorFocusNode.unfocus();
        }
      }
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
    // Schedule a post-frame unfocus to catch stray refocus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _activePanel != _ActivePanel.none) {
        widget.editorFocusNode.unfocus();
      }
    });
    setState(() {
      _selectionColorIsHighlight = isHighlight;
      _activePanel = _ActivePanel.selectionColor;
    });
    _notifyPanelHeightChanged();
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

    // The whole toolbar — panel + button row — reads as one continuous
    // elevated card floating above the editor: rounded at the top and
    // lifted with a soft shadow, rather than a flat bar pinned on with
    // a hard 1px border. This also means the panel and the row beneath
    // it never look like two separately-bolted-on pieces, whatever
    // combination is currently showing.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(ThemeRadii.xxl),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Inline panel area — sits ABOVE the toolbar row, like a tab
            // bar's content pane, rather than as a modal overlay on top of
            // the editor. AnimatedSize smooths the height change as panels
            // open/close/swap instead of an abrupt jump.
            AnimatedSize(
              duration: ThemeDurations.standard,
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: _activePanel == _ActivePanel.none
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Container(
                      height: _panelHeight,
                      color: theme.colorScheme.surfaceContainerLow,
                      child: Column(
                        children: [
                          const _PanelGrabber(),
                          Expanded(child: _buildActivePanel(context)),
                        ],
                      ),
                    ),
            ),
            Container(
              height: _barHeight,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
               
              ),
            
              child: 
              
              AnimatedSwitcher(
                duration: ThemeDurations.fast,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
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
                        onAfterFormat: _reassertUnfocus,
                        onBackgroundPressed: widget.onBackgroundPressed,
                        onStickerPressed: widget.onStickerPressed,
                        onOverlayImagePressed: widget.onOverlayImagePressed,
                        onInlineImagePressed: widget.onInlineImagePressed,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  

  Widget _buildActivePanel(BuildContext context) {
    switch (_activePanel) {
      case _ActivePanel.textFormat:
        return _TextFormatPanel(
          controller: widget.controller,
          onAlignmentChanged: widget.onAlignmentChanged,
          onBoldChanged: widget.onBoldChanged,
          onItalicChanged: widget.onItalicChanged,
          onUnderlineChanged: widget.onUnderlineChanged,
          onFontSizeChanged: widget.onFontSizeChanged,
          onAfterFormat: _reassertUnfocus,
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
          onAfterFormat: _reassertUnfocus,
        );
      case _ActivePanel.textColor:
        return _DocumentColorPanel(
          controller: widget.controller,
          onTextColorChanged: widget.onTextColorChanged,
          onAfterFormat: _reassertUnfocus,
        );
      case _ActivePanel.selectionColor:
        return _FontColorPanel(
          controller: widget.controller,
          isHighlight: _selectionColorIsHighlight,
          onDone: () => _openPanel(_ActivePanel.selectionColor),
          onAfterFormat: _reassertUnfocus,
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
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}

/// Small centered grabber shown at the top of whichever panel is open,
/// matching the drag-handle affordance every other bottom sheet in the
/// app already uses (e.g. `DiaryFormOverlaySettingsSheet`) — a quiet
/// visual cue that this is a dismissible sheet-like surface, not a
/// fixed part of the toolbar.
class _PanelGrabber extends StatelessWidget {
  const _PanelGrabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ThemeSpacing.sm, bottom: ThemeSpacing.xs),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
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
  final ValueChanged<_ActivePanel> onOpenPanel;
  final VoidCallback onClosePanel;
  final VoidCallback onAfterFormat;
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
    required this.onAfterFormat,
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
    widget.onClosePanel();
    final isActive = _isBlockActive(quill.Attribute.blockQuote);
    widget.controller.formatSelection(
      isActive
          ? quill.Attribute.clone(quill.Attribute.blockQuote, null)
          : quill.Attribute.blockQuote,
    );
  }

  void _undo() {
    widget.controller.undo();
    widget.onAfterFormat();
  }

  void _redo() {
    widget.controller.redo();
    widget.onAfterFormat();
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
            isActive: widget.activePanel == _ActivePanel.textFormat ||
                _isAnyTextFormatActive,
            onPressed: () => widget.onOpenPanel(_ActivePanel.textFormat),
          ),
          _ToolbarIconButton(
            textLabel: 'Aa',
            tooltip: 'Font',
            isActive: widget.activePanel == _ActivePanel.font,
            onPressed: () => widget.onOpenPanel(_ActivePanel.font),
          ),
          _ToolbarIconButton(
            icon: Icons.format_color_text_rounded,
            tooltip: 'Text color',
            isActive: widget.activePanel == _ActivePanel.textColor ||
                _hasDocumentTextColor,
            onPressed: () => widget.onOpenPanel(_ActivePanel.textColor),
          ),
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
  final VoidCallback onAfterFormat;

  const _TextFormatPanel({
    required this.controller,
    required this.onAlignmentChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onUnderlineChanged,
    required this.onFontSizeChanged,
    required this.onAfterFormat,
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
    widget.onAfterFormat();
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
    widget.onAfterFormat();
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
    widget.onAfterFormat();
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
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
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
  final VoidCallback onAfterFormat;

  const _DocumentColorPanel({
    required this.controller,
    required this.onTextColorChanged,
    required this.onAfterFormat,
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
    widget.onAfterFormat();
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
    widget.onAfterFormat();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final swatches = AppColors.forRole(_selectedRole, isDark: isDark);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Text color', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _ColorRoleSelector(
              selectedRole: _selectedRole,
              onRoleChanged: (role) => setState(() => _selectedRole = role),
            ),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ThemeSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ListOptionRow(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Bullet list',
              isActive: _isActive(quill.Attribute.ul),
              onTap: () => _toggle(quill.Attribute.ul),
            ),
            _ListOptionRow(
              icon: Icons.format_list_numbered_rounded,
              label: 'Numbered list',
              isActive: _isActive(quill.Attribute.ol),
              onTap: () => _toggle(quill.Attribute.ol),
            ),
            _ListOptionRow(
              icon: Icons.checklist_rounded,
              label: 'Checklist',
              isActive: _isActive(quill.Attribute.unchecked) ||
                  _isActive(quill.Attribute.checked),
              onTap: () => _toggle(quill.Attribute.unchecked),
            ),
          ],
        ),
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
    final color =
        isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface;

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
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
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

class _FontColorPanel extends StatefulWidget {
  final quill.QuillController controller;
  final bool isHighlight;
  final VoidCallback onDone;
  final VoidCallback onAfterFormat;

  const _FontColorPanel({
    required this.controller,
    this.isHighlight = false,
    required this.onDone,
    required this.onAfterFormat,
  });

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
    widget.onAfterFormat();
  }

  void _clear() {
    final attribute =
        widget.isHighlight ? quill.Attribute.background : quill.Attribute.color;
    widget.controller.formatSelection(quill.Attribute.clone(attribute, null));
    widget.onAfterFormat();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final swatches = AppColors.forRole(_selectedRole, isDark: isDark);

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
                  widget.isHighlight ? 'Highlight color' : 'Text color',
                  style: theme.textTheme.titleMedium,
                ),
                TextButton(onPressed: widget.onDone, child: const Text('Done')),
              ],
            ),
            const SizedBox(height: 10),
            _ColorRoleSelector(
              selectedRole: _selectedRole,
              onRoleChanged: (role) => setState(() => _selectedRole = role),
            ),
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