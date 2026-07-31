// lib/features/backgrounds/presentation/widgets/background_picker_widget.dart

import 'dart:io';

import 'package:bubimo/core/error/exceptions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
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
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
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
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Downloaded', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (!state.remoteFetchAttempted)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (state.remoteFetchFailed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      "Couldn't load more backgrounds — check your "
                      'connection.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.read<BackgroundPickerBloc>().add(
                        const LoadBackgrounds(),
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (state.remotePresets.isEmpty)
              Text(
                'No additional packs available right now.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              _BackgroundGrid(
                paths: state.remotePresets,
                onTap: (path) => widget.onSelected(
                  SelectedBackground(
                    type: BackgroundSourceType.presetRemote,
                    path: path,
                  ),
                ),
              ),
          ],
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
    if (paths.isEmpty) {
      return Text(
        'None available.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final path = paths[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onTap(path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // `path` is the Supabase public URL for this preset, not a
            // local file path — CachedNetworkImage resolves the
            // network-vs-disk-cache decision itself and shows
            // `placeholder` while that resolves, same pattern as the
            // sticker grid's thumbnails.
            child: CachedNetworkImage(
              imageUrl: path,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => const Center(
                child: CupertinoActivityIndicator(),
              ),
              errorWidget: (_, _, _) => const Icon(
                Icons.broken_image,
                color: Colors.grey,
              ),
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