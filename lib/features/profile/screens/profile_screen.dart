import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/localization/strings.dart';
import '../../../widgets/modern_widgets.dart';
import '../../../widgets/skeleton_loader.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController();
  bool _isEditing = false;
  bool _isEditingShop = false;
  bool _isLoading = false;
  bool _isLoadingShop = false;

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _updateName() async {
    final locale = ref.read(languageProvider);
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final user = authRepository.currentUser;
      if (user != null) {
        await authRepository.updateUserName(user.uid, name);
        ref.invalidate(currentUserProvider);
      }
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(locale, 'name_updated'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                locale,
                'error_with_message',
                params: {'message': e.toString()},
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateShopName() async {
    final locale = ref.read(languageProvider);
    final name = _shopNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoadingShop = true;
    });

    try {
      final currentShop = ref.read(currentShopProvider).value;
      if (currentShop != null) {
        final shopRepo = ref.read(shopRepositoryProvider);
        await shopRepo.updateShopName(currentShop.id, name);
        ref.invalidate(currentShopProvider);
      }
      if (mounted) {
        setState(() {
          _isEditingShop = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(locale, 'shop_name_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                locale,
                'error_with_message',
                params: {'message': e.toString()},
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingShop = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('লগআউট'),
        content: const Text('আপনি কি নিশ্চিত লগআউট করতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.errorGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: const Text('লগআউট', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('পাসওয়ার্ড পরিবর্তন করুন'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current Password
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'বর্তমান পাসওয়ার্ড',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureCurrent = !obscureCurrent;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // New Password
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'নতুন পাসওয়ার্ড',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureNew = !obscureNew;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Confirm Password
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'পাসওয়ার্ড নিশ্চিত করুন',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বাতিল'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final currentPassword = currentPasswordController.text.trim();
                  final newPassword = newPasswordController.text.trim();
                  final confirmPassword = confirmPasswordController.text.trim();

                  // Validation
                  if (currentPassword.isEmpty ||
                      newPassword.isEmpty ||
                      confirmPassword.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('সব ফিল্ড পূরণ করুন')),
                    );
                    return;
                  }

                  if (newPassword.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'নতুন পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে',
                        ),
                      ),
                    );
                    return;
                  }

                  if (newPassword != confirmPassword) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('নতুন পাসওয়ার্ড মিলছে না')),
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .changePassword(
                          currentPassword: currentPassword,
                          newPassword: newPassword,
                        );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('পাসওয়ার্ড সফলভাবে পরিবর্তন হয়েছে'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      String errorMessage = 'ত্রুটি: $e';
                      if (e.toString().contains('wrong-password')) {
                        errorMessage = 'বর্তমান পাসওয়ার্ড ভুল';
                      } else if (e.toString().contains('weak-password')) {
                        errorMessage = 'পাসওয়ার্ড দুর্বল';
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(errorMessage)));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: const Text(
                  'পরিবর্তন করুন',
                  style: TextStyle(color: AppTheme.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentShop = ref.watch(currentShopProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          // Initialize controller with current name
          if (!_isEditing) {
            _nameController.text = user.name;
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  ScreenHeader(
                    title: 'প্রোফাইল',
                    onBack: context.isWide
                        ? null
                        : () => context.canPop()
                            ? context.pop()
                            : context.go('/more'),
                  ).animate().fadeIn().slideX(begin: -0.05),

                  const SizedBox(height: 32),

                  // Profile Avatar with gradient ring
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkBackground : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 16),

                  // User name
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 12),

                  // Role Badge
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: user.isOwner
                              ? AppTheme.purpleGradient
                              : AppTheme.tealGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.isOwner ? 'দোকান মালিক' : 'স্টাফ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .scale(begin: const Offset(0.9, 0.9)),

                  const SizedBox(height: 32),

                  // Profile Info Card
                  ModernCard(
                    child: Column(
                      children: [
                        // Name Field
                        _ProfileTile(
                          icon: Icons.person_rounded,
                          label: 'নাম',
                          value: user.name,
                          trailing: IconButton(
                            icon: Icon(
                              _isEditing
                                  ? Icons.close_rounded
                                  : Icons.edit_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _isEditing = !_isEditing;
                                if (!_isEditing) {
                                  _nameController.text = user.name;
                                }
                              });
                            },
                          ),
                          isEditing: _isEditing,
                          editWidget: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),

                        if (_isEditing) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _updateName,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.onPrimary,
                                        ),
                                      )
                                    : const Text(
                                        'সংরক্ষণ করুন',
                                        style: TextStyle(color: AppTheme.onPrimary),
                                      ),
                              ),
                            ),
                          ),
                        ],

                        const Divider(height: 32),

                        // Email
                        _ProfileTile(
                          icon: Icons.email_rounded,
                          label: 'ইমেইল',
                          value: user.email,
                        ),

                        const Divider(height: 32),

                        // Shop Name
                        currentShop.when(
                          data: (shop) {
                            final isOwner = user.isOwner;
                            // Initialize shop name controller
                            if (!_isEditingShop && shop != null) {
                              _shopNameController.text = shop.name;
                            }

                            return Column(
                              children: [
                                _ProfileTile(
                                  icon: Icons.store_rounded,
                                  label: 'দোকান',
                                  value: shop?.name ?? 'দোকান নেই',
                                  trailing: isOwner && shop != null
                                      ? IconButton(
                                          icon: Icon(
                                            _isEditingShop
                                                ? Icons.close_rounded
                                                : Icons.edit_rounded,
                                            color: AppTheme.primaryColor,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isEditingShop = !_isEditingShop;
                                              if (!_isEditingShop) {
                                                _shopNameController.text =
                                                    shop.name;
                                              }
                                            });
                                          },
                                        )
                                      : null,
                                  isEditing: _isEditingShop,
                                  editWidget: TextField(
                                    controller: _shopNameController,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      isDense: true,
                                    ),
                                  ),
                                ),

                                if (_isEditingShop) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoadingShop
                                            ? null
                                            : _updateShopName,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                        ),
                                        child: _isLoadingShop
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppTheme.onPrimary,
                                                    ),
                                              )
                                            : const Text(
                                                'সংরক্ষণ করুন',
                                                style: TextStyle(
                                                  color: AppTheme.onPrimary,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                          loading: () => const SkeletonCard(height: 50),
                          error: (_, __) => const Text('Error loading shop'),
                        ),

                        const Divider(height: 32),

                        // Member Since
                        _ProfileTile(
                          icon: Icons.calendar_today_rounded,
                          label: 'সদস্য হয়েছেন',
                          value: DateFormatter.formatDisplay(user.createdAt),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                  const SizedBox(height: 24),

                  // Change Password Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _showChangePasswordDialog,
                        icon: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppTheme.onPrimary,
                        ),
                        label: const Text(
                          'পাসওয়ার্ড পরিবর্তন করুন',
                          style: TextStyle(
                            color: AppTheme.onPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.15),

                  const SizedBox(height: 16),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppTheme.errorColor,
                      ),
                      label: const Text(
                        'লগআউট',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppTheme.errorColor,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading profile')),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool isEditing;
  final Widget? editWidget;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.isEditing = false,
    this.editWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              isEditing && editWidget != null
                  ? editWidget!
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

extension LinearGradientScale on LinearGradient {
  LinearGradient scale(double factor) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors.map((c) => Color.lerp(Colors.white, c, factor)!).toList(),
    );
  }
}
