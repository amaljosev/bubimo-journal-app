// lib/features/diary_entry/presentation/widgets/overlay/sticker_picker_sheet.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/injection.dart';
import '../../bloc/sticker_picker/sticker_picker_bloc.dart';
import '../../bloc/sticker_picker/sticker_picker_event.dart';
import '../../bloc/sticker_picker/sticker_picker_state.dart';

/// Opens the sticker picker bottom sheet and returns the URL of the
/// sticker the user tapped, or `null` if they dismissed it without
/// choosing one.
///
/// Mirrors `showBackgroundPickerSheet`'s calling convention: the caller
/// (diary_form_page) owns what happens next (downloading + placing the
/// sticker as an overlay) — this function's only job is presenting the
/// picker UI and returning a selection. That download-on-select flow
/// is unchanged by the offline-seed work below: `downloadSticker`
/// already resolves instantly for anything already on disk, so a
/// seeded sticker just makes that round-trip a no-op instead of a
/// real network call.
///
/// No connectivity pre-check anymore — the bloc's own state (seeded
/// offline cache, or a real fetch failure) drives everything now, the
/// same change made to `showBackgroundPickerSheet`. Gating on
/// `NetworkInfo` before ever creating the bloc would block an offline
/// user from seeing a perfectly valid cached category.
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
  late final StickerPickerBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<StickerPickerBloc>()..add(const StickerPickerRequested());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: const _StickerPickerContent(),
    );
  }
}

class _StickerPickerContent extends StatelessWidget {
  const _StickerPickerContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: BlocBuilder<StickerPickerBloc, StickerPickerState>(
          // Compares the raw stored fields, not the `stickersByCategory`
          // getter — that getter rebuilds a fresh Map on every call, so
          // comparing it directly would (mis-)report "changed" on every
          // single state, defeating the point of buildWhen.
          buildWhen: (prev, current) =>
              prev.isLoadingCategories != current.isLoadingCategories ||
              prev.categoriesError != current.categoriesError ||
              prev.isSyncingCategories != current.isSyncingCategories ||
              prev.categoryUrls != current.categoryUrls ||
              prev.downloadedByUrl != current.downloadedByUrl,
          builder: (context, state) {
            if (state.isLoadingCategories) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.categoriesError != null) {
              // Deliberately not displaying state.categoriesError's
              // content — it's sourced from Failure.message, which can
              // carry a raw exception string. Logged in the bloc; the
              // UI only ever shows this fixed, human-readable copy.
              return const _CategoriesErrorView();
            }

            final categoriesByName = state.stickersByCategory;
            final categories = categoriesByName.keys.toList();

            if (categories.isEmpty) {
              return const _EmptyStickersView();
            }

            return Column(
              children: [
                // Subtle, non-blocking — shown only while a seed is
                // already on screen and we're checking Supabase for
                // the rest in the background.
                if (state.isSyncingCategories)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: categories.length == 1
                      ? _StickerGrid(items: categoriesByName[categories.first]!)
                      : _CategoryTabs(categoriesByName: categoriesByName),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoriesErrorView extends StatelessWidget {
  const _CategoriesErrorView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
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
            "Couldn't load stickers",
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
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
}

class _EmptyStickersView extends StatelessWidget {
  const _EmptyStickersView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tabbed view for 2+ known categories. Only ever built once
/// `stickersByCategory` already has its final category count for this
/// session (a single Supabase listing call populates all of them at
/// once — this never grows further afterward), so `DefaultTabController`
/// is created with the right `length` from the start and never needs
/// to be resized after mounting, which it does not handle gracefully.
class _CategoryTabs extends StatelessWidget {
  final Map<String, List<StickerPickerItem>> categoriesByName;

  const _CategoryTabs({required this.categoriesByName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = categoriesByName.keys.toList();

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
                // Extracted into its own StatefulWidget specifically so
                // AutomaticKeepAliveClientMixin has something to attach
                // to — TabBarView disposes offscreen tabs by default,
                // which was tearing down each grid (and its already-
                // resolved image caches) on every tab switch.
                return _StickerGrid(items: categoriesByName[category] ?? const []);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a single category's sticker grid. Each tile shows a local
/// file (already downloaded — either from the offline seed, or a
/// previous selection this session) when one's available, falling
/// back to `CachedNetworkImage` straight from the Supabase URL when
/// it's not — categories beyond the seeded one stay this way until
/// something in them is actually picked.
///
/// Kept alive across tab switches via [AutomaticKeepAliveClientMixin]
/// so [CachedNetworkImage]'s in-memory cache isn't discarded and
/// re-paid-for every time the user flips back to a previously-viewed
/// tab.
class _StickerGrid extends StatefulWidget {
  const _StickerGrid({required this.items});

  final List<StickerPickerItem> items;

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

    if (widget.items.isEmpty) {
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
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, item.url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.localPath != null
                ? Image.file(
                    File(item.localPath!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      developer.log(
                        'Failed to render cached sticker: ${item.url}',
                        name: 'StickerPickerSheet',
                        error: error,
                        stackTrace: stackTrace,
                      );
                      return const Icon(Icons.broken_image, color: Colors.grey);
                    },
                  )
                : CachedNetworkImage(
                    imageUrl: item.url,
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