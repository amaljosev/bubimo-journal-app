// lib/features/backgrounds/presentation/widgets/background_picker_widget.dart

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/media_storage_service.dart';
import '../bloc/background_picker/background_picker_bloc.dart';
import '../bloc/background_picker/background_picker_event.dart';
import '../bloc/background_picker/background_picker_state.dart';

/// Where a selected background came from — determines which of
/// `DiaryEntry`'s two background fields the caller should set.
enum BackgroundSourceType {
  /// A Supabase preset, already downloaded to a local file by the time
  /// this is returned. Caller should set `bgLocalPath`.
  presetRemote,

  /// Picked from the device gallery. Caller should set
  /// `bgGalleryImagePath`.
  gallery,

  /// The user explicitly cleared the background — `path` is null.
  /// Caller should unset both `bgLocalPath` and `bgGalleryImagePath`.
  none,
}

class SelectedBackground {
  final BackgroundSourceType type;

  /// Null when [type] is [BackgroundSourceType.none]; always non-null
  /// for the other two types.
  final String? path;

  const SelectedBackground({required this.type, this.path});
}

/// Lets the user choose a background: a Supabase preset, a gallery
/// photo, or none. Returns the choice via [onSelected]; the caller
/// (diary_form_page) applies it to the entry.
class BackgroundPickerWidget extends StatefulWidget {
  final ValueChanged<SelectedBackground> onSelected;

  /// The entry's current preset file path, if its background is a
  /// preset, so the matching tile (or "None") opens highlighted.
  final String? currentPresetPath;

  const BackgroundPickerWidget({
    super.key,
    required this.onSelected,
    this.currentPresetPath,
  });

  @override
  State<BackgroundPickerWidget> createState() => _BackgroundPickerWidgetState();
}

class _BackgroundPickerWidgetState extends State<BackgroundPickerWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();
  final MediaStorageService _mediaStorageService = getIt<MediaStorageService>();

  bool _isPicking = false;
  bool _isCropping = false;

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

  /// `image_cropper` only ships Android, iOS and Web implementations, and
  /// this widget's file handling (`dart:io`) is not web-ready, so cropping
  /// runs on Android/iOS only. Everywhere else the original flow is kept.
  bool get _isCropSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Opens the native cropper locked to the current screen's aspect ratio
  /// (width : height of the window, so it adapts to every device and to
  /// rotation / split-screen). Returns the cropped file's path, or null if
  /// the user cancelled.
  Future<String?> _cropToScreenRatio(String sourcePath) async {
    // Read everything that needs `context` before the first await.
    final screen = MediaQuery.sizeOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      // Passing an aspectRatio locks the crop box to it.
      aspectRatio: CropAspectRatio(
        ratioX: screen.width,
        ratioY: screen.height,
      ),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop background',
          toolbarColor: colorScheme.primary,
          toolbarWidgetColor: colorScheme.onPrimary,
          activeControlsWidgetColor: colorScheme.primary,
          lockAspectRatio: true,
          // Hides the bottom controls (ratio menu, rotate, scale wheel).
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Crop background',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    return cropped?.path;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Crops [sourcePath], stores the result durably and reports it as a
  /// user-owned image. Does nothing if the user cancels the crop, so the
  /// picker sheet simply stays open.
  Future<void> _cropSaveAndSelect(String sourcePath) async {
    final croppedPath = await _cropToScreenRatio(sourcePath);
    if (croppedPath == null) return;

    final savedPath = await _mediaStorageService.saveFile(
      File(croppedPath),
      category: MediaCategory.diaryBackgrounds,
    );
    if (!mounted) return;
    widget.onSelected(
      SelectedBackground(type: BackgroundSourceType.gallery, path: savedPath),
    );
  }

  Future<void> _pickFromGallery() async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      if (_isCropSupported) {
        await _cropSaveAndSelect(picked.path);
        return;
      }

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
      _showSnack('Could not save image: ${e.message}');
    } catch (_) {
      _showSnack('Could not crop image. Please try again.');
    } finally {
      _isPicking = false;
    }
  }

  /// A preset finished downloading. The downloaded file is shared and
  /// reused, so it is never modified: the crop is written to a new file.
  Future<void> _onPresetDownloaded(String localPath) async {
    if (!_isCropSupported) {
      widget.onSelected(
        SelectedBackground(
          type: BackgroundSourceType.presetRemote,
          path: localPath,
        ),
      );
      return;
    }

    if (_isCropping) return;
    _isCropping = true;
    try {
      await _cropSaveAndSelect(localPath);
    } on MediaStorageException catch (e) {
      _showSnack('Could not save image: ${e.message}');
    } catch (_) {
      _showSnack('Could not crop image. Please try again.');
    } finally {
      _isCropping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<BackgroundPickerBloc>()..add(const BackgroundPickerStarted()),
      // Hands the downloaded preset to the caller, or reports a failed
      // download. Lives above the tabs so it works regardless of which
      // tab is visible.
      child: BlocListener<BackgroundPickerBloc, BackgroundPickerState>(
        listenWhen: (prev, curr) =>
            (curr.downloaded != null && prev.downloaded != curr.downloaded) ||
            (curr.downloadFailed && !prev.downloadFailed),
        listener: (context, state) {
          final downloaded = state.downloaded;
          if (downloaded != null) {
            unawaited(_onPresetDownloaded(downloaded.localPath));
          } else if (state.downloadFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Couldn't download this background. Try again."),
              ),
            );
          }
        },
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
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PresetsTab(
                      currentPresetPath: widget.currentPresetPath,
                      onClear: () => widget.onSelected(
                        const SelectedBackground(
                          type: BackgroundSourceType.none,
                        ),
                      ),
                    ),
                    _GalleryTab(onPickPressed: _pickFromGallery),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Presets tab
// ---------------------------------------------------------------------------

class _PresetsTab extends StatefulWidget {
  final String? currentPresetPath;
  final VoidCallback onClear;

  const _PresetsTab({this.currentPresetPath, required this.onClear});

  @override
  State<_PresetsTab> createState() => _PresetsTabState();
}

class _PresetsTabState extends State<_PresetsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// File name of the entry's current preset (e.g. `3.webp`), used to
  /// mark the matching tile. Null means "None" is the current choice.
  late final String? _currentFileName = _fileNameOf(widget.currentPresetPath);

  static String? _fileNameOf(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    return pathOrUrl.split(RegExp(r'[\\/]')).last;
  }

  void _select(String? url) {
    if (url == null) {
      widget.onClear();
      return;
    }
    context.read<BackgroundPickerBloc>().add(BackgroundPresetSelected(url));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return BlocBuilder<BackgroundPickerBloc, BackgroundPickerState>(
      builder: (context, state) {
        switch (state.status) {
          case BackgroundPickerStatus.loading:
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );

          case BackgroundPickerStatus.failure:
            return _ErrorView(
              onRetry: () => context.read<BackgroundPickerBloc>().add(
                const BackgroundPickerRetried(),
              ),
            );

          case BackgroundPickerStatus.ready:
            return Column(
              children: [
                if (state.isRefreshing)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                    // Tiles are built lazily, so thumbnails only load
                    // as they scroll into view.
                    itemCount: state.urls.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _SelectableTile(
                          isSelected: _currentFileName == null,
                          onTap: state.downloadingUrl == null
                              ? () => _select(null)
                              : null,
                          child: const _NoneTile(),
                        );
                      }

                      final url = state.urls[index - 1];
                      final isDownloading = state.downloadingUrl == url;
                      return _SelectableTile(
                        key: ValueKey(url),
                        isSelected:
                            _currentFileName != null &&
                            _currentFileName == _fileNameOf(url),
                        onTap: state.downloadingUrl == null
                            ? () => _select(url)
                            : null,
                        child: _PresetThumbnail(
                          url: url,
                          isDownloading: isDownloading,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
        }
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Shared "current selection" look: a colored ring plus a checkmark.
class _SelectableTile extends StatelessWidget {
  final bool isSelected;

  /// Null disables the tile (e.g. while another preset is downloading).
  final VoidCallback? onTap;
  final Widget child;

  const _SelectableTile({
    super.key,
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

/// The always-first tile: clears the background.
class _NoneTile extends StatelessWidget {
  const _NoneTile();

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

/// A preset thumbnail streamed from its public URL. The image library
/// caches it on disk, so it is only fetched once. The full file is not
/// stored in the app until the user taps the tile.
class _PresetThumbnail extends StatelessWidget {
  final String url;
  final bool isDownloading;

  const _PresetThumbnail({required this.url, required this.isDownloading});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          // Tiles are ~80dp wide: decode at thumbnail size, not at the
          // wallpaper's full resolution.
          memCacheWidth: 300,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, _) =>
              ColoredBox(color: colorScheme.surfaceContainerHighest),
          errorWidget: (_, _, _) => ColoredBox(
            color: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (isDownloading)
          ColoredBox(
            color: Colors.black45,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gallery tab
// ---------------------------------------------------------------------------

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
    super.build(context);

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
/// selection, or null if dismissed without choosing. The caller checks
/// connectivity before calling this (see diary_form_page).
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