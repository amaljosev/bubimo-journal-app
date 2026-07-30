import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  const UrlLauncherHelper._();

  static Future<void> launchUrlString(
    BuildContext context,
    String url,
    LaunchMode? launchMode 

  ) async {
    final uri = Uri.parse(url);

    final success = await launchUrl(
      uri,
      mode: launchMode?? LaunchMode.platformDefault,
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the link.'),
        ),
      );
    }
  }
}