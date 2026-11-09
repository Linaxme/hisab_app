import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

const keypadBackspace = '⌫';
const _maxDigits = 9;

/// Applies one keypad press to a digit string ("" means zero).
String applyKeypadKey(String current, String key) {
  if (key == keypadBackspace) {
    return current.isEmpty ? current : current.substring(0, current.length - 1);
  }
  final next = current + key;
  final trimmed = next.replaceFirst(RegExp(r'^0+'), '');
  return trimmed.length > _maxDigits ? current : trimmed;
}

/// Maps a physical key press to a keypad key, or null when it is not one.
String? keypadKeyFor(KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.backspace) return keypadBackspace;
  final char = event.character;
  if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) return char;
  return null;
}

/// Big calculator-style number pad used by the quick entry forms.
class AmountKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback? onClear;

  const AmountKeypad({super.key, required this.onKey, this.onClear});

  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', keypadBackspace];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: [
        for (final key in _keys)
          _KeypadButton(
            label: key,
            onTap: () {
              HapticFeedback.selectionClick();
              onKey(key);
            },
            onLongPress: key == keypadBackspace ? onClear : null,
          ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _KeypadButton({required this.label, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isBack = label == keypadBackspace;
    return Material(
      color: isBack ? AppTheme.errorColor.withValues(alpha: 0.1) : AppTheme.darkCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        child: Center(
          child: isBack
              ? const Icon(Icons.backspace_outlined, color: AppTheme.errorColor, size: 22)
              : Text(label, style: AppTheme.numeric(fontSize: 22, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
