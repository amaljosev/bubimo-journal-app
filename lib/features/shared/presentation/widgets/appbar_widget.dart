import 'package:bubimo/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

AppBar myAppbar(BuildContext context, String title, Widget? favorite) {
  return AppBar(
    title: Text(title),
    centerTitle: true,
    elevation: 0,
    actions: [(favorite ?? const _SettingsButton())],
  );
}

/// The settings [IconButton] used by [myAppbar], guarded against a
/// fast double-tap pushing [AppRoutes.settings] twice onto the stack.
///
/// [myAppbar] is a shared helper called from many screens, so this bug
/// was effectively present on every screen using it at once — pulling
/// the button into its own tiny [StatefulWidget] gives it a place to
/// hold the navigation lock, since the surrounding [myAppbar] function
/// itself is stateless and can't hold one.
class _SettingsButton extends StatefulWidget {
  const _SettingsButton();

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isNavigating = false;

  Future<void> _openSettings(BuildContext context) async {
    if (_isNavigating) return;
    _isNavigating = true;

    await context.push(AppRoutes.settings);

    if (context.mounted) {
      setState(() => _isNavigating = false);
    } else {
      _isNavigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _openSettings(context),
      icon: const Icon(Icons.settings),
    );
  }
}
