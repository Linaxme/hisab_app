import 'package:flutter/material.dart';

/// The app icon (ledger under a tin roof), same artwork as the launcher icon.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/app_logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}
