import 'package:flutter/material.dart';

/// Layout breakpoints shared by the whole app.
class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;

  /// Max width of page content on large screens.
  static const double contentMaxWidth = 1200;
}

enum ScreenSize { mobile, tablet, desktop }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  ScreenSize get screenSize {
    final width = screenWidth;
    if (width >= Breakpoints.desktop) return ScreenSize.desktop;
    if (width >= Breakpoints.tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;

  /// Tablet or desktop.
  bool get isWide => !isMobile;
}

/// Centers [child] and caps its width on large screens.
class ContentConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
