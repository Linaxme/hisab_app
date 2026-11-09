import 'package:flutter/material.dart';
import '../core/utils/responsive.dart';

/// Opens an entry form either as a centered popup or as a bottom sheet.
///
/// By default wide screens get a popup and phones get a bottom sheet;
/// pass [popup] to force one style (quick actions always use the popup).
Future<T?> showEntryForm<T>(
  BuildContext context,
  Widget form, {
  bool? popup,
}) {
  if (popup ?? context.isWide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _PopupScope(child: form),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => form,
  );
}

class _PopupScope extends InheritedWidget {
  const _PopupScope({required super.child});

  @override
  bool updateShouldNotify(_PopupScope oldWidget) => false;
}

/// Top of an entry form: a drag handle in a bottom sheet, a close button in a popup.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final inPopup =
        context.getElementForInheritedWidgetOfExactType<_PopupScope>() != null;

    if (inPopup) {
      return Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded),
        ),
      );
    }

    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
