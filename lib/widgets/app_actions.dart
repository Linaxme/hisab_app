import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/strings.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_theme.dart';

/// Asks for confirmation, then signs the user out.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final locale = ref.read(languageProvider);
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
      title: Text(tr(locale, 'logout')),
      content: Text(tr(locale, 'logout_confirm')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr(locale, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: Text(tr(locale, 'logout')),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await ref.read(authRepositoryProvider).signOut();
  }
}
