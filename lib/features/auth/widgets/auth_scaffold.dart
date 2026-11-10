import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/strings.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../widgets/app_logo.dart';

/// Shared layout for login / register / shop setup screens.
///
/// Mobile: gradient header with the form in a rounded sheet below it.
/// Desktop: branded panel on the left, form card on the right.
class AuthScaffold extends ConsumerWidget {
  /// Header icon; null shows the app logo.
  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final List<Widget> children;

  const AuthScaffold({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    final formCard = _FormCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onBack: onBack,
      showHeader: isDesktop,
      children: children,
    );

    return Scaffold(
      backgroundColor: AppTheme.isDark(context)
          ? AppTheme.darkBackground
          : AppTheme.lightBackground,
      body: isDesktop
          ? Row(
              children: [
                Expanded(flex: 5, child: _BrandPanel(locale: locale)),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: formCard,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _MobileHeader(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    onBack: onBack,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -32),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ContentConstraint(maxWidth: 480, child: formCard),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  const _MobileHeader({
    this.icon,
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        children: [
          const Positioned(top: -40, right: -30, child: _Blob(size: 160)),
          const Positioned(bottom: 10, left: -50, child: _Blob(size: 120)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 64),
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: onBack == null
                          ? null
                          : IconButton(
                              onPressed: onBack,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.18),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  (icon == null
                          ? const AppLogo(size: 88)
                          : Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: AppTheme.softShadow(AppTheme.primaryColor, strength: 1.4),
                              ),
                              child: Icon(icon, size: 38, color: AppTheme.onPrimary),
                            ))
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final bool showHeader;
  final List<Widget> children;

  const _FormCard({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.showHeader,
    required this.children,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(context, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                if (onBack != null) ...[
                  IconButton.filledTonal(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
                if (icon == null)
                  const AppLogo(size: 52)
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.softShadow(AppTheme.primaryColor),
                    ),
                    child: Icon(icon, color: AppTheme.onPrimary),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                )),
            const SizedBox(height: 24),
          ],
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06);
  }
}

class _BrandPanel extends StatelessWidget {
  final Locale locale;

  const _BrandPanel({required this.locale});

  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.bolt_rounded, tr(locale, 'feature_live_cash')),
      (Icons.groups_rounded, tr(locale, 'feature_staff')),
      (Icons.cloud_off_rounded, tr(locale, 'feature_offline')),
      (Icons.insights_rounded, tr(locale, 'feature_reports')),
    ];

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
      child: Stack(
        children: [
          const Positioned(top: -80, right: -60, child: _Blob(size: 320)),
          const Positioned(bottom: -100, left: -80, child: _Blob(size: 360)),
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 52),
                    const SizedBox(width: 12),
                    const Text(
                      'আমার দোকান',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  tr(locale, 'app_tagline'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05),
                const SizedBox(height: 32),
                for (final (i, (icon, label)) in features.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (150 + 100 * i).ms).slideX(begin: -0.05),
                const Spacer(),
                Text(
                  '© ${DateTime.now().year} আমার দোকান',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;

  const _Blob({required this.size});

  @override
  Widget build(BuildContext context) =>
      AppTheme.glowBlob(size: size * 1.6, opacity: 0.26);
}

/// Error message box shown above auth forms.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    ).animate().shake();
  }
}

/// Tinted hint box shown under auth forms.
class AuthInfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const AuthInfoTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.isDark(context) ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width gradient call-to-action button with a loading state.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.7,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? AppTheme.softShadow(AppTheme.primaryColor) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onPrimary,
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 8),
                          Icon(icon, color: AppTheme.onPrimary, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
