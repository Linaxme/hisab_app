import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Colours for chart segments, in order of use.
const chartPalette = <Color>[
  AppTheme.primaryColor,
  AppTheme.goldColor,
  AppTheme.violetColor,
  AppTheme.infoColor,
  AppTheme.errorColor,
  AppTheme.accentColor,
  AppTheme.warningColor,
  Color(0xFF94A3B8),
];

/// Animated ring chart; [segments] are (value, colour) pairs.
class DonutChart extends StatelessWidget {
  final List<(double, Color)> segments;
  final double size;
  final double thickness;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.segments,
    this.size = 150,
    this.thickness = 18,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => CustomPaint(
          painter: _DonutPainter(segments, thickness, progress),
          child: child,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segments;
  final double thickness;
  final double progress;

  _DonutPainter(this.segments, this.thickness, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(thickness / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = Colors.white.withValues(alpha: 0.05);
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    final total = segments.fold<double>(0, (sum, s) => sum + s.$1);
    if (total <= 0) return;

    final gap = segments.length > 1 ? 0.035 : 0.0;
    var start = -math.pi / 2;
    for (final (value, color) in segments) {
      final sweep = value / total * math.pi * 2 * progress;
      if (sweep > gap) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..color = color,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.thickness != thickness || old.segments != segments;
}
