// lib/features/settings/presentation/pages/settings_page.dart

import 'package:bubimo/core/constants/app_constants.dart';
import 'package:bubimo/core/router/app_router.dart';
import 'package:bubimo/core/utils/url_launcher_helper.dart';
import 'package:bubimo/features/contact_us/presentation/widgets/contact_us_sheet.dart';
import 'package:bubimo/features/settings/presentation/widgets/about_app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/settings_list_item.dart';

/// The Settings screen.
///
/// Originally an embedded tab body inside [MainShell]; now reached by
/// pushing from [ProfileAnalyticsScreen]'s gear icon, so it owns its own
/// [Scaffold]/[AppBar] (with a back button) rather than relying on
/// shell-provided chrome.
///
/// Only the "Reminder" and "App Lock" items are wired up. Every other
/// item is intentionally a static, no-op row until its feature is
/// built — flip `onTap` from `null` to a real callback as each one
/// comes online, no structural changes needed here.
///
/// The "Analytics" row that used to live under Insights has been
/// removed — Analytics is no longer a separate pushed destination, it's
/// now part of the combined Profile & Analytics tab (see
/// ProfileAnalyticsScreen / MainShell), reachable via the bottom nav
/// rather than from Settings.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SettingsSection(
              title: 'Data & Security',
              children: [
                SettingsListItem(
                  icon: Icons.lock_outline_rounded,
                  label: 'App Lock',
                  onTap: () => context.push(AppRoutes.appLockSettings),
                ),
                SettingsListItem(
                  icon: Icons.backup_outlined,
                  label: 'Backup & Restore',
                  onTap: () => context.push(AppRoutes.cloudBackup),
                ),
                SettingsListItem(
                  icon: Icons.ios_share_rounded,
                  label: 'Export Diary',
                  onTap: () => context.push(AppRoutes.importExport),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Preferences',
              children: [
                SettingsListItem(
                  icon: Icons.notifications_outlined,
                  label: 'Reminder',
                  onTap: () => context.push(AppRoutes.reminderSettings),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Support',
              children: [
                SettingsListItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help',
                  onTap: () => context.push(AppRoutes.help),
                ),
                SettingsListItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => UrlLauncherHelper.launchUrlString(
                    context,
                    AppConstants.privacyPolicyUrl,
                    LaunchMode.inAppWebView,
                  ),
                ),
                SettingsListItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About This App',
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AboutAppSheet(),
                  ),
                ),
                SettingsListItem(
                  icon: Icons.mail_outline_rounded,
                  label: 'Contact Us',
                  onTap: () => showContactUsSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Spread the Word',
              children: [
                SettingsListItem(
                  icon: Icons.share_outlined,
                  label: 'Share App',
                ),
                SettingsListItem(
                  icon: Icons.star_outline_rounded,
                  label: 'Rate App',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void showContactUsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContactUsSheet(),
    );
  }
}
