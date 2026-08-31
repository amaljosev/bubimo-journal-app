// lib/features/backgrounds/presentation/widgets/background_picker_widget.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:bubimo/core/error/exceptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/storage/media_storage_service.dart';
import '../bloc/background_picker/background_picker_bloc.dart';
import '../bloc/background_picker/background_picker_event.dart';
import '../bloc/background_picker/background_picker_state.dart';

/// One shared loading visual for the picker's single full-tab loading
/// moment (no persisted seed yet, first fetch still in flight) — kept
/// as one constant so there's a single common loading look rather than
/// several different-looking ones.
const Widget _loadingIndicator = Center(
  child: SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  ),
);

/// How close to the bottom (in logical pixels) the grid needs to be
/// scrolled before the next page of Supabase presets is requested.
const double _loadMoreThreshold = 300;

/// Where a selected background came from — determines which of
/// `DiaryEntry`'s two background fields the caller should set.
enum BackgroundSourceType {
  /// A Supabase-fetched preset, already downloaded and cached locally
  /// by the time this is returned. Caller should set `bgLocalPath`.
  presetRemote,

  /// Picked from the device gallery. Caller should set
  /// `bgGalleryImagePath`.
  gallery,

  /// The user explicitly cleared the background — `path` is null.
  /// Caller should unset both `bgLocalPath` and
  /// `bgGalleryImagePath`.
  none,
}

class SelectedBackground {
  final BackgroundSourceType type;

  /// Null when [type] is [BackgroundSourceType.none]; always
  /// non-null for the other two types.
  final String? path;

  const SelectedBackground({required this.type, this.path});
}

/// Lets the user choose a background: Supabase-fetched presets (if
/// online, or from the offline seed if not), their own gallery photo,
/// or clearing the background entirely. Returns the selection via
/// [onSelected] — this widget doesn't touch the diary entry itself,
/// the caller (diary_form_page) applies it based on
/// [SelectedBackground.type].
class BackgroundPickerWidget extends StatefulWidget {
  final ValueChanged<SelectedBackground> onSelected;

  /// The diary entry's currently-active preset path, if its
  /// background currently comes from a preset — so the matching tile
  /// (or the Clear tile, if this is null) opens already marked as
  /// selected instead of always defaulting to Clear regardless of
  /// what's actually set.
  final String? currentPresetPath;

  const BackgroundPickerWidget({
    super.key,
    required this.onSelected,
    this.currentPresetPath,
  });

  @override
  State<BackgroundPickerWidget> createState() =>
      _BackgroundPickerWidgetState();
}

class _BackgroundPickerWidgetState extends State<BackgroundPickerWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();
  final MediaStorageService _mediaStorageService = getIt<MediaStorageService>();

  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final savedPath = await _mediaStorageService.saveFile(
        File(picked.path),
        category: MediaCategory.diaryBackgrounds,
      );
      widget.onSelected(
        SelectedBackground(
          type: BackgroundSourceType.gallery,
          path: savedPath,
        ),
      );
    } on MediaStorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save image: ${e.message}')),
        );
      }
    } finally {
      _isPicking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<BackgroundPickerBloc>()..add(const LoadBackgrounds()),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Presets'),
                Tab(text: 'Gallery'),
              ],
            ),
            Expanded(
              // AutomaticKeepAliveClientMixin on each tab (below) needs
              // TabBarView to not tear the tab down when it scrolls
              // offscreen — that disposal is what forces a rebuild (and
              // re-decode of every already-local image) on every switch
              // back to a previously-viewed tab.
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PresetsTab(
                    onSelected: widget.onSelected,
                    currentPresetPath: widget.currentPresetPath,
                  ),
                  _GalleryTab(onPickPressed: _pickFromGallery),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetsTab extends StatefulWidget {
  final ValueChanged<SelectedBackground> onSelected;
  final String? currentPresetPath;

  const _PresetsTab({required this.onSelected, this.currentPresetPath});

  @override
  State<_PresetsTab> createState() => _PresetsTabState();
}

class _PresetsTabState extends State<_PresetsTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  /// Null means the "Clear" tile is the current selection. Non-null is
  /// the selected preset's local cached path. Initialized from
  /// [_PresetsTab.currentPresetPath] (not always null) so reopening
  /// the picker highlights whatever's actually set right now, rather
  /// than always defaulting back to Clear regardless of position.
  String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _selectedPath = widget.currentPresetPath;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) {
      return;
    }

    // Belt-and-suspenders: check the bloc's latest state here too
    // (not just inside the bloc's own handler) so a burst of scroll
    // callbacks near the threshold doesn't queue up redundant events.
    final bloc = context.read<BackgroundPickerBloc>();
    if (bloc.state.isLoadingMoreRemote || !bloc.state.hasMoreRemote) return;
    bloc.add(const LoadMoreBackgrounds());
  }

  void _handleSelect(String? path) {
    setState(() => _selectedPath = path);
    widget.onSelected(
      path == null
          ? const SelectedBackground(type: BackgroundSourceType.none)
          : SelectedBackground(
              type: BackgroundSourceType.presetRemote,
              path: path,
            ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return BlocBuilder<BackgroundPickerBloc, BackgroundPickerState>(
      builder: (context, state) {
        if (!state.remoteFetchAttempted) {
          return _loadingIndicator;
        }

        if (state.remoteFetchFailed) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Couldn't load backgrounds — check your connection.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context
                        .read<BackgroundPickerBloc>()
                        .add(const LoadBackgrounds()),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        // Always shown once we get here — the Clear tile makes sure
        // there's a meaningful first item even when there happen to
        // be zero downloaded presets, and this now covers both "fully
        // online" and "offline, showing the persisted seed" alike.
        return _BackgroundGrid(
          paths: state.remotePresets,
          selectedPath: _selectedPath,
          onSelect: _handleSelect,
          scrollController: _scrollController,
          isLoadingMore: state.isLoadingMoreRemote,
        );
      },
    );
  }
}

class _BackgroundGrid extends StatelessWidget {
  final List<String> paths;
  final String? selectedPath;
  final ValueChanged<String?> onSelect;
  final ScrollController scrollController;
  final bool isLoadingMore;

  const _BackgroundGrid({
    required this.paths,
    required this.selectedPath,
    required this.onSelect,
    required this.scrollController,
    required this.isLoadingMore,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return _SelectableTile(
                    isSelected: selectedPath == null,
                    onTap: () => onSelect(null),
                    child: const _ClearTile(),
                  ); 
                }
                final path = paths[index - 1];
                return _SelectableTile(
                  isSelected: selectedPath == path,
                  onTap: () => onSelect(path),
                  child: _PresetTile(path: path),
                );
              },
              childCount: paths.length + 1,
            ),
          ),
        ),
        if (isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: _loadingIndicator,
            ),
          ),
      ],
    );
  }
}

/// Wraps a tile with the shared "this is the current selection" look
/// — a colored ring plus a small checkmark badge — so the Clear tile
/// and every image tile show it identically, and it always tracks
/// whichever tile is actually selected rather than a fixed position.
class _SelectableTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectableTile({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (isSelected) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.primary, width: 3),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: colorScheme.primary,
                    child: Icon(
                      Icons.check,
                      size: 12,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The always-first grid item: explicitly clears the background
/// rather than picking an image.
class _ClearTile extends StatelessWidget {
  const _ClearTile();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.not_interested_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            'None',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String path;

  const _PresetTile({required this.path});

  @override
  Widget build(BuildContext context) {
    // `path` is a durable LOCAL file path, not a URL — the bloc only
    // ever adds an entry to `remoteByUrl` once that URL is actually
    // downloaded and cached (whether from the persisted offline seed
    // or a later page), so by the time the grid renders it's already
    // on disk. Image.file, not a network image loader.
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        developer.log(
          'Failed to render cached background preset: $path',
          name: 'BackgroundPickerWidget',
          error: error,
          stackTrace: stackTrace,
        );
        return const Icon(Icons.broken_image, color: Colors.grey);
      },
    );
  }
}

class _GalleryTab extends StatefulWidget {
  final VoidCallback onPickPressed;

  const _GalleryTab({required this.onPickPressed});

  @override
  State<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<_GalleryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return Center(
      child: FilledButton.icon(
        onPressed: widget.onPickPressed,
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Choose from gallery'),
      ),
    );
  }
}

/// Shows [BackgroundPickerWidget] in a modal bottom sheet. Returns the
/// selection, or null if dismissed without choosing.
///
/// Pass [currentPresetPath] (the diary entry's current `bgLocalPath`,
/// if it has one) so the picker opens with the right tile already
/// marked as selected instead of always defaulting to Clear.
Future<SelectedBackground?> showBackgroundPickerSheet(
  BuildContext context, {
  String? currentPresetPath,
}) {
  return showModalBottomSheet<SelectedBackground>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return BackgroundPickerWidget(
        currentPresetPath: currentPresetPath,
        onSelected: (selection) => Navigator.of(sheetContext).pop(selection),
      );
    },
  );
}