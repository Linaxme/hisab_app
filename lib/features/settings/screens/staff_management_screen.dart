import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

/// Provider to fetch staff members for current shop
final staffListProvider = StreamProvider<List<UserModel>>((ref) {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return Stream.value([]);
  return ref.watch(userRepositoryProvider).watchStaffByShopId(shopId);
});

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টাফ ম্যানেজমেন্ট'),
      ),
      body: staffAsync.when(
        data: (staffList) {
          if (staffList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'কোনো স্টাফ নেই',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ইনভাইট কোড শেয়ার করুন স্টাফ যোগ করতে',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final staff = staffList[index];
              return _StaffCard(staff: staff);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          print('Staff loading error: $error');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('স্টাফ লোড করতে সমস্যা হয়েছে'),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StaffCard extends ConsumerWidget {
  final UserModel staff;

  const _StaffCard({required this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: staff.active 
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
              child: Text(
                staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: staff.active ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        staff.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: staff.active 
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          staff.active ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: staff.active ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    staff.email,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Toggle
            Switch(
              value: staff.active,
              activeColor: AppTheme.successColor,
              onChanged: (value) => _toggleStaffStatus(context, ref, staff, value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStaffStatus(
    BuildContext context,
    WidgetRef ref,
    UserModel staff,
    bool newStatus,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(newStatus ? 'স্টাফ একটিভ করুন?' : 'স্টাফ ইনঅ্যাক্টিভ করুন?'),
        content: Text(
          newStatus
              ? '${staff.name} আবার অ্যাপ ব্যবহার করতে পারবে।'
              : '${staff.name} আর অ্যাপ ব্যবহার করতে পারবে না।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppTheme.successColor : AppTheme.errorColor,
            ),
            child: Text(
              newStatus ? 'একটিভ করুন' : 'ইনঅ্যাক্টিভ করুন',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(userRepositoryProvider).updateUserStatus(staff.uid, newStatus, shopId: staff.shopId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus ? 'স্টাফ একটিভ করা হয়েছে' : 'স্টাফ ইনঅ্যাক্টিভ করা হয়েছে'),
              backgroundColor: newStatus ? AppTheme.successColor : AppTheme.errorColor,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('সমস্যা হয়েছে: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }
}
