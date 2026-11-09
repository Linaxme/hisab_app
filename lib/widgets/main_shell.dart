import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/strings.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/responsive.dart';
import '../features/entry/new_entry_sheet.dart';
import 'app_actions.dart';

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  final String route;

  const _NavItem(this.icon, this.selectedIcon, this.labelKey, this.route);
}

class _NavGroup {
  final String labelKey;
  final List<_NavItem> items;

  const _NavGroup(this.labelKey, this.items);
}

const _home = _NavItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'nav_home', '/dashboard');
const _sales = _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'nav_sales', '/sales');
const _expenses = _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'nav_expenses', '/expenses');
const _credit = _NavItem(Icons.credit_card_outlined, Icons.credit_card_rounded, 'nav_credit', '/credit');
const _more = _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'nav_more', '/more');
const _deposits = _NavItem(Icons.savings_outlined, Icons.savings_rounded, 'nav_deposits', '/deposits');
const _returns = _NavItem(Icons.assignment_return_outlined, Icons.assignment_return_rounded, 'nav_returns', '/returns');
const _monthly = _NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'nav_monthly', '/monthly-summary');
const _products = _NavItem(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'nav_products', '/products-settings');
const _settings = _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'nav_settings', '/settings');

// The centre slot between these is the + (new entry) button.
const _mobileTabs = [_home, _sales, _expenses, _more];

List<_NavGroup> _sidebarGroups(bool isOwner) => [
      const _NavGroup('nav_main', [_home, _sales, _expenses, _credit]),
      const _NavGroup('nav_records', [_deposits, _returns]),
      if (isOwner) const _NavGroup('nav_owner', [_monthly, _products, _settings]),
    ];

bool _isActive(String location, _NavItem item) =>
    location == item.route || location.startsWith('${item.route}/');

/// App frame: bottom navigation on phones, collapsible sidebar on tablets
/// and a full sidebar on desktop browsers.
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(inviteCodeSyncProvider);
    final router = GoRouter.of(context);

    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        // `last` (not `uri`) so pages opened with context.push are detected too.
        final config = router.routerDelegate.currentConfiguration;
        final location = config.lastOrNull?.matchedLocation ?? config.uri.path;

        switch (context.screenSize) {
          case ScreenSize.mobile:
            return _MobileFrame(location: location, child: child);
          case ScreenSize.tablet:
            return _WideFrame(location: location, extended: false, child: child);
          case ScreenSize.desktop:
            return _WideFrame(location: location, extended: true, child: child);
        }
      },
    );
  }
}

class _MobileFrame extends ConsumerWidget {
  final String location;
  final Widget child;

  const _MobileFrame({required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final tabIndex = _mobileTabs.indexWhere((item) => _isActive(location, item));
    // Sub-pages (deposits, settings, ...) are reached from the More tab.
    final index = tabIndex == -1 ? _mobileTabs.length - 1 : tabIndex;

    Widget tab(int i) {
      final item = _mobileTabs[i];
      return Expanded(
        child: _BottomTab(
          icon: i == index ? item.selectedIcon : item.icon,
          label: tr(locale, item.labelKey),
          selected: i == index,
          onTap: () => context.go(item.route),
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkSurface.withValues(alpha: 0.97),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                tab(0),
                tab(1),
                Expanded(
                  child: Center(
                    child: _PlusButton(
                      tooltip: tr(locale, 'new_entry'),
                      onTap: () => showNewEntrySheet(context),
                    ),
                  ),
                ),
                tab(2),
                tab(3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryColor : AppTheme.darkTextSecondary;
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: selected ? 18 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: selected ? AppTheme.softShadow(AppTheme.primaryColor, strength: 2) : null,
            ),
          ),
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _PlusButton({required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.darkBackground, width: 4),
              boxShadow: AppTheme.softShadow(AppTheme.primaryColor, strength: 1.6),
            ),
            child: const Icon(Icons.add_rounded, size: 30, color: AppTheme.onPrimary),
          ),
        ),
      ),
    );
  }
}

class _WideFrame extends StatelessWidget {
  final String location;
  final bool extended;
  final Widget child;

  const _WideFrame({
    required this.location,
    required this.extended,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(location: location, extended: extended),
          Expanded(
            child: ContentConstraint(
              // List screens read better in a narrower column than the dashboard.
              maxWidth: location == '/dashboard' ? Breakpoints.contentMaxWidth : 960,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final String location;
  final bool extended;

  const _Sidebar({required this.location, required this.extended});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final shop = ref.watch(currentShopProvider).valueOrNull;
    final isOwner = user?.isOwner ?? false;
    final isDark = AppTheme.isDark(context);
    String t(String key) => tr(locale, key);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: extended ? 268 : 84,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          right: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand
            Padding(
              padding: EdgeInsets.fromLTRB(extended ? 20 : 18, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.softShadow(AppTheme.primaryColor),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppTheme.onPrimary),
                  ),
                  if (extended) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'দোকান হিসাব',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            shop?.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(extended ? 16 : 14, 4, extended ? 16 : 14, 4),
              child: _NewEntryButton(
                label: t('new_entry'),
                extended: extended,
                onTap: () => showNewEntrySheet(context),
              ),
            ),

            // Navigation
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 10, vertical: 8),
                children: [
                  for (final group in _sidebarGroups(isOwner)) ...[
                    if (extended)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                        child: Text(
                          t(group.labelKey).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Divider(height: 1),
                      ),
                    for (final item in group.items)
                      _SidebarTile(
                        icon: _isActive(location, item) ? item.selectedIcon : item.icon,
                        label: t(item.labelKey),
                        selected: _isActive(location, item),
                        extended: extended,
                        onTap: () => context.go(item.route),
                      ),
                  ],
                ],
              ),
            ),

            // Preferences
            Padding(
              padding: EdgeInsets.symmetric(horizontal: extended ? 16 : 10),
              child: Flex(
                direction: extended ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: t('language'),
                    onPressed: () => ref.read(languageProvider.notifier).toggle(),
                    icon: Text(
                      locale.languageCode == 'bn' ? 'EN' : 'বাং',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: t('logout'),
                    onPressed: () => confirmAndLogout(context, ref),
                    color: AppTheme.errorColor,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
            ),

            // User card
            Padding(
              padding: EdgeInsets.fromLTRB(extended ? 12 : 10, 4, extended ? 12 : 10, 16),
              child: Material(
                color: location == '/profile'
                    ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.1)
                    : (isDark ? AppTheme.darkCard : AppTheme.lightBackground),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.go('/profile'),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'U',
                            style: const TextStyle(color: AppTheme.onPrimary, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (extended) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  isOwner ? t('owner') : t('staff'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                        ],
                      ],
                    ),
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

class _NewEntryButton extends StatelessWidget {
  final String label;
  final bool extended;
  final VoidCallback onTap;

  const _NewEntryButton({required this.label, required this.extended, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow(AppTheme.primaryColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: AppTheme.onPrimary, size: 24),
              if (extended) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return extended ? button : Tooltip(message: label, child: button);
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final fg = selected
        ? (isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
        : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary);

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0, vertical: 12),
            child: Row(
              mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 22),
                if (extended) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? fg : null,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return extended ? tile : Tooltip(message: label, child: tile);
  }
}
