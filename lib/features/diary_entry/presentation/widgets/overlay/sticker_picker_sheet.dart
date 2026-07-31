// lib/features/diary_entry/presentation/widgets/overlay/sticker_picker_sheet.dart

import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/network/network_info.dart';
import '../../../../../core/widgets/needs_internet_inline.dart';
import '../../bloc/sticker_picker/sticker_picker_bloc.dart';

/// Opens the sticker picker bottom sheet and returns the URL of the
/// sticker the user tapped, or `null` if they dismissed it without
/// choosing one.
///
/// Mirrors `showBackgroundPickerSheet`'s calling convention: the caller
/// (diary_form_page) owns what happens next (downloading + placing the
/// sticker as an overlay) — this function's only job is presenting the
/// picker UI and returning a selection.
///
/// Gates on connectivity before ever dispatching the Supabase category
/// fetch: `_StickerPickerSheetState` checks `NetworkInfo` first and
/// shows `NeedsInternetInline` in place of the picker if there's none,
/// with its own retry — the bloc's own `categoriesError` state (below)
/// stays as a second layer for a fetch that starts fine but fails
/// mid-flight (rate limit, Supabase outage, connection dropping
/// between the gate check and the fetch actually completing).
Future<String?> showStickerPickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _StickerPickerSheet(),
  );
}

class _StickerPickerSheet extends StatefulWidget {
  const _StickerPickerSheet();

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet> {
  final NetworkInfo _networkInfo = getIt<NetworkInfo>();

  /// Null while the first connectivity check is still running; true/
  /// false once known. Checked BEFORE the bloc is even created, so an
  /// offline visit never fires the Supabase category fetch at all —
  /// same reasoning as `CloudBackupGate` checking before building the
  /// real cloud backup screen, just for a sheet instead of a route.
  bool? _hasInternet;
  bool _isRetrying = false;

  StickerPickerBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _check(initial: true);
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  Future<void> _check({bool initial = false}) async {
    setState(() => _isRetrying = !initial);

    final hasInternet = await _networkInfo.isConnected;
    if (!mounted) return;

    setState(() {
      _hasInternet = hasInternet;
      _isRetrying = false;
    });

    if (hasInternet && _bloc == null) {
      _bloc = getIt<StickerPickerBloc>()
        ..add(const StickerPickerRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasInternet == null) {
      return const SafeArea(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_hasInternet!) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: NeedsInternetInline(
            action: 'browse stickers',
            isRetrying: _isRetrying,
            onRetry: () => _check(),
          ),
        ),
      );
    }

    return BlocProvider.value(
      value: _bloc!,
      child: const _StickerPickerContent(),
    );
  }
}

class _StickerPickerContent extends StatelessWidget {
  const _StickerPickerContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: BlocBuilder<StickerPickerBloc, StickerPickerState>(
          buildWhen: (prev, current) =>
              prev.isLoadingCategories != current.isLoadingCategories ||
              prev.categoriesError != current.categoriesError ||
              prev.stickersByCategory != current.stickersByCategory,
          builder: (context, state) {
            if (state.isLoadingCategories) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.categoriesError != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 34,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No internet connection',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You need an internet connection to browse '
                      'stickers.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: () => context.read<StickerPickerBloc>().add(
                        const StickerPickerRetried(),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              );
            }

            final categories = state.stickersByCategory.keys.toList();
            log(categories.toString());

            if (categories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No stickers yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return DefaultTabController(
              length: categories.length,
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: categories.map((cat) => Tab(text: cat)).toList(),
                      labelStyle: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      indicatorSize: TabBarIndicatorSize.label,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: categories.map((category) {
                        final urls = state.stickersByCategory[category] ?? [];
                        // Extracted into its own StatefulWidget (below)
                        // specifically so AutomaticKeepAliveClientMixin
                        // has something to attach to — TabBarView
                        // disposes offscreen tabs by default, which was
                        // tearing down each grid (and its already-cached
                        // CachedNetworkImage widgets) on every tab
                        // switch and forcing a full placeholder-then-
                        // decode cycle on return, even though the bytes
                        // were already on disk.
                        return _StickerGrid(urls: urls);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Renders a single category's sticker grid.
///
/// Kept alive across tab switches via [AutomaticKeepAliveClientMixin]
/// so [CachedNetworkImage]'s in-memory image cache (and the disk-cache
/// lookups it already resolved) aren't discarded and re-paid-for every
/// time the user flips back to a previously-viewed tab.
class _StickerGrid extends StatefulWidget {
  const _StickerGrid({required this.urls});

  final List<String> urls;

  @override
  State<_StickerGrid> createState() => _StickerGridState();
}

class _StickerGridState extends State<_StickerGrid>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin — omitting this call
    // means wantKeepAlive is silently ignored.
    super.build(context);

    if (widget.urls.isEmpty) {
      return Center(
        child: Text(
          'Nothing in this category',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: widget.urls.length,
      itemBuilder: (context, index) {
        final url = widget.urls[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => const CupertinoActivityIndicator(),
              errorWidget: (_, _, _) =>
                  const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}