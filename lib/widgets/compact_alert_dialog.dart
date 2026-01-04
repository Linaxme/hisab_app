import 'package:flutter/material.dart';

class CompactAlertDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsets? contentPadding;
  final EdgeInsets? actionsPadding;
  final double? titleFontSize;

  const CompactAlertDialog({
    super.key,
    required this.title,
    this.content,
    this.actions,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.actionsPadding = const EdgeInsets.fromLTRB(8, 0, 8, 12),
    this.titleFontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: titleFontSize,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      contentPadding: contentPadding,
      actionsPadding: actionsPadding,
      content: content,
      actions: actions ?? [],
    );
  }
}
