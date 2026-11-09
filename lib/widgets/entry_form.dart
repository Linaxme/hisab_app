import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
/// Opens an entry form as a centred popup.
Future<T?> showEntryForm<T>(BuildContext context, Widget form) {
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        // The dialog already sits above the keyboard.
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: form,
        ),
      ),
    ),
  );
}

/// Top of a popup form: a close button.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.close_rounded),
      ),
    );
  }
}

/// One half of a "ক্যাশ থেকে / ক্যাশের বাইরে" choice in entry forms.
class PaymentTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const PaymentTypeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.errorGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppTheme.darkCard : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
