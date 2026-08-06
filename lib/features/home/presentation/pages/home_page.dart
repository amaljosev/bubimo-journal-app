// lib/features/home/presentation/pages/home_page.dart

import 'dart:ui';

import 'package:bubimo/core/router/app_router.dart';
import 'package:bubimo/core/theme/background_image_theme_extension.dart';
import 'package:bubimo/core/utils/entry_grouping_utils.dart';
import 'package:bubimo/features/shared/presentation/widgets/appbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/error_screen.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../diary_entry/domain/entities/diary_entry.dart';
import '../../../home/presentation/widgets/diary_list_item.dart';
import '../../../shared/presentation/widgets/background_header_image.dart';
import '../../../shared/presentation/widgets/date_tile.dart';
import '../../../shared/presentation/widgets/empty_state_widget.dart';
import '../bloc/diary_list/diary_list_bloc.dart';
import '../bloc/diary_list/diary_list_event.dart';
import '../bloc/diary_list/diary_list_state.dart';

/// The Diary tab's content.
///
/// Unlike the other tabs, this screen provides its OWN AppBar (a
/// collapsing [SliverAppBar]) rather than consuming [MainShell]'s shared
/// one — the active theme's header image needs to sit behind the app
/// bar and collapse with scroll, which only works if the app bar is
/// part of the same [CustomScrollView] as the list. [MainShell] must
/// skip rendering its shared AppBar specifically for this tab; see the
/// note in [MainShell] where tabs are built.
///
/// Its [DiaryListBloc] is provided by [MainShell] (created once, kept
/// alive across tab switches) — this widget only consumes it via
/// [BlocBuilder]/[context.read], it does not create it.
///
/// This page only ever renders the most recent [_maxHomeEntries] entries
/// (see [_HomeViewState._cappedEntries]) — it is a preview, not the full
/// history. The full, uncapped list lives on the Timeline tab. When more
/// entries exist than fit in that cap, a "View more" row appears at the
/// bottom; tapping it calls [onViewMoreInTimeline], which [MainShell]
/// wires to switching the bottom nav to the Timeline tab (index 0) —
/// see [MainShell._openCreateEntry]'s sibling wiring for the FAB, and
/// the analogous `onTap: () => _onTabTapped(0)` passed down for this
/// callback.
///
/// RESPONSIVE NOTES (read before touching layout constants below):
/// Every dimension that used to be a bare `const double` sized for a
/// single "typical phone" reference size has been rewritten to derive
/// from either [MediaQuery] (for screen-wide decisions: overall
/// viewport height/width, text scale factor, safe-area insets — things
/// no single widget lower in the tree can see on its own) or
/// [LayoutBuilder] (for anything that instead depends on the space a
/// *specific* widget/row has actually been given, which MediaQuery
/// cannot know — it only reports the window's size, not what a parent
/// further up the tree decided to hand down). This split follows the
/// current (2026) Flutter guidance: MediaQuery for global/device-level
/// facts, LayoutBuilder for component-level available space, with
/// breakpoint math centralized rather than repeated ad hoc at each call
/// site. See [_ResponsiveMetrics] below for the centralized breakpoint
/// logic. Percentage-of-screen-width sizing (e.g. "width * 0.3") is
/// deliberately avoided per that same guidance — it scales a number,
/// but doesn't respect the actual content or intent behind it, so
/// clamped ranges are used instead of raw fractions wherever a fraction
/// is involved.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onViewMoreInTimeline});

  /// Invoked when the user taps the "View more" row at the bottom of a
  /// truncated entry list. [MainShell] supplies this as a switch to the
  /// Timeline tab (`() => _onTabTapped(0)`) rather than a route push,
  /// since Timeline already exists as a sibling tab fed by the same
  /// [DiaryListBloc] instance — pushing a new route would just show a
  /// second, disconnected copy of the same data.
  final VoidCallback onViewMoreInTimeline;

  @override
  Widget build(BuildContext context) {
    return _HomeView(onViewMoreInTimeline: onViewMoreInTimeline);
  }
}

/// Centralized breakpoint / clamp logic for this page.
///
/// Keeping every magic number that reacts to screen size in one place
/// (rather than scattered `if (width > 600)` checks at each call site)
/// is the single change most consistently called out across current
/// Flutter responsive-design guidance — it's what actually keeps
/// "responsive" maintainable instead of a pile of independent hacks
/// that drift out of sync with each other over time.
///
/// Every method here is a pure function of the inputs it's given
/// (never reads [BuildContext]/[MediaQuery] itself), so callers decide
/// once, at the point they already have a [MediaQuery]/[LayoutBuilder]
/// value in hand, and every derived number stays consistent with it.
abstract final class _ResponsiveMetrics {
  /// Clamps the diary header's expanded height so it never eats an
  /// unreasonable share of the viewport.
  ///
  /// [preferredHeight] is the designer's original target (200, the
  /// prior constant). [viewportHeight] is the *actual* screen height
  /// for this device/orientation/window
  /// ([MediaQuery.sizeOf(context).height] — a screen-global fact
  /// LayoutBuilder's sliver constraints can't give us here, since a
  /// [SliverAppBar]'s own constraints are just "how tall can you be",
  /// not "how tall is the whole window").
  ///
  /// On a normal portrait phone (viewport height well over 700), this
  /// returns [preferredHeight] unchanged — nothing changes for the
  /// common case. It only kicks in on short view ports: a phone rotated
  /// to landscape, a small device, a resizable desktop/web window
  /// pulled short, or a split-screen pane — where a fixed 200px header
  /// could otherwise leave too little (or negative) room for content
  /// beneath it, which is the class of bug a fixed fullscreen-oriented
  /// constant tends to produce on "some device" that isn't the one it
  /// was tuned against.
  static double diaryHeaderExpandedHeight({
    required double preferredHeight,
    required double viewportHeight,
  }) {
    final maxByViewport = viewportHeight * 0.28;
    // Lower bound keeps FlexibleSpaceBar's title/back-affordance area
    // usable even on the shortest view ports; upper bound is whichever
    // of the design target or the viewport-scaled ceiling is smaller.
    return preferredHeight.clamp(120.0, maxByViewport).toDouble();
  }

  /// Height of the pinned favorites-toggle bar.
  ///
  /// The prior implementation hardcoded this to 64 (12 top padding + 40
  /// toggle height + 12 bottom padding) assuming the toggle's own
  /// content — a Row of icon + text — always fits inside a 40px-tall
  /// segment. That assumption silently breaks once the user has scaled
  /// up system text size (Settings > Display > Font size on Android,
  /// or Dynamic Type on iOS): [textScaleFactor] comes from
  /// [MediaQuery.textScalerOf(context)], a screen-global accessibility
  /// setting no single child widget can discover on its own, which is
  /// exactly the kind of fact MediaQuery (not LayoutBuilder) is for.
  ///
  /// Scaling only the *toggle* portion (not the padding) keeps the
  /// visual rhythm intact at 1.0x scale while still leaving headroom
  /// once text grows.
  static double pinnedFavoritesBarHeight({required double textScaleFactor}) {
    const topPadding = 12.0;
    const bottomPadding = 12.0;
    const baseToggleHeight = 40.0;
    final scaledToggleHeight =
        baseToggleHeight * textScaleFactor.clamp(1.0, 1.3);
    return topPadding + scaledToggleHeight + bottomPadding;
  }

  /// Width of a single segment in [_FavoritesFilterToggle], given the
  /// width actually available to the toggle (from [LayoutBuilder] at
  /// its call site — the toggle is centered inside a pinned header, so
  /// its *available* width is the header's width, which is not
  /// necessarily the full device width once other padding/insets are
  /// accounted for; MediaQuery's raw screen width would overstate it).
  ///
  /// Clamped rather than left as a raw fraction of [availableWidth]:
  /// - Floor of 84 keeps "Favorites" + its icon from clipping/wrapping
  ///   even on the narrowest supported phone widths.
  /// - Ceiling of 132 stops the toggle from stretching absurdly wide
  ///   on a tablet/desktop window, where "half the available width"
  ///   would otherwise produce a segment far wider than the label
  ///   inside it needs.
  static double favoritesToggleSegmentWidth({required double availableWidth}) {
    // Two segments plus track padding on both sides and between them.
    const trackPadding = 4.0;
    final perSegmentBudget = (availableWidth - trackPadding * 2) / 2;
    return perSegmentBudget.clamp(84.0, 132.0);
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView({required this.onViewMoreInTimeline});

  final VoidCallback onViewMoreInTimeline;

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  /// Design-time target for the header's expanded height. Actual
  /// rendered height is derived from this via
  /// [_ResponsiveMetrics.diaryHeaderExpandedHeight] in [build], which
  /// clamps it against the real viewport height — see that method's
  /// doc for why a bare constant here previously risked overflow-
  /// adjacent layout breakage on short view ports.
  static const double _headerExpandedHeightPreferred = 200;

  /// Home is a preview of the most recent entries, not the full diary.
  /// Only this many of [DiaryListState.visibleEntries] are ever grouped
  /// and rendered here; anything beyond this is reached via the "View
  /// more" row, which hands off to the Timeline tab (see
  /// [HomePage.onViewMoreInTimeline]).
  ///
  /// NOTE: this cap is applied client-side to whatever the bloc already
  /// loaded into [DiaryListState.visibleEntries] — it does not change
  /// how many entries the bloc fetches. If the bloc/repository were ever
  /// changed to page-fetch only 20 entries at a time, this cap could no
  /// longer distinguish "exactly 20 entries exist" from "more exist
  /// beyond 20"; that distinction would need a real total-count/hasMore
  /// signal from the repository. Left as UI-only per current scope.
  static const int _maxHomeEntries = 20;

  // Note: creating a new entry is no longer triggered from this page's
  // own FAB — MainShell's NotchedNavBar owns a single persistent "+"
  // button (in the nav bar's notch) that opens AppRoutes.diaryForm from
  // any tab. See MainShell._openCreateEntry.

  Future<void> _openEntry(BuildContext context, String entryId) async {
    final result = await context.push<bool>(
      AppRoutes.diaryView,
      extra: entryId,
    );

    if (result == true && context.mounted) {
      context.read<DiaryListBloc>().add(const LoadDiaryEntries());
    }
  }

  /// Slices [entries] down to [_maxHomeEntries] for display purposes.
  /// Grouping and year-separator logic both run on the already-capped
  /// list, so a day-group (and, in turn, a year) can end mid-way
  /// through — matching the "view more" button sitting immediately
  /// after entry 20 regardless of which day/year it happens to fall in.
  List<DiaryEntry> _cappedEntries(List<DiaryEntry> entries) {
    if (entries.length <= _maxHomeEntries) return entries;
    return entries.sublist(0, _maxHomeEntries);
  }

  @override
  Widget build(BuildContext context) {
    final headerImagePath = Theme.of(
      context,
    ).extension<BackgroundImageTheme>()?.imagePath;
    final colorScheme = Theme.of(context).colorScheme;
    final currentYear = DateTime.now().year;

    // Screen-global facts read once here and threaded down, rather
    // than re-querying MediaQuery deep in the tree per source
    // guidance's note that every MediaQuery read is a potential
    // rebuild dependency — reading once at the top and passing plain
    // doubles/values down means a resize only rebuilds this single
    // build(), not additionally whatever nested widgets would have
    // held their own separate MediaQuery.of(context) calls.
    final viewportSize = MediaQuery.sizeOf(context);
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);

    final headerExpandedHeight = _ResponsiveMetrics.diaryHeaderExpandedHeight(
      preferredHeight: _headerExpandedHeightPreferred,
      viewportHeight: viewportSize.height,
    );
    final pinnedFavoritesBarHeight = _ResponsiveMetrics
        .pinnedFavoritesBarHeight(textScaleFactor: textScaleFactor);

    return Scaffold(
      extendBodyBehindAppBar: headerImagePath != null,
      appBar:  headerImagePath == null?myAppbar(context, '', null):null,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (headerImagePath != null)
            SliverAppBar(
              expandedHeight: headerExpandedHeight,
              centerTitle: true,
              // No back button on a tab root, and no theme-agnostic
              // elevation shadow riding on top of the header image.
              automaticallyImplyLeading: false,
              elevation: 0,

              // Only worth enabling the overscroll stretch effect when
              // there's actually a header image to stretch — with the
              // plain kToolbarHeight bar (no image) there's nothing for
              // `stretch` to visually affect, so it's skipped to avoid
              // spending the extra overscroll-physics work for no effect.
              stretch: true,

              // How far past the top the user must pull before
              // `onStretchTrigger` fires. Note this only gates the
              // *callback* — the zoomBackground visual itself starts
              // scaling immediately on any overscroll, growing
              // proportionally the further past the top edge the user
              // drags, so this value doesn't need to be large to see
              // the zoom kick in.
              stretchTriggerOffset: 50,
              onStretchTrigger: () async {},
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.fadeTitle,
                ],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackgroundHeaderImage(path: headerImagePath),

                    // Frosted transition band: blurs only the bottom portion
                    // of the image itself (not whatever sits behind the
                    // sliver boundary), with the blur intensity ramping in
                    // via ShaderMask rather than switching on at a hard edge.
                    // Because this sits inside the image's own Stack, it
                    // always has real image content beneath it regardless of
                    // scroll offset — unlike a separate BackdropFilter widget
                    // positioned below the sliver, which only has whatever
                    // happens to be rendered there at that scroll position.
                    //
                    // Height derives from headerExpandedHeight (the
                    // clamped, per-viewport value) rather than the old
                    // bare _headerExpandedHeight constant, so this band
                    // stays proportional to whatever height the header
                    // actually ended up rendering at on this device —
                    // on a short/landscape viewport where the header
                    // was clamped down, the band shrinks with it
                    // instead of overshooting a header that's no
                    // longer 200px tall.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: headerExpandedHeight * 0.5,
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          // Alpha ramp controls how much blur "shows through"
                          // at each height — 0 at top (no blur) to full blur
                          // at the very bottom, so the transition itself
                          // feels gradual instead of a visible blur/no-blur
                          // line.
                          colors: [Colors.transparent, Colors.black],
                          stops: [0.0, 0.85],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),

                    // Readability scrim up top, unchanged.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment(0, -0.2),
                          colors: [
                            Color.fromRGBO(0, 0, 0, 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // Color fade to the exact body surface color — this is
                    // what actually dissolves the image into the page
                    // background by the time the sliver boundary is reached.
                    // Placed after the blur layer so it composites on top,
                    // softening the blurred pixels into flat color at the
                    // very bottom rather than leaving softened-but-still-
                    // visible image detail right at the seam.
                    //
                    // Height likewise derives from headerExpandedHeight
                    // rather than the old fixed constant, for the same
                    // proportionality reason as the blur band above.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: headerExpandedHeight * 0.55,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.surface.withValues(alpha: 0),
                              colorScheme.surface.withValues(alpha: 0.55),
                              colorScheme.surface,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Pinned favorites toggle bar. Using SliverPersistentHeader
          // (pinned: true) instead of a SliverToBoxAdapter so this
          // sticks to the top of the CustomScrollView — right below
          // the (unpinned) SliverAppBar above — once the header image
          // has scrolled out of view, rather than scrolling away with
          // the rest of the list content.
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedFavoritesHeaderDelegate(
              backgroundColor: Colors.transparent,
              // Height now scales with system text size (see
              // _ResponsiveMetrics.pinnedFavoritesBarHeight) instead of
              // a bare 64 that assumed 1.0x scale — prevents the
              // toggle's own text/icon from clipping against this
              // delegate's fixed minExtent/maxExtent when the user has
              // large system font sizes on.
              height: pinnedFavoritesBarHeight,
              child: BlocBuilder<DiaryListBloc, DiaryListState>(
                builder: (context, state) {
                  return Center(
                    // LayoutBuilder here (rather than reaching for
                    // MediaQuery again) because what the toggle needs
                    // to know is "how wide is the box this delegate
                    // gave me", i.e. this widget's own parent-provided
                    // constraints — not the device's overall screen
                    // width, which could differ once the pinned
                    // header's own horizontal padding/insets are
                    // accounted for. This is the LayoutBuilder-vs-
                    // MediaQuery distinction the responsive-design
                    // sources consistently draw: MediaQuery answers
                    // "how big is the window", LayoutBuilder answers
                    // "how much room do I actually have here".
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _FavoritesFilterToggle(
                          showFavoritesOnly: state.showFavoritesOnly,
                          availableWidth: constraints.maxWidth,
                          onChanged: (value) => context
                              .read<DiaryListBloc>()
                              .add(FavoritesFilterChanged(value)),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          BlocBuilder<DiaryListBloc, DiaryListState>(
            builder: (context, state) {
              switch (state.status) {
                case DiaryListStatus.initial:
                case DiaryListStatus.loading:
                  return const SliverFillRemaining(child: LoadingScreen());

                case DiaryListStatus.failure:
                  return SliverFillRemaining(
                    child: ErrorScreen(
                      message: state.errorMessage ?? 'Something went wrong.',
                      onRetry: () => context.read<DiaryListBloc>().add(
                        const LoadDiaryEntries(),
                      ),
                    ),
                  );

                case DiaryListStatus.loaded:
                  if (state.isEmpty) {
                    return SliverFillRemaining(
                      child: EmptyStateWidget(
                        isFavoritesFilter: state.showFavoritesOnly,
                        // Creating an entry is now driven by the nav
                        // bar's persistent FAB rather than a callback
                        // owned by this page; push the same route
                        // directly so the empty-state button still
                        // works standalone.
                        onCreatePressed: () async {
                          final result = await context.push<bool>(
                            AppRoutes.diaryForm,
                          );
                          if (result == true && context.mounted) {
                            context.read<DiaryListBloc>().add(
                              const LoadDiaryEntries(),
                            );
                          }
                        },
                      ),
                    );
                  }

                  // Home only ever previews the most recent entries;
                  // see [_HomeViewState._maxHomeEntries] doc for why
                  // this is a client-side cap on top of whatever the
                  // bloc loaded, and its limitation vs. real pagination.
                  final totalLoadedCount = state.visibleEntries.length;
                  final cappedEntries = _cappedEntries(state.visibleEntries);
                  // Only meaningful as "there's more beyond what's
                  // shown" when strictly more than the cap were loaded.
                  // At exactly _maxHomeEntries total, everything is
                  // already on screen, so a "View more" row would lead
                  // to a Timeline tab showing the identical entries —
                  // the button is gated on `>`, not `>=`, to avoid that
                  // dead-end. See doc comment on [HomePage] for detail.
                  final hasMoreThanCap =
                      totalLoadedCount > _maxHomeEntries;

                  final dayGroups = EntryGroupingUtils.groupByDay<DiaryEntry>(
                    cappedEntries,
                    (entry) => entry.date,
                  );

                  // Flatten day-groups into a single render list, with a
                  // year-separator row spliced in immediately before the
                  // first group of each year change. No separator is
                  // ever shown for the current calendar year — the
                  // running "last shown year" starts pre-seeded to
                  // `currentYear`, so a leading group in the current
                  // year never trips the "year changed" check, while a
                  // leading group from an earlier year trips it right
                  // away (matches "show the previous year" starting
                  // immediately if the very first entries aren't from
                  // this year).
                  final rows = <_HomeRow>[];
                  var lastShownYear = currentYear;
                  for (final group in dayGroups) {
                    final groupYear = group.date.year;
                    if (groupYear != lastShownYear) {
                      rows.add(_YearSeparatorRow(groupYear));
                      lastShownYear = groupYear;
                    }
                    rows.add(
                      _DayGroupRow(date: group.date, entries: group.entries),
                    );
                  }

                  return SliverPadding(
                    // Extra bottom inset (beyond the standard 16) so
                    // the last entries clear the floating NotchedNavBar.
                    // MainShell uses `extendBody: true` so this list
                    // draws full-height behind the bar; without this,
                    // the bottom-most entries would sit under its
                    // opaque surface. ~140 comfortably clears the bar's
                    // total height (flat bar + FAB protrusion) at
                    // typical text scale; on very large system text
                    // sizes the nav bar itself may grow too, but that
                    // bar owns its own responsive sizing (out of scope
                    // for this file) — this padding only needs to
                    // clear it, not compute it.
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                    sliver: SliverList.separated(
                      // +1 trailing slot for the "View more" row, only
                      // ever populated when hasMoreThanCap is true.
                      itemCount: rows.length + (hasMoreThanCap ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        if (index >= rows.length) {
                          // Trailing "View more" row — only reachable
                          // when hasMoreThanCap added the extra slot.
                          return _ViewMoreRow(
                            onTap: widget.onViewMoreInTimeline,
                          );
                        }

                        final row = rows[index];
                        return switch (row) {
                          _YearSeparatorRow(:final year) =>
                            _YearSeparatorLabel(year: year),
                          _DayGroupRow(:final date, :final entries) =>
                            // LayoutBuilder here rather than trusting a
                            // bare Row: on an extremely narrow viewport
                            // (a small phone in split-screen, or a
                            // resizable desktop/web window pulled
                            // narrow), the fixed-width DateTile column
                            // plus its SizedBox gap could in principle
                            // leave the Expanded card too little space
                            // to lay out its own internal Row (mood
                            // emoji + label) without that inner Row
                            // itself overflowing horizontally — the
                            // card's own text already clips safely via
                            // maxLines/ellipsis, but a Row of
                            // fixed-size children (icon + label) has no
                            // such fallback on its own. Constraining
                            // the date column's width relative to what
                            // this specific row was actually given
                            // (constraints.maxWidth, not the device's
                            // overall MediaQuery width, which may
                            // overstate it once outer list padding is
                            // subtracted) keeps that from ever reducing
                            // the card's Expanded share below a usable
                            // floor.
                            LayoutBuilder(
                              builder: (context, constraints) {
                                const dateColumnGap = 12.0;
                                const preferredDateColumnWidth = 50.0;
                                // Reserve at least enough width for the
                                // card to render its mood row without
                                // squeezing below a usable minimum;
                                // shrink the date column first since
                                // its own content (a 2-digit day number
                                // + short weekday abbreviation) tolerates
                                // a narrower column better than the
                                // card's Row of icon-plus-label content
                                // does.
                                const minCardWidth = 160.0;
                                final maxDateColumnWidth =
                                    constraints.maxWidth -
                                    dateColumnGap -
                                    minCardWidth;
                                final dateColumnWidth =
                                    preferredDateColumnWidth
                                        .clamp(0.0, maxDateColumnWidth.clamp(0.0, preferredDateColumnWidth))
                                        .toDouble();

                                return Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: dateColumnWidth,
                                      child: DateTile(date: date),
                                    ),
                                    const SizedBox(width: dateColumnGap),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < entries.length;
                                            i++
                                          )
                                            ...[
                                              if (i > 0)
                                                const SizedBox(height: 8),
                                              DiaryListItem(
                                                entry: entries[i],
                                                showDateColumn: false,
                                                onTap: () => _openEntry(
                                                  context,
                                                  entries[i].id,
                                                ),
                                              ),
                                            ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        };
                      },
                    ),
                  );
              }
            },
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 200)),
        ],
      ),
    );
  }
}

/// Sealed render-row model for the flattened Home list: either a
/// year-separator label or a day-group. Lets a single
/// [SliverList.separated] mix both without a second sliver / nested
/// list, so the existing separatorBuilder spacing keeps applying
/// uniformly between every row, separator or not.
///
/// [_DayGroupRow] pulls just `date` and `entries` out of
/// `EntryGroupingUtils`' day-group object rather than storing that
/// object itself, since its concrete class name isn't imported here
/// and isn't needed — the original code only ever used `group.date`
/// (a `DateTime`) and `group.entries` (a `List<DiaryEntry>`), so
/// storing exactly those two, concretely typed, keeps everything
/// statically checked without introducing generics whose interaction
/// with sealed-class pattern matching would need a Dart SDK to verify
/// (none is available in this environment — see the network/filesystem
/// tool results earlier in this conversation).
sealed class _HomeRow {
  const _HomeRow();
}

final class _YearSeparatorRow extends _HomeRow {
  const _YearSeparatorRow(this.year);
  final int year;
}

final class _DayGroupRow extends _HomeRow {
  const _DayGroupRow({required this.date, required this.entries});
  final DateTime date;
  final List<DiaryEntry> entries;
}

/// Plain centered year label ("2023", "2022", …) marking the point
/// where entries roll over into an earlier year. Deliberately not
/// wrapped in a card/background — the user's spec shows it as bare
/// "text", sitting in the flow between day-groups, not as a chip.
class _YearSeparatorLabel extends StatelessWidget {
  const _YearSeparatorLabel({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$year',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Trailing row shown only when more than [_HomeViewState._maxHomeEntries]
/// entries are loaded. Hands off to [HomePage.onViewMoreInTimeline],
/// which [MainShell] wires to a Timeline-tab switch rather than a new
/// route push (see [HomePage] doc comment for why).
class _ViewMoreRow extends StatelessWidget {
  const _ViewMoreRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
          ),
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('View more in Timeline'),
        ),
      ),
    );
  }
}

/// [SliverPersistentHeaderDelegate] that pins the favorites filter
/// toggle to the top of the scroll view.
///
/// Gives the toggle a fixed, solid-color background (matching the
/// scaffold's surface) rather than a transparent one — once pinned,
/// list items scroll underneath it, so it needs an opaque backing to
/// avoid content showing through/behind the toggle.
///
/// [height] is now a constructor parameter rather than a bare
/// `static const _height = 64` — the caller
/// ([_HomeViewState.build]) computes it from
/// [_ResponsiveMetrics.pinnedFavoritesBarHeight], which factors in the
/// device's current system text-scale factor. minExtent/maxExtent are
/// both set to this same value (as before, keeping the bar's height
/// fixed *for a given text scale* rather than allowing it to shrink
/// while pinned), so the only thing that changed is *what* that fixed
/// value resolves to.
class _PinnedFavoritesHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedFavoritesHeaderDelegate({
    required this.child,
    required this.backgroundColor,
    required this.height,
  });

  final Widget child;
  final Color backgroundColor;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedFavoritesHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.height != height;
  }
}

/// A pill-shaped, two-option toggle ("All" / "Favorites") with an
/// animated sliding capsule behind the selected label.
///
/// Both segments are given an identical width (rather than sizing to
/// their own text/icon content), so the sliding capsule's position is
/// always an exact, symmetric half of the track — no drift between
/// "All" (shorter label) and "Favorites" (longer label with icon).
///
/// That shared segment width is now [availableWidth]-driven (via
/// [_ResponsiveMetrics.favoritesToggleSegmentWidth]) instead of a bare
/// `108.0` constant. [availableWidth] is supplied by the caller from a
/// [LayoutBuilder] wrapping this widget — deliberately *not* read here
/// via `MediaQuery.of(context).size.width` (which the prior code did
/// fetch into a local `size` variable but never actually used): the
/// width this toggle needs to fit inside is however much room its
/// *parent* (the pinned header, centered) handed it, which is not
/// necessarily the same number as the full device screen width once
/// that header's own padding/insets are subtracted — MediaQuery can't
/// see that, only LayoutBuilder can.
class _FavoritesFilterToggle extends StatelessWidget {
  const _FavoritesFilterToggle({
    required this.showFavoritesOnly,
    required this.availableWidth,
    required this.onChanged,
  });

  final bool showFavoritesOnly;
  final double availableWidth;
  final ValueChanged<bool> onChanged;

  static const _height = 40.0;
  static const _trackPadding = 4.0;
  static const _radius = Radius.circular(_height / 2);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final segmentWidth = _ResponsiveMetrics.favoritesToggleSegmentWidth(
      availableWidth: availableWidth,
    );
    final trackWidth = segmentWidth * 2 + _trackPadding * 2;

    return Container(
      height: _height,
      width: trackWidth,
      padding: const EdgeInsets.all(_trackPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.all(_radius),
      ),
      child: Stack(
        children: [
          // Sliding highlight capsule. Positioned with exact pixel
          // offsets (0 vs. segmentWidth) rather than Alignment, so it
          // always sits flush under whichever segment is active,
          // regardless of that segment's own content width.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: showFavoritesOnly ? segmentWidth : 0,
            top: 0,
            bottom: 0,
            width: segmentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.all(_radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _buildOption(
                context,
                label: 'All',
                icon: null,
                isSelected: !showFavoritesOnly,
                segmentWidth: segmentWidth,
                onTap: () => onChanged(false),
              ),
              _buildOption(
                context,
                label: 'Favorites',
                icon: Icons.favorite_rounded,
                isSelected: showFavoritesOnly,
                segmentWidth: segmentWidth,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String label,
    required IconData? icon,
    required bool isSelected,
    required double segmentWidth,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return SizedBox(
      width: segmentWidth,
      height: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            color: foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
              ],
              // Flexible + ellipsis: at the narrowest clamped segment
              // width (84px) combined with a large system text scale
              // factor, "Favorites" could in principle still be tight;
              // Flexible with ellipsis means that edge degrades to a
              // clipped label with "…" rather than a Row-level
              // horizontal overflow (a yellow/black striped overflow
              // banner), which is strictly worse than a truncated word
              // in a toggle whose two states are already visually
              // distinguished by the sliding capsule position, icon
              // presence, and color — the label text alone isn't the
              // only cue.
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}