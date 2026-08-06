// lib/features/timeline/presentation/pages/timeline_page.dart

import 'package:bubimo/core/utils/date_utils.dart';
import 'package:bubimo/core/utils/entry_grouping_utils.dart';
import 'package:bubimo/features/home/presentation/widgets/diary_list_item.dart';
import 'package:bubimo/features/shared/presentation/widgets/appbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/background_image_theme_extension.dart';
import '../../../diary_entry/domain/entities/diary_entry.dart';
import '../../../home/presentation/bloc/diary_list/diary_list_bloc.dart';
import '../../../home/presentation/bloc/diary_list/diary_list_event.dart';
import '../../../home/presentation/bloc/diary_list/diary_list_state.dart';
import '../../../shared/presentation/widgets/background_header_image.dart';
import '../cubit/timeline_cubit.dart';
import '../cubit/timeline_state.dart';
import '../widgets/timeline_day_cells.dart';
import '../widgets/timeline_entry_card.dart';
import '../widgets/timeline_pills.dart';

/// The Timeline tab's content — a calendar view of every diary entry,
/// with a day-by-day breakdown below.
///
/// Ported from an earlier version of the app's `DiaryCalendarScreen`,
/// restyled to this app's theme system (colors/text styles pulled
/// live from [Theme.of(context)] rather than hardcoded, so it follows
/// whatever theme — including custom ones — is currently active).
///
/// Entries come from the shared [DiaryListBloc] that [MainShell] already
/// keeps alive (same source Diary/Favorites use) — this screen does not
/// fetch its own data. Only calendar navigation state (focused/selected
/// day) is local, owned by [TimelineCubit].
///
/// Rebuild scoping: the hero header, the calendar, and the
/// selected-day breakdown are each wrapped in their own narrow
/// BlocBuilder/BlocSelector so that, e.g., tapping a different day only
/// rebuilds the day header + entry list below — not the calendar grid
/// or the hero stats — and a `DiaryListBloc` emission only rebuilds the
/// calendar/hero if the actual entries changed.
class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TimelineCubit(),
      child: const _TimelineView(),
    );
  }
}

class _TimelineView extends StatefulWidget {
  const _TimelineView();

  @override
  State<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<_TimelineView>
    with TickerProviderStateMixin {
  late final AnimationController _entryListController;
  late final Animation<double> _entryListFade;

  @override
  void initState() {
    super.initState();
    _entryListController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _entryListFade = CurvedAnimation(
      parent: _entryListController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _entryListController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  // Date math (normalize/compare/mood-lookup/marked-dates) now lives in
  // AppDateUtils / EntryGroupingUtils — this class only wires those
  // shared helpers to DiaryEntry-specific field access.

  static List<DiaryEntry> _entriesForDay(DateTime day, List<DiaryEntry> all) {
    return EntryGroupingUtils.itemsForDay<DiaryEntry>(day, all, (e) => e.date);
  }

  static Set<DateTime> _markedDates(List<DiaryEntry> entries) {
    return EntryGroupingUtils.markedDays<DiaryEntry>(entries, (e) => e.date);
  }

  static bool _dayHasFavorite(DateTime day, List<DiaryEntry> entries) {
    return EntryGroupingUtils.anyOnDay<DiaryEntry>(
      day,
      entries,
      (e) => e.date,
      (e) => e.isFavorite,
    );
  }

  /// First mood emoji found for the day, or '' if none set.
  static String _moodForDay(DateTime day, List<DiaryEntry> entries) {
    return EntryGroupingUtils.firstOnDay<DiaryEntry, String>(
          day,
          entries,
          (e) => e.date,
          (e) => e.mood?.emoji,
        ) ??
        '';
  }

  void _onDaySelected(DateTime day) {
    context.read<TimelineCubit>().daySelected(day);
    _entryListController
      ..reset()
      ..forward();
  }

  Future<void> _navigateToEntry(DiaryEntry entry) async {
    final result = await context.push<bool>(
      AppRoutes.diaryView,
      extra: entry.id,
    );
    if (result == true && mounted) {
      context.read<DiaryListBloc>().add(const LoadDiaryEntries());
    }
  }

  bool _isNavigatingToFavorites = false;

  void _goToFavorites() {
    if (_isNavigatingToFavorites) return;
    _isNavigatingToFavorites = true;

    context.push(AppRoutes.favorites).then((_) {
      if (mounted) {
        setState(() => _isNavigatingToFavorites = false);
      } else {
        _isNavigatingToFavorites = false;
      }
    });
  }

  // ── Day cell builder ─────────────────────────────────────────────────

  static Widget _buildDayCell({
    required BuildContext context,
    required DateTime day,
    required List<DiaryEntry> entries,
    required Set<DateTime> markedDates,
    required bool isToday,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final norm = AppDateUtils.dateOnlyUtc(day);
    final hasEntry = markedDates.contains(norm);
    final hasFav = _dayHasFavorite(day, entries);
    final mood = _moodForDay(day, entries);

    if (isSelected) {
      return SelectedDayCell(day: day, hasFav: hasFav, mood: mood);
    }
    if (hasFav) {
      return FavoriteDayCell(day: day, mood: mood);
    }
    if (hasEntry) {
      return EntryDayCell(day: day, mood: mood);
    }
    if (isToday) {
      return TodayEmptyCell(day: day);
    }
    return Center(
      child: Text(
        '${day.day}',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bgImagePath = Theme.of(
      context,
    ).extension<BackgroundImageTheme>()?.imagePath;

    return Scaffold(
      appBar: bgImagePath != null
          ? null
          : myAppbar(
              context,
              'Timeline',
              IconPill(
                onTap: _goToFavorites,
                color: Colors.redAccent,
                icon: Icons.favorite,
                textColor: Colors.white,
                label: '',
              ),
            ),
      body: BlocBuilder<DiaryListBloc, DiaryListState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.entries != current.entries ||
            previous.errorMessage != current.errorMessage,
        builder: (context, listState) {
          if (listState.status == DiaryListStatus.loading ||
              listState.status == DiaryListStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (listState.status == DiaryListStatus.failure) {
            return _ErrorView(
              message: listState.errorMessage ?? 'Something went wrong.',
              onRetry: () =>
                  context.read<DiaryListBloc>().add(const LoadDiaryEntries()),
            );
          }

          final entries = listState.entries;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (bgImagePath != null)
                BlocSelector<TimelineCubit, TimelineState, DateTime>(
                  selector: (state) => state.focusedDay,
                  builder: (context, focusedDay) {
                    return _TimelineHeroAppBar(
                      entries: entries,
                      focusedDay: focusedDay,
                      bgImagePath: bgImagePath,
                      onFavoritesTap: _goToFavorites,
                    );
                  },
                ),

              BlocBuilder<TimelineCubit, TimelineState>(
                builder: (context, timelineState) {
                  final focusedDay = timelineState.focusedDay;
                  final selectedDay = timelineState.selectedDay;
                  final markedDates = _markedDates(entries);

                  return SliverToBoxAdapter(
                    child: _TimelineCalendarCard(
                      focusedDay: focusedDay,
                      selectedDay: selectedDay,
                      entries: entries,
                      markedDates: markedDates,
                      onDaySelected: _onDaySelected,
                      onPageChanged: (foc) =>
                          context.read<TimelineCubit>().pageChanged(foc),
                      dayCellBuilder: _buildDayCell,
                    ),
                  );
                },
              ),

              // ── Legend ─────────────────────────────────────────────
              const SliverToBoxAdapter(child: _CalendarLegend()),

              // ── Selected day header + entries ─────────────────────
              // This is the part that changes on every day tap, so it's
              // isolated in its own BlocSelector keyed off selectedDay
              // (entries is already scoped to the outer builder).
              BlocSelector<TimelineCubit, TimelineState, DateTime>(
                selector: (state) => state.selectedDay,
                builder: (context, selectedDay) {
                  final dayEntries = _entriesForDay(selectedDay, entries);

                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _SelectedDayHeader(
                          selectedDay: selectedDay,
                          dayEntryCount: dayEntries.length,
                        ),
                      ),
                      if (dayEntries.isEmpty)
                        const SliverToBoxAdapter(child: TimelineEmptyDayView())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((ctx, i) {
                              return FadeTransition(
                                opacity: _entryListFade,
                                child: SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.08),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _entryListController,
                                          curve: Interval(
                                            i * 0.12,
                                            1.0,
                                            curve: Curves.easeOut,
                                          ),
                                        ),
                                      ),
                                  child: DiaryListItem(
                                    key: ValueKey(dayEntries[i].id),
                                    entry: dayEntries[i],
                                    showDateColumn: false,
                                    onTap: () =>
                                        _navigateToEntry(dayEntries[i]),
                                  ),
                                ),
                              );
                            }, childCount: dayEntries.length),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }
}

/// Hero collapsing app bar: month/year title, entry/favorite stat pills,
/// and the collapsed-state favorites shortcut. Isolated so it only
/// rebuilds when `entries` or `focusedDay` change — not on every day
/// selection.
class _TimelineHeroAppBar extends StatelessWidget {
  const _TimelineHeroAppBar({
    required this.entries,
    required this.focusedDay,
    required this.bgImagePath,
    required this.onFavoritesTap,
  });

  final List<DiaryEntry> entries;
  final DateTime focusedDay;
  final String? bgImagePath;
  final VoidCallback onFavoritesTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favCount = entries.where((e) => e.isFavorite).length;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      collapsedHeight: 60,
      stretch: true,
      surfaceTintColor: const Color.fromRGBO(0, 0, 0, 0),
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconPill(
            onTap: onFavoritesTap,
            color: Colors.redAccent,
            icon: Icons.favorite,
            label: '$favCount',
            textColor: Colors.white,
          ),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final expandRatio = ((constraints.maxHeight - 60) / (200 - 60)).clamp(
            0.0,
            1.0,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              if (bgImagePath != null)
                Opacity(
                  opacity: expandRatio,
                  child: BackgroundHeaderImage(path: bgImagePath!),
                ),
              if (bgImagePath != null)
                Opacity(
                  opacity: expandRatio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.22),
                          Colors.black.withValues(alpha: 0.31),
                        ],
                      ),
                    ),
                  ),
                ),

              // Expanded hero content
              Positioned(
                bottom: 0,
                left: 20,
                right: 20,
                child: Opacity(
                  opacity: bgImagePath != null ? expandRatio : 1.0,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20, top: 52),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppDateUtils.monthNameLong(focusedDay.month),
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    color: bgImagePath != null
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '${focusedDay.year}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color:
                                        (bgImagePath != null
                                                ? Colors.white
                                                : theme.colorScheme.onSurface)
                                            .withValues(alpha: 0.55),
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatPill(
                                icon: Icons.book_outlined,
                                label: '${entries.length} entries',
                                color: bgImagePath != null
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                              ),
                              const SizedBox(height: 6),
                              StatPill(
                                icon: Icons.favorite,
                                label: '$favCount favorites',
                                color: Colors.redAccent.shade100,
                                iconColor: Colors.redAccent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The calendar card, isolated so its own state changes (focused/selected
/// day, entries) don't also force a rebuild of the hero header above.
class _TimelineCalendarCard extends StatelessWidget {
  const _TimelineCalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.entries,
    required this.markedDates,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.dayCellBuilder,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<DiaryEntry> entries;
  final Set<DateTime> markedDates;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final Widget Function({
    required BuildContext context,
    required DateTime day,
    required List<DiaryEntry> entries,
    required Set<DateTime> markedDates,
    required bool isToday,
    required bool isSelected,
  })
  dayCellBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: TableCalendar(
          availableGestures: AvailableGestures.horizontalSwipe,
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: focusedDay,
          selectedDayPredicate: (d) => isSameDay(selectedDay, d),
          onDaySelected: (sel, foc) => onDaySelected(sel),
          onPageChanged: onPageChanged,
          rowHeight: 52,
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            isTodayHighlighted: false,
            markersMaxCount: 0,
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: theme.textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
            leftChevronIcon: CalendarChevron(
              icon: Icons.chevron_left,
              color: theme.colorScheme.primary,
            ),
            rightChevronIcon: CalendarChevron(
              icon: Icons.chevron_right,
              color: theme.colorScheme.primary,
            ),
            headerPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: theme.textTheme.labelSmall!.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            weekendStyle: theme.textTheme.labelSmall!.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (ctx, day, _) => dayCellBuilder(
              context: ctx,
              day: day,
              entries: entries,
              markedDates: markedDates,
              isToday: isSameDay(day, DateTime.now()),
              isSelected: isSameDay(selectedDay, day),
            ),
            todayBuilder: (ctx, day, _) => dayCellBuilder(
              context: ctx,
              day: day,
              entries: entries,
              markedDates: markedDates,
              isToday: true,
              isSelected: isSameDay(selectedDay, day),
            ),
            selectedBuilder: (ctx, day, _) => dayCellBuilder(
              context: ctx,
              day: day,
              entries: entries,
              markedDates: markedDates,
              isToday: isSameDay(day, DateTime.now()),
              isSelected: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Static legend row — never depends on bloc state, so it's a const
/// widget built once.
class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          LegendItem(
            label: 'Has entry',
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.25),
                    theme.colorScheme.secondary.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          LegendItem(
            label: 'Favorite',
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.redAccent.withValues(alpha: 0.3),
                    Colors.pink.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          LegendItem(
            label: 'Selected',
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The date-tile + weekday/label header shown above the selected day's
/// entry list, plus the "N entries" pill.
class _SelectedDayHeader extends StatelessWidget {
  const _SelectedDayHeader({
    required this.selectedDay,
    required this.dayEntryCount,
  });

  final DateTime selectedDay;
  final int dayEntryCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = AppDateUtils.isToday(selectedDay);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isToday
                  ? LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isToday
                  ? null
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  AppDateUtils.monthAbbrUpper(selectedDay.month),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: isToday
                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                        : theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '${selectedDay.day}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isToday
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppDateUtils.weekdayNameShort(
                    selectedDay.weekday,
                  ).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                    letterSpacing: 1.2,
                    fontSize: 10,
                  ),
                ),
                Text(
                  isToday
                      ? 'Today'
                      : AppDateUtils.monthNameLong(selectedDay.month),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (dayEntryCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$dayEntryCount ${dayEntryCount == 1 ? 'entry' : 'entries'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
