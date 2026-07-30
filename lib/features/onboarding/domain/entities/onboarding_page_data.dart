// lib/features/onboarding/domain/entities/onboarding_page_data.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show IconData;

/// Content for a single onboarding page: what it says and which
/// accent from [AppColors] it's built around.
///
/// Framework-light on purpose (no [Color], no widgets) so this stays
/// easy to unit test and easy to reorder/extend without touching any
/// presentation code — [OnboardingPage] (presentation) is the only
/// place that turns [accentIndex] into an actual [RgbaColor] via
/// `AppColors.primaryLight[accentIndex]` /
/// `AppColors.onboardingGradientForPrimary`.
class OnboardingPageData extends Equatable {
  /// Short headline, e.g. "Capture every day".
  final String title;

  /// One or two sentences expanding on [title].
  final String description;

  /// The features this page represents (shown as small chips/tags),
  /// e.g. `['Timeline', 'Rich text editor', 'Custom themes']`.
  final List<String> features;

  /// Icon used in the page's hero illustration.
  final IconData icon;

  /// Index into `AppColors.primaryLight` / `AppColors.primaryDark`
  /// (and the index-matched `onboardingGradientLight/Dark`) — the
  /// single source of truth for this page's accent color, so the
  /// same index picks both the icon/CTA color and its background
  /// gradient tint.
  final int accentIndex;

  const OnboardingPageData({
    required this.title,
    required this.description,
    required this.features,
    required this.icon,
    required this.accentIndex,
  });

  @override
  List<Object?> get props => [title, description, features, icon, accentIndex];
}