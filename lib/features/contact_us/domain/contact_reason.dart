// lib/features/contact_us/domain/contact_reason.dart

/// The reason a user is contacting support, driving both the tile
/// shown in [ContactUsSheet] and the email subject line sent.
enum ContactReason {
  feedback(
    title: 'Feedback',
    subtitle: 'Share your experience with us',
    emailSubject: 'bubimo - General Feedback',
  ),
  support(
    title: 'Support',
    subtitle: 'Need help? Contact support',
    emailSubject: 'bubimo - Support Request',
  ),
  bugReport(
    title: 'Bug Report',
    subtitle: 'Found a problem? Let us know',
    emailSubject: 'bubimo - Bug Report',
  ),
  featureSuggestion(
    title: 'Feature Suggestion',
    subtitle: 'Suggest a new feature',
    emailSubject: 'bubimo - Feature Suggestion',
  );

  final String title;
  final String subtitle;
  final String emailSubject;

  const ContactReason({
    required this.title,
    required this.subtitle,
    required this.emailSubject,
  });
}