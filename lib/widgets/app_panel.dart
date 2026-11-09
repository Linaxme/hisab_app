import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/responsive.dart';
import 'entry_form.dart';

/// Opens [panel] as a centred dialog on wide screens and a bottom sheet on phones.
Future<T?> showAppPanel<T>(BuildContext context, Widget panel, {double maxWidth = 560}) {
  if (context.isWide) {
    return showDialog<T>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: panel,
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => panel,
  );
}

/// Shared chrome for [showAppPanel] content: handle, title, subtitle.
class AppPanelFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const AppPanelFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: wide ? null : const BorderRadius.vertical(top: Radius.circular(28)),
        border: wide
            ? null
            : Border(top: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.35))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 2),
                        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 18),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
