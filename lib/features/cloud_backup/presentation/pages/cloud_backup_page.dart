// lib/features/cloud_backup/presentation/pages/cloud_backup_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/cloud_backup_bloc.dart';

/// Screen for signing into Google, backing up the diary to Drive, and
/// restoring from the cloud backup. Reached from the drawer's
/// "Backup" item (`onBackupTap`) — the slot previously reserved and
/// left unwired specifically for this feature; see `app_drawer.dart`.
///
/// Deliberately separate from `BackupRestorePage` (the local `.bubimo`/
/// PDF screen) — cloud backup involves a Google account and network
/// access, which is a meaningfully different user decision from a
/// local file operation, even though both ultimately reuse the same
/// underlying archive format.
class CloudBackupPage extends StatelessWidget {
  const CloudBackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<CloudBackupBloc>()..add(const CloudBackupSilentSignInRequested()),
      child: const _CloudBackupView(),
    );
  }
}

class _CloudBackupView extends StatefulWidget {
  const _CloudBackupView();

  @override
  State<_CloudBackupView> createState() => _CloudBackupViewState();
}

class _CloudBackupViewState extends State<_CloudBackupView> {
  /// True once a restore has completed successfully during this visit
  /// to the screen. Reported back to whoever pushed this route (see
  /// `home_page.dart`'s `_openCloudBackup`) so Home knows to refresh
  /// its entry list — `MainShell` keeps `DiaryListBloc` alive for its
  /// whole lifetime (so tab switches stay instant), which also means
  /// nothing re-fetches automatically just because this screen was
  /// popped. Deliberately NOT auto-popped immediately after the
  /// restore-complete dialog closes — the user may still want to sign
  /// out or just look at the status card before leaving, so this is
  /// reported on whatever back action they actually take instead.
  bool _hasRestoredEntries = false;

  Future<void> _showResultDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore from Google Drive?'),
        content: const Text(
          'Entries from your cloud backup will be added as new diary '
          'entries, keeping their original dates. Nothing already in '
          'your diary will be changed or removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CloudBackupBloc>().add(const CloudBackupRestoreRequested());
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete cloud backup?'),
        content: const Text(
          'This removes your backup from Google Drive. Your diary on '
          'this device is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CloudBackupBloc>().add(const CloudBackupDeleteRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_hasRestoredEntries);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Cloud Backup')),
        body: BlocConsumer<CloudBackupBloc, CloudBackupState>(
          listenWhen: (previous, current) =>
              current.status == CloudBackupStatus.failure ||
              (current.status == CloudBackupStatus.success &&
                  current.message != null),
          listener: (context, state) {
            if (state.status == CloudBackupStatus.failure) {
              _showResultDialog(
                context,
                title: 'Something went wrong',
                message: state.message ?? 'Please try again.',
              );
              return;
            }

            // restoredCount is set once by a successful restore and
            // then persists on every later state (see
            // CloudBackupState.copyWith's `restoredCount ?? this
            // .restoredCount`) — so checking it's non-null here, with
            // no comparison to the previous state, is deliberate: it
            // can only ever be non-null if a restore has genuinely
            // completed at some point THIS visit, and re-setting an
            // already-true flag on a later, unrelated success (e.g. a
            // subsequent backup) is a harmless no-op, not a bug.
            if (state.restoredCount != null) {
              setState(() => _hasRestoredEntries = true);
            }

            if (state.message != null) {
              _showResultDialog(context, title: 'Done', message: state.message!);
            }
          },
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_outlined, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Keeps one backup of your whole diary in your own '
                          'Google Drive — only this app can read or write '
                          'it. Backing up again replaces the previous one; '
                          'this is not a version history.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!state.isSignedIn) ...[
                  FilledButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => context
                            .read<CloudBackupBloc>()
                            .add(const CloudBackupSignInRequested()),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign in with Google'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ] else ...[
                  if (state.signedInEmail != null) ...[
                    Text(
                      "You're already signed in as ${state.signedInEmail}",
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _StatusCard(state: state, colorScheme: colorScheme, textTheme: textTheme),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => context
                            .read<CloudBackupBloc>()
                            .add(const CloudBackupNowRequested()),
                    icon: state.isBusy && state.phase != null
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      state.isBusy && state.phase != null
                          ? state.phase!.label
                          : 'Back up now',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.isBusy || state.currentBackup == null
                        ? null
                        : () => _confirmRestore(context),
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Restore from Drive'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (state.currentBackup != null)
                    TextButton.icon(
                      onPressed:
                          state.isBusy ? null : () => _confirmDelete(context),
                      icon: Icon(Icons.delete_outline, color: colorScheme.error),
                      label: Text(
                        'Delete cloud backup',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: state.isBusy
                        ? null
                        : () => context
                            .read<CloudBackupBloc>()
                            .add(const CloudBackupSignOutRequested()),
                    child: const Text('Sign out'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final CloudBackupState state;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StatusCard({
    required this.state,
    required this.colorScheme,
    required this.textTheme,
  });

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final backup = state.currentBackup;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            backup != null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: backup != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup != null ? 'Cloud backup found' : 'No cloud backup yet',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (backup != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${backup.entryCount} ${backup.entryCount == 1 ? 'entry' : 'entries'} '
                    '· ${_formatDate(backup.createdAt)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}