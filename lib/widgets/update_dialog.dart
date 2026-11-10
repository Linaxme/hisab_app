import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';

import '../core/localization/strings.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_theme.dart';
import '../core/update/app_updater.dart';

bool _promptShown = false;

/// Shows the update prompt at most once per app session.
void maybePromptUpdate(BuildContext context, AppUpdate update) {
  if (_promptShown) return;
  _promptShown = true;
  showUpdateDialog(context, update);
}

Future<void> showUpdateDialog(BuildContext context, AppUpdate update) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !update.required,
    builder: (_) => PopScope(
      canPop: !update.required,
      child: _UpdateDialog(update: update),
    ),
  );
}

/// Manual check from the More screen.
Future<void> checkForUpdateManually(BuildContext context, WidgetRef ref) async {
  final locale = ref.read(languageProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final update = await AppUpdater.check();
    if (!context.mounted) return;
    if (update == null) {
      messenger.showSnackBar(SnackBar(content: Text(tr(locale, 'update_up_to_date'))));
    } else {
      await showUpdateDialog(context, update);
    }
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(tr(locale, 'update_check_failed'))));
  }
}

class _UpdateDialog extends ConsumerStatefulWidget {
  final AppUpdate update;

  const _UpdateDialog({required this.update});

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  StreamSubscription<OtaEvent>? _subscription;
  OtaEvent? _event;

  bool get _downloading => _event?.status == OtaStatus.DOWNLOADING;

  bool get _failed => switch (_event?.status) {
        OtaStatus.ALREADY_RUNNING_ERROR ||
        OtaStatus.INSTALLATION_ERROR ||
        OtaStatus.PERMISSION_NOT_GRANTED_ERROR ||
        OtaStatus.INTERNAL_ERROR ||
        OtaStatus.DOWNLOAD_ERROR ||
        OtaStatus.CHECKSUM_ERROR ||
        OtaStatus.CANCELED =>
          true,
        _ => false,
      };

  void _start() {
    _subscription?.cancel();
    setState(() => _event = OtaEvent(OtaStatus.DOWNLOADING, '0'));
    // A fresh instance each time: OtaUpdate caches its first progress stream.
    _subscription = OtaUpdate()
        .execute(
          widget.update.url,
          destinationFilename: 'amar-dokan-${widget.update.version}.apk',
          sha256checksum: widget.update.sha256,
        )
        .listen(
          (event) => setState(() => _event = event),
          onError: (_) => setState(() => _event = OtaEvent(OtaStatus.INTERNAL_ERROR, null)),
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    String t(String key, [Map<String, String> params = const {}]) => tr(locale, key, params: params);
    final update = widget.update;
    final percent = int.tryParse(_event?.value ?? '') ?? 0;

    final String? status = switch (_event?.status) {
      null => null,
      OtaStatus.DOWNLOADING => t('update_downloading', {'percent': '$percent'}),
      OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE => t('update_installing'),
      OtaStatus.PERMISSION_NOT_GRANTED_ERROR => t('update_permission'),
      _ => t('update_failed'),
    };

    return AlertDialog(
      icon: const Icon(Icons.system_update_rounded, color: AppTheme.primaryColor, size: 32),
      title: Text(t('update_available')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  t('update_new_version', {'version': update.version}),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
                ),
              ),
              if (update.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(update.notes, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (update.required) ...[
                const SizedBox(height: 12),
                Text(t('update_required'), style: const TextStyle(color: AppTheme.warningColor)),
              ],
              if (status != null) ...[
                const SizedBox(height: 16),
                if (_downloading)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: percent / 100, minHeight: 6),
                  ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: TextStyle(color: _failed ? AppTheme.errorColor : AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!update.required && !_downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('update_later')),
          ),
        FilledButton(
          onPressed: _downloading ? null : _start,
          child: Text(_event == null ? t('update_now') : t('update_retry')),
        ),
      ],
    );
  }
}
