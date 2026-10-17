// lib/features/plus/presentation/widgets/plus_settings_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/plus_bloc.dart';
import '../routing/plus_route_paths.dart';

/// The "Bubimo Plus" row at the top of Settings. Visually mirrors
/// `AdsToggleTile` / `SettingsListItem` (icon + label inside the same
/// rounded `SettingsSection` card). Opens the paywall, which doubles
/// as the "you're a member" screen for existing Plus users.
class PlusSettingsTile extends StatelessWidget {
  const PlusSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPlus = context.select<PlusBloc, bool>((b) => b.state.isPlus);

    return InkWell(
      onTap: () => context.push(PlusRoutePaths.paywall),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bubimo Plus',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPlus ? 'Active' : 'Unlock themes, backups and more',
                    style: textTheme.bodySmall?.copyWith(
                      color: isPlus
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
