import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/strings.dart';
import '../../../core/update/app_updater.dart';
import '../../../widgets/app_actions.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/modern_widgets.dart';
import '../../../widgets/update_dialog.dart';

/// More Screen - Settings, Profile, etc.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final currentShop = ref.watch(currentShopProvider).valueOrNull;
    final isOwner = currentUser?.isOwner ?? false;
    final locale = ref.watch(languageProvider);
    String t(String key) => tr(locale, key);
    final version = ref.watch(appVersionProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ScreenHeader(title: t('more_title')),
            const SizedBox(height: 16),

            // Profile card
            _ProfileCard(
              name: currentUser?.name ?? 'User',
              shopName: currentShop?.name ?? t('no_shop'),
              roleLabel: isOwner ? t('owner') : t('staff'),
              onTap: () => context.push('/profile'),
            ).animate().fadeIn().slideY(begin: 0.05),

            const SizedBox(height: 24),
            SectionHeader(title: t('nav_records')),
            const SizedBox(height: 10),
            _MenuGroup(
              children: [
                _MenuItem(
                  icon: Icons.handshake_rounded,
                  color: AppTheme.warningColor,
                  title: t('nav_credit'),
                  subtitle: t('menu_credit_sub'),
                  onTap: () => context.push('/credit'),
                ),
                _MenuItem(
                  icon: Icons.savings_rounded,
                  color: AppTheme.accentColor,
                  title: t('nav_deposits'),
                  subtitle: t('menu_deposits_sub'),
                  onTap: () => context.push('/deposits'),
                ),
                _MenuItem(
                  icon: Icons.assignment_return_rounded,
                  color: AppTheme.violetColor,
                  title: t('nav_returns'),
                  subtitle: t('menu_returns_sub'),
                  onTap: () => context.push('/returns'),
                ),
              ],
            ).animate().fadeIn(delay: 80.ms),

            if (isOwner) ...[
              const SizedBox(height: 20),
              SectionHeader(title: t('nav_owner')),
              const SizedBox(height: 10),
              _MenuGroup(
                children: [
                  _MenuItem(
                    icon: Icons.calendar_month_rounded,
                    color: AppTheme.primaryColor,
                    title: t('nav_monthly'),
                    subtitle: t('menu_monthly_sub'),
                    onTap: () => context.push('/monthly-summary'),
                  ),
                  _MenuItem(
                    icon: Icons.inventory_2_rounded,
                    color: AppTheme.warningColor,
                    title: t('nav_products'),
                    subtitle: t('menu_products_sub'),
                    onTap: () => context.push('/products-settings'),
                  ),
                  _MenuItem(
                    icon: Icons.settings_rounded,
                    color: AppTheme.infoColor,
                    title: t('nav_settings'),
                    subtitle: t('menu_settings_sub'),
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ).animate().fadeIn(delay: 140.ms),
            ],

            const SizedBox(height: 20),
            SectionHeader(title: t('nav_appearance')),
            const SizedBox(height: 10),
            _MenuGroup(
              children: [
                _MenuRow(
                  icon: Icons.translate_rounded,
                  color: AppTheme.accentColor,
                  title: t('language'),
                  subtitle: locale.languageCode == 'bn' ? 'বাংলা' : 'English',
                  trailing: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: 'bn', label: Text('বাং')),
                      ButtonSegment(value: 'en', label: Text('EN')),
                    ],
                    selected: {locale.languageCode},
                    onSelectionChanged: (value) => ref
                        .read(languageProvider.notifier)
                        .setLanguage(value.first),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 20),
            _MenuGroup(
              children: [
                _MenuItem(
                  icon: Icons.privacy_tip_rounded,
                  color: AppTheme.infoColor,
                  title: 'গোপনীয়তা নীতি',
                  subtitle: 'কী তথ্য রাখা হয় ও কীভাবে মুছবেন',
                  onTap: () => context.push('/privacy'),
                ),
                if (AppUpdater.isAndroid)
                  _MenuItem(
                    icon: Icons.system_update_rounded,
                    color: AppTheme.primaryColor,
                    title: t('update_check'),
                    subtitle: version == null ? null : tr(locale, 'app_version', params: {'version': version}),
                    onTap: () => checkForUpdateManually(context, ref),
                  ),
                _MenuItem(
                  icon: Icons.logout_rounded,
                  color: AppTheme.errorColor,
                  title: t('logout'),
                  titleColor: AppTheme.errorColor,
                  showChevron: false,
                  onTap: () => confirmAndLogout(context, ref),
                ),
              ],
            ).animate().fadeIn(delay: 260.ms),

            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  const AppLogo(size: 48),
                  const SizedBox(height: 8),
                  Text(
                    t('app_tagline'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    version == null ? '' : 'Version $version',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String shopName;
  final String roleLabel;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.shopName,
    required this.roleLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.22)),
        boxShadow: AppTheme.softShadow(AppTheme.primaryColor, strength: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -70,
                child: AppTheme.glowBlob(size: 200),
              ),
              Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.softShadow(AppTheme.primaryColor),
                  ),
                  child: Text(
                    name.isEmpty ? 'U' : name[0].toUpperCase(),
                    style: AppTheme.numeric(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.goldColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      color: AppTheme.goldColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card that stacks menu rows with dividers between them
class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context, radius: 20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 64),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: _MenuRow(
          icon: icon,
          color: color,
          title: title,
          subtitle: subtitle,
          titleColor: titleColor,
          trailing: showChevron
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                )
              : null,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;

  const _MenuRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 38, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
