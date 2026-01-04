import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final currentShop = ref.watch(currentShopProvider).valueOrNull;
    final isOwner = currentUser?.isOwner ?? false;

    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Text(
                    (currentUser?.name ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  currentUser?.name ?? 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentShop?.name ?? 'No Shop',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOwner ? 'Owner' : 'Staff',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/dashboard');
                  },
                ),
                _DrawerItem(
                  icon: Icons.point_of_sale,
                  title: 'Sales',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/sales');
                  },
                ),
                _DrawerItem(
                  icon: Icons.shopping_cart,
                  title: 'Expenses',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/expenses');
                  },
                ),
                _DrawerItem(
                  icon: Icons.credit_card,
                  title: 'Credit',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/credit');
                  },
                ),
                _DrawerItem(
                  icon: Icons.savings,
                  title: 'Deposits',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/deposits');
                  },
                ),
                _DrawerItem(
                  icon: Icons.assignment_return,
                  title: 'Returns',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/returns');
                  },
                ),
                
                // Owner-only items
                if (isOwner) ...[
                  const Divider(),
                  _DrawerItem(
                    icon: Icons.calendar_month,
                    title: 'Monthly Summary',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/monthly-summary');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/settings');
                    },
                  ),
                ],
                
                const Divider(),
                _DrawerItem(
                  icon: Icons.person,
                  title: 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                _DrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(authRepositoryProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      onTap: onTap,
    );
  }
}
