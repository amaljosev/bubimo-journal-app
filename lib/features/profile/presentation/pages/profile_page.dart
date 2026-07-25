// lib/features/profile/presentation/pages/profile_analytics_screen.dart

import 'package:bubimo/core/router/app_router.dart';
import 'package:bubimo/features/shared/presentation/widgets/appbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/notched_nav_bar.dart'
    show kNavBarHeight;
import '../../../../core/widgets/error_screen.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../bloc/analytics_bloc.dart';
import '../bloc/analytics_event.dart';
import '../bloc/analytics_state.dart';
import '../widgets/analytics_widgets/heatmap_widget.dart';
import '../widgets/analytics_widgets/mood_count_chart.dart';
import '../widgets/analytics_widgets/stats_summary_card.dart';
import '../widgets/analytics_widgets/streak_display.dart';
import '../widgets/analytics_widgets/writing_consistency_chart.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/profile_header.dart';

class ProfileAnalyticsScreen extends StatelessWidget {
  const ProfileAnalyticsScreen({super.key});

  Future<void> _onEditProfile(
    BuildContext context,
    ProfileState profileState,
  ) async {
    final current = profileState.profile;
    if (current == null) return;

    final updated = await EditProfileSheet.show(context, current);
    if (updated != null && context.mounted) {
      context.read<ProfileCubit>().saveProfile(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: myAppbar(context, 'Profile',null),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, profileState) {
          return BlocBuilder<AnalyticsBloc, AnalyticsState>(
            builder: (context, analyticsState) {
              return _buildBody(context, profileState, analyticsState);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ProfileState profileState,
    AnalyticsState analyticsState,
  ) {
    // The profile card and the analytics cards load somewhat
    // independently (two separate blocs); only block the whole screen
    // on a spinner while BOTH are still on their very first load.
    final profileStillLoading =
        profileState.status == ProfileStatus.initial ||
        profileState.status == ProfileStatus.loading;
    final analyticsStillLoading =
        analyticsState.status == AnalyticsStatus.initial ||
        analyticsState.status == AnalyticsStatus.loading;

    if (profileStillLoading && analyticsStillLoading) {
      return const LoadingScreen();
    }

    if (analyticsState.status == AnalyticsStatus.failure) {
      return ErrorScreen(
        message: analyticsState.errorMessage ?? 'Something went wrong.',
        onRetry: () => context.read<AnalyticsBloc>().add(const LoadAnalytics()),
      );
    }

    return RefreshIndicator(
      // Pull-to-refresh is a deliberate, user-initiated reload — unlike
      // the initial load, this is fine to dispatch from here.
      onRefresh: () async {
        context.read<ProfileCubit>().loadProfile();
        context.read<AnalyticsBloc>().add(const LoadAnalytics());
      },
      child: ListView(
        // This screen is a MainShell tab, and MainShell mounts its
        // Scaffold with extendBody: true so NotchedNavBar can float
        // over tab content with its notch/FAB — but that also means
        // this content otherwise renders FULL-HEIGHT behind the bar
        // with no automatic inset, unlike a normal Scaffold with a
        // bottomNavigationBar. A flat 24px bottom padding left the
        // last card (the mood chart) and its "Less/More" legend
        // partially hidden under the bar. kNavBarHeight (the bar's
        // own flat-surface height, not counting the FAB's protrusion
        // above it — the FAB only overlaps a narrow centered strip, not
        // full-width scroll content) plus a small breathing-room
        // margin plus the device's own safe-area inset (NotchedNavBar
        // applies SafeArea only to ITS OWN content, not to whatever
        // scrolls behind it) together guarantee the last item always
        // fully clears the bar.
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + kNavBarHeight + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (profileState.profile != null)
            ProfileHeader(
              profile: profileState.profile!,
              onEdit: () => _onEditProfile(context, profileState),
            ),
          if (analyticsState.status == AnalyticsStatus.loaded) ...[
            StreakDisplay(
              currentStreak: analyticsState.currentStreak,
              longestStreak: analyticsState.longestStreak,
            ),
            const SizedBox(height: 12),
            StatsSummaryCard(stats: analyticsState.entryStats),
            const SizedBox(height: 12),
            HeatmapWidget(heatmapData: analyticsState.heatmapData),

            const SizedBox(height: 12),
            MoodCountChart(moodCounts: analyticsState.moodCounts),
            const SizedBox(height: 12),
            WritingConsistencyChart(
              wordCountTrend: analyticsState.wordCountTrend,
            ),
          ],
        ],
      ),
    );
  }
}
