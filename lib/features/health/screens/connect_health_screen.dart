import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/health_sync_controller.dart';
import '../../../core/theme/app_colors.dart';

class ConnectHealthScreen extends ConsumerWidget {
  const ConnectHealthScreen({super.key});

  static const _healthConnectPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';

  String get _platformName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  Future<void> _openHealthConnectInPlayStore(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(_healthConnectPlayStoreUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Play Store')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final syncState = ref.watch(healthSyncControllerProvider);
    final controller = ref.read(healthSyncControllerProvider.notifier);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Back button — same circular chip treatment used across
              // Delete Account / Signup / Forgot Password.
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_ios_new,
                      size: 16, color: colors.textPrimary),
                ),
              ),

              const SizedBox(height: 28),

              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite_rounded,
                    size: 30, color: colors.accent),
              ),
              const SizedBox(height: 20),

              Text(
                'Connect Health Data',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Optional — link $_platformName to bring your steps, active calories, heart rate, sleep, and weight into Eatsy alongside your food log.',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _DataItem('Steps'),
                    _DataItem('Active calories burned'),
                    _DataItem('Heart rate'),
                    _DataItem('Sleep duration'),
                    _DataItem('Weight'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildStatusSection(context, colors, syncState, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(
      BuildContext context,
      AppColors colors,
      HealthSyncState syncState,
      HealthSyncController controller,
      ) {
    switch (syncState.status) {
      case HealthConnectionStatus.unknown:
        return const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 24),
            child: CircularProgressIndicator(),
          ),
        );

      case HealthConnectionStatus.notAvailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Health Connect isn\'t installed or needs an update on this device. It\'s a separate app from Google — install or update it to continue.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _openHealthConnectInPlayStore(context),
              child: const Text('Open Health Connect in Play Store'),
            ),
          ],
        );

      case HealthConnectionStatus.notConnected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (syncState.errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  syncState.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: () => controller.connect(),
              child: Text('Connect $_platformName'),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see an OS permission prompt next. You can disconnect at any time from this screen.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case HealthConnectionStatus.connected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: colors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected to $_platformName',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          syncState.lastSyncedAt == null
                              ? 'Not synced yet'
                              : 'Last synced ${_formatRelativeTime(syncState.lastSyncedAt!)}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (syncState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Last sync failed: ${syncState.errorMessage}',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: syncState.isSyncing ? null : () => controller.sync(),
              child: syncState.isSyncing
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text('Sync Now'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => controller.disconnect(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Disconnect'),
            ),
            const SizedBox(height: 8),
            Text(
              'Disconnecting stops future syncing. Data already synced stays in your account unless you delete your account entirely.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }

  String _formatRelativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _DataItem extends StatelessWidget {
  final String text;
  const _DataItem(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: colors.accent),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(fontSize: 13, color: colors.textPrimary)),
        ],
      ),
    );
  }
}