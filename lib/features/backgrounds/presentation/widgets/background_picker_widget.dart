// lib/features/backgrounds/presentation/widgets/background_picker_widget.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:bubimo/core/error/exceptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/media_storage_service.dart';
import '../../../../core/widgets/needs_internet_inline.dart';
import '../bloc/background_picker/background_picker_bloc.dart';
import '../bloc/background_picker/background_picker_event.dart';
import '../bloc/background_picker/background_picker_state.dart';

/// One shared loading visual for every "still working on it" moment
/// in this picker (connectivity check, remote fetch) — a single
/// common loading state instead of several different-looking ones.
const Widget _loadingIndicator = Center(
  child: SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  ),
);

/// Where a selected background came from — determines which of
/// `DiaryEntry`'s two background fields the caller should set.
enum BackgroundSourceType {
  /// A Supabase-fetched preset, already downloaded and cached locally
  /// by the time this is returned. Caller should set `bgLocalPath`.
  presetRemote,

  /// Picked from the device gallery. Caller should set
  /// `bgGalleryImagePath`.
  gallery,
}

class SelectedBackground {
  final BackgroundSourceType type;
  final String path;

  const SelectedBackground({required this.type, required this.path});
}

/// Lets the user choose a background: Supabase-fetched presets (if
/// online), or their own gallery photo. Returns the selection via
/// [onSelected] — this widget doesn't touch the diary entry itself,
/// the caller (diary_form_page) applies it based on
/// [SelectedBackground.type].
class BackgroundPickerWidget extends StatefulWidget {
  final ValueChanged<SelectedBackground> onSelected;

  const BackgroundPickerWidget({super.key, required this.onSelected});

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
                  _PresetsTab(onSelected: widget.onSelected),
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

  const _PresetsTab({required this.onSelected});

  @override
  State<_PresetsTab> createState() => _PresetsTabState();
}

class _PresetsTabState extends State<_PresetsTab>
    with AutomaticKeepAliveClientMixin {
  final NetworkInfo _networkInfo = getIt<NetworkInfo>();

  /// Null while the first connectivity check is still running; true/
  /// false once known. Checked once per tab visit, alongside (not
  /// instead of) the bloc's own `LoadBackgrounds` dispatch — this
  /// only decides which UI to show; `BackgroundPickerBloc` still owns
  /// the actual fetch and its own `remoteFetchFailed` state covers a
  /// fetch that starts fine but fails mid-flight.
  bool? _hasInternet;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _check(initial: true);
  }

  Future<void> _check({bool initial = false}) async {
    setState(() => _isRetrying = !initial);

    final hasInternet = await _networkInfo.isConnected;
    if (!mounted) return;

    setState(() {
      _hasInternet = hasInternet;
      _isRetrying = false;
    });

    if (hasInternet && !initial) {
      // Retried from offline back to online — (re)kick the fetch, since
      // the very first load already happened via LoadBackgrounds in
      // BackgroundPickerWidget.build regardless of connectivity.
      context.read<BackgroundPickerBloc>().add(const LoadBackgrounds());
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    if (_hasInternet == null) {
      return _loadingIndicator;
    }

    if (!_hasInternet!) {
      return NeedsInternetInline(
        action: 'load background presets',
        isRetrying: _isRetrying,
        onRetry: () => _check(),
      );
    }

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

        if (state.remotePresets.isEmpty) {
          return Center(
            child: Text(
              'No backgrounds available right now.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }

        return _BackgroundGrid(
          paths: state.remotePresets,
          onTap: (path) => widget.onSelected(
            SelectedBackground(
              type: BackgroundSourceType.presetRemote,
              path: path,
            ),
          ),
        );
      },
    );
  }
}

class _BackgroundGrid extends StatelessWidget {
  final List<String> paths;
  final ValueChanged<String> onTap;

  const _BackgroundGrid({required this.paths, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final path = paths[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onTap(path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // `path` is a durable LOCAL file path, not a URL — the
            // bloc downloads and caches every Supabase preset up
            // front (see BackgroundPickerState.remotePresets' doc
            // comment), so by the time the grid renders it's already
            // on disk. Image.file, not a network image loader.
            child: Image.file(
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
            ),
          ),
        );
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
Future<SelectedBackground?> showBackgroundPickerSheet(BuildContext context) {
  return showModalBottomSheet<SelectedBackground>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return BackgroundPickerWidget(
        onSelected: (selection) => Navigator.of(sheetContext).pop(selection),
      );
    },
  );
}