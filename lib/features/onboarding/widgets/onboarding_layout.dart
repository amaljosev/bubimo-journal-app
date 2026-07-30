// lib/features/onboarding/presentation/widgets/onboarding_layout.dart

/// Below this width, onboarding pages stack the illustration above
/// the text (phone portrait). At or above it, they sit side by side
/// (tablet, or phone landscape wide enough to fit both comfortably).
///
/// 600 matches Material's compact/medium breakpoint, so this lines up
/// with how the rest of the app already reasons about "is this a
/// tablet" elsewhere, rather than inventing a new cutoff just for
/// onboarding.
const double kOnboardingWideBreakpoint = 600;