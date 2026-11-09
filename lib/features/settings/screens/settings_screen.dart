import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/strings.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/dashboard_preferences_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import 'staff_management_screen.dart';
import 'category_management_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentShop = ref.watch(currentShopProvider);
    final locale = ref.watch(languageProvider);
    final t = (String key, {Map<String, String> params = const {}}) => tr(locale, key, params: params);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('settings_title')),
      ),
      body: currentShop.when(
        data: (shop) {
          if (shop == null) {
            return const Center(child: Text('Shop not found'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Shop Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shop Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _SettingRow(
                        icon: Icons.store,
                        title: 'Shop Name',
                        subtitle: shop.name,
                      ),
                      const Divider(height: 24),
                      _SettingRow(
                        icon: Icons.key,
                        title: 'Invite Code',
                        subtitle: shop.inviteCode,
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Regenerate Invite Code'),
                                content: const Text(
                                  'This will create a new invite code. Staff with the old code won\'t be able to join.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Regenerate'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              try {
                                await ref.read(shopRepositoryProvider).regenerateInviteCode(shop.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invite code regenerated')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to regenerate invite code: $e')),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Display Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Settings',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show Profit'),
                        subtitle: const Text('Display profit information in the app'),
                        value: shop.showProfit,
                        onChanged: (value) async {
                          await ref.read(shopRepositoryProvider).updateShopSettings(
                                shop.id,
                                showProfit: value,
                              );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Language Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('language'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('language_desc'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: locale.languageCode,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'bn',
                            child: Text(t('bangla_label')),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(t('english_label')),
                          ),
                        ],
                        onChanged: (code) {
                          if (code != null) {
                            ref.read(languageProvider.notifier).setLanguage(code);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Dashboard Card Management
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ড্যাশবোর্ড কার্ড ম্যানেজমেন্ট',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ড্যাশবোর্ডে কোন কার্ডগুলো দেখাতে চান তা নির্বাচন করুন',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 16),
                      _DashboardCardSettings(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Staff Management
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.people, color: AppTheme.primaryColor),
                  ),
                  title: const Text('Staff Management'),
                  subtitle: const Text('Manage your staff members'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StaffManagementScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Category Management
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.category, color: AppTheme.primaryColor),
                  ),
                  title: const Text('Expense Categories'),
                  subtitle: const Text('Manage expense categories'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // App Info
              Center(
                child: Column(
                  children: [
                    Text(
                      'আমার দোকান',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const SkeletonLoader(),
        error: (_, __) => const Center(child: Text('Error loading settings')),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _DashboardCardSettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(dashboardPreferencesProvider);

    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.account_balance_wallet_rounded),
          title: const Text('ওপেনিং ক্যাশ'),
          value: prefs.showOpeningCash,
          onChanged: (value) {
            ref.read(dashboardPreferencesProvider.notifier).setOpeningCashVisibility(value);
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.trending_up_rounded),
          title: const Text('আজকের বিক্রয়'),
          value: prefs.showTodaySales,
          onChanged: (value) {
            ref.read(dashboardPreferencesProvider.notifier).setTodaySalesVisibility(value);
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.trending_down_rounded),
          title: const Text('আজকের খরচ'),
          value: prefs.showTodayExpenses,
          onChanged: (value) {
            ref.read(dashboardPreferencesProvider.notifier).setTodayExpensesVisibility(value);
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.savings_rounded),
          title: const Text('জমা'),
          value: prefs.showDeposits,
          onChanged: (value) {
            ref.read(dashboardPreferencesProvider.notifier).setDepositsVisibility(value);
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.assignment_return_rounded),
          title: const Text('ফেরত'),
          value: prefs.showReturns,
          onChanged: (value) {
            ref.read(dashboardPreferencesProvider.notifier).setReturnsVisibility(value);
          },
        ),
      ],
    );
  }
}
