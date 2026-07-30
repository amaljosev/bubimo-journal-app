// lib/features/onboarding/presentation/widgets/onboarding_pages_data.dart

import 'package:bubimo/features/onboarding/domain/entities/onboarding_page_data.dart';
import 'package:flutter/material.dart';


/// The 3 onboarding pages, grouping the app's 7 features by the
/// moment in a user's journey they matter most: writing an entry,
/// looking back at entries over time, and keeping entries safe.
/// Kept as a plain const list (not fetched from anywhere) since this
/// copy ships with the app rather than varying per user.
const List<OnboardingPageData> kOnboardingPages = [
  OnboardingPageData(
    title: 'Make it yours',
    description:
        'Write freely with a full rich text editor, then style every '
        'page with a theme that feels like you.',
    features: ['Rich text editor', 'Free customization', 'Custom themes'],
    icon: Icons.edit_note_rounded,
    accentIndex: 0, // Dusk violet
  ),
  OnboardingPageData(
    title: 'Watch your story unfold',
    description:
        'Every entry lines up on a timeline, with analytics that '
        'surface your patterns and a favorites shelf for the ones '
        'worth revisiting.',
    features: ['Timeline', 'Analytics', 'Favorite entries'],
    icon: Icons.timeline_rounded,
    accentIndex: 1, // Ocean blue
  ),
  OnboardingPageData(
    title: 'Kept safe, always yours',
    description:
        'An app lock keeps your entries private, and backup means '
        'they\'ll be there even if your phone isn\'t.',
    features: ['App lock', 'Backup & restore'],
    icon: Icons.shield_outlined,
    accentIndex: 2, // Meadow green
  ),
];