// lib/features/theme/presentation/pages/custom_theme_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/built_in_themes.dart';
import '../../domain/entities/app_theme_data.dart';
import '../bloc/custom_theme_form/custom_theme_form_bloc.dart';
import '../widgets/custom_theme_form/color_field_tile.dart';
import '../widgets/custom_theme_form/font_picker_sheet.dart';
import '../widgets/custom_theme_form/header_image_picker_field.dart';
import '../widgets/custom_theme_form/home_preview_card.dart';
import '../widgets/custom_theme_form/text_color_swatch_picker_sheet.dart';
import '../widgets/custom_theme_form/theme_name_field.dart';

class CustomThemeScreen extends StatelessWidget {
  final AppThemeData? existingTheme;

  const CustomThemeScreen({super.key, this.existingTheme});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getIt<CustomThemeFormBloc>();
        final theme = existingTheme;
        if (theme != null) {
          bloc.add(CustomThemeFormInitializedForEdit(theme));
        } else {
          bloc.add(CustomThemeFormInitialized(BuiltInThemes.defaultTheme));
        }
        return bloc;
      },
      child: _CustomThemeScreenView(isEditing: existingTheme != null),
    );
  }
}

class _CustomThemeScreenView extends StatefulWidget {
  final bool isEditing;

  const _CustomThemeScreenView({required this.isEditing});

  @override
  State<_CustomThemeScreenView> createState() =>
      _CustomThemeScreenViewState();
}

class _CustomThemeScreenViewState extends State<_CustomThemeScreenView> {
  late final TextEditingController _nameController;
  final ScrollController _scrollController = ScrollController();
  bool _initializedController = false;

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPreview() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openFontPicker(BuildContext context, String current) async {
    final picked = await FontPickerSheet.show(context, selectedFont: current);
    if (picked != null && context.mounted) {
      context.read<CustomThemeFormBloc>().add(CustomThemeFontChanged(picked));
    }
  }

  /// Opens the curated, contrast-filtered swatch picker for the Text
  /// color field — routed via [ColorFieldTile.onTap] rather than the
  /// default freeform [RgbaColorPickerSheet], since text color is
  /// constrained to pre-vetted options that already pass contrast
  /// against the current Background/Surface colors (see
  /// `TextColorSwatchPickerSheet`).
  Future<void> _openTextColorPicker(
    BuildContext context,
    CustomThemeFormState state,
  ) async {
    final picked = await TextColorSwatchPickerSheet.show(
      context,
      initialColor: state.textColor,
      backgroundColor: state.backgroundColor,
      surfaceColor: state.surfaceColor,
      isDark: state.isDark,
    );
    if (picked != null && context.mounted) {
      context
          .read<CustomThemeFormBloc>()
          .add(CustomThemeTextColorChanged(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomThemeFormBloc, CustomThemeFormState>(
      listener: (context, state) {
        if (!_initializedController &&
            state.status != CustomThemeFormStatus.initial) {
          _nameController = TextEditingController(text: state.name);
          _initializedController = true;
        }

        if (state.status == CustomThemeFormStatus.success) {
          context.pop(true);
        }
        if (state.status == CustomThemeFormStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        if (!_initializedController) {
          // First build before the initializing event has been
          // processed — render a lightweight loading state rather than
          // constructing the controller with stale/default text.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.isEditing ? 'Edit Theme' : 'Create Custom Theme'),
            actions: [
              IconButton(
                tooltip: 'Scroll to preview',
                icon: const Icon(Icons.arrow_upward),
                onPressed: _scrollToPreview,
              ),
            ],
          ),
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              HomePreviewCard(
                primaryColor: state.primaryColor,
                secondaryColor: state.secondaryColor,
                surfaceColor: state.surfaceColor,
                backgroundColor: state.backgroundColor,
                textColor: state.textColor,
                isDark: state.isDark,
                fontFamily: state.fontFamily,
                headerImagePath: state.headerImagePath,
              ),
              const SizedBox(height: 24),
              
              _DarkModeSwitcher(
                isDark: state.isDark,
                onChanged: (value) => context
                    .read<CustomThemeFormBloc>()
                    .add(CustomThemeDarkModeToggled(value)),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Font'),
                subtitle: Text(state.fontFamily),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFontPicker(context, state.fontFamily),
              ),
              const SizedBox(height: 20),
              HeaderImagePickerField(
                imagePath: state.headerImagePath,
                onImagePicked: (path) => context
                    .read<CustomThemeFormBloc>()
                    .add(CustomThemeHeaderImagePicked(path)),
                onImageRemoved: () => context
                    .read<CustomThemeFormBloc>()
                    .add(const CustomThemeHeaderImageCleared()),
              ),
              const SizedBox(height: 20),
              Text(
                'Colors',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap any color below to change it. The preview above '
                'updates instantly.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              ColorFieldTile(
                label: 'Primary',
                description:
                    'Buttons, the floating action button, and the active '
                    'tab indicator',
                color: state.primaryColor,
                presets: AppColors.forRole(
                  AppColorRole.primary,
                  isDark: state.isDark,
                ),
                onChanged: (color) => context
                    .read<CustomThemeFormBloc>()
                    .add(CustomThemePrimaryColorChanged(color)),
              ),
              const Divider(height: 1),
              ColorFieldTile(
                label: 'Secondary',
                description:
                    'Accent highlights, like the colored bar on diary entries',
                color: state.secondaryColor,
                presets: AppColors.forRole(
                  AppColorRole.secondary,
                  isDark: state.isDark,
                ),
                onChanged: (color) => context
                    .read<CustomThemeFormBloc>()
                    .add(CustomThemeSecondaryColorChanged(color)),
              ),
              const Divider(height: 1),
              ColorFieldTile(
                label: 'Surface',
                description: 'Cards, sheets, and app bars',
                color: state.surfaceColor,
                presets: AppColors.forRole(
                  AppColorRole.surface,
                  isDark: state.isDark,
                ),
                onChanged: (color) => context
                    .read<CustomThemeFormBloc>()
                    .add(CustomThemeSurfaceColorChanged(color)),
              ),
              const Divider(height: 1),
              ColorFieldTile(
                label: 'Background',
                description: 'The main page background behind everything',
                color: state.backgroundColor,
                presets: AppColors.forRole(
                  AppColorRole.background,
                  isDark: state.isDark,
                ),
                onChanged: (color) => context
                    .read<CustomThemeFormBloc>()
                    .add(CustomThemeBackgroundColorChanged(color)),
              ),
              const Divider(height: 1),
              ColorFieldTile(
                label: 'Text',
                description: 'Titles, body text, and icons',
                color: state.textColor,
                warning: state.textColorWarning,
                onTap: () => _openTextColorPicker(context, state),
              ),
              const SizedBox(height: 12),
              
              ThemeNameField(
                controller: _nameController,
                onChanged: (value) => context
                    .read<CustomThemeFormBloc>()
                    .add(CustomThemeNameChanged(value)),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: state.canSubmit
                    ? () => context
                        .read<CustomThemeFormBloc>()
                        .add(const CustomThemeFormSubmitted())
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isEditing ? 'Update Theme' : 'Save Theme'),
              ),
              if (!state.canSubmit && state.textColorWarning != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Fix the text color issue above before saving.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => context
                        .read<CustomThemeFormBloc>()
                        .add(const CustomThemeColorsReset()),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text(
                      state.isDark
                          ? 'Reset to default dark colors'
                          : 'Reset to default light colors',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Light/Dark Mode switcher. Toggling this changes
/// [CustomThemeFormState.isDark], which the live preview reflects
/// immediately and which re-evaluates the Text color's contrast
/// validation against the newly selected mode.
class _DarkModeSwitcher extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _DarkModeSwitcher({required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeOption(
              label: 'Light Mode',
              icon: Icons.light_mode_outlined,
              isSelected: !isDark,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ModeOption(
              label: 'Dark Mode',
              icon: Icons.dark_mode_outlined,
              isSelected: isDark,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}