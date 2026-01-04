import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';

/// Provider to track Firestore sync status
final firestoreSyncStatusProvider = StreamProvider<bool>((ref) {
  return FirebaseFirestore.instance.snapshotsInSync().map((_) => true);
});

/// Compact sync indicator for app bar
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(firestoreSyncStatusProvider);
    
    return syncStatus.when(
      data: (_) => const _SyncedIcon(),
      loading: () => const _SyncingIcon(),
      error: (_, __) => const _OfflineIcon(),
    );
  }
}

class _SyncedIcon extends StatelessWidget {
  const _SyncedIcon();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'সিঙ্ক হয়েছে',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.cloud_done_rounded,
          size: 18,
          color: AppTheme.successColor,
        ),
      ),
    );
  }
}

class _SyncingIcon extends StatefulWidget {
  const _SyncingIcon();

  @override
  State<_SyncingIcon> createState() => _SyncingIconState();
}

class _SyncingIconState extends State<_SyncingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'সিঙ্ক হচ্ছে...',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: RotationTransition(
          turns: _controller,
          child: const Icon(
            Icons.sync_rounded,
            size: 18,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _OfflineIcon extends StatelessWidget {
  const _OfflineIcon();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'অফলাইন',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.cloud_off_rounded,
          size: 18,
          color: AppTheme.errorColor,
        ),
      ),
    );
  }
}

/// Banner style sync indicator for bottom of screen
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(firestoreSyncStatusProvider);
    
    return syncStatus.when(
      data: (_) => const SizedBox.shrink(),
      loading: () => _buildBanner(
        context,
        icon: Icons.sync_rounded,
        message: 'ডেটা সিঙ্ক হচ্ছে...',
        color: AppTheme.primaryColor,
      ),
      error: (_, __) => _buildBanner(
        context,
        icon: Icons.cloud_off_rounded,
        message: 'অফলাইন মোড',
        color: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildBanner(
    BuildContext context, {
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full screen offline indicator
class OfflineOverlay extends StatelessWidget {
  const OfflineOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ইন্টারনেট সংযোগ নেই',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'আপনার ইন্টারনেট সংযোগ চেক করুন',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
