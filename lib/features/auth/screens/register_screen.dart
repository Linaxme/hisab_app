import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/strings.dart';
import '../widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String _selectedRole = AppConstants.roleOwner;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepository = ref.read(authRepositoryProvider);

      // Create Firebase Auth user
      final userCredential = await authRepository.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Create Firestore user document
      await authRepository.createUserDocument(
        uid: userCredential.user!.uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
      );

      // Navigation will be handled by router redirect
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return 'এই ইমেইল আগে থেকেই নিবন্ধিত।';
    } else if (error.contains('invalid-email')) {
      return 'ইমেইল ঠিক নয়।';
    } else if (error.contains('weak-password')) {
      return 'পাসওয়ার্ড দুর্বল।';
    }
    return 'রেজিস্ট্রেশন ব্যর্থ। আবার চেষ্টা করুন।';
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);

    return AuthScaffold(
      icon: Icons.person_add_alt_1_rounded,
      title: 'অ্যাকাউন্ট তৈরি করুন',
      subtitle: 'আপনার তথ্য দিয়ে শুরু করুন',
      onBack: () => context.go('/login'),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                AuthErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],

              // Role Selection
              Text(
                'আমি একজন:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      title: 'দোকান মালিক',
                      subtitle: 'সম্পূর্ণ অ্যাক্সেস',
                      icon: Icons.admin_panel_settings_rounded,
                      isSelected: _selectedRole == AppConstants.roleOwner,
                      onTap: () => setState(
                        () => _selectedRole = AppConstants.roleOwner,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleCard(
                      title: 'স্টাফ',
                      subtitle: 'সীমিত অ্যাক্সেস',
                      icon: Icons.badge_rounded,
                      isSelected: _selectedRole == AppConstants.roleStaff,
                      onTap: () => setState(
                        () => _selectedRole = AppConstants.roleStaff,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: tr(locale, 'name'),
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'নাম দিন';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.1),
              const SizedBox(height: 14),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: tr(locale, 'email'),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ইমেইল দিন';
                  }
                  if (!value.contains('@')) {
                    return 'সঠিক ইমেইল দিন';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 230.ms).slideY(begin: 0.1),
              const SizedBox(height: 14),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: tr(locale, 'password'),
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'পাসওয়ার্ড দিন';
                  }
                  if (value.length < 6) {
                    return 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1),
              const SizedBox(height: 14),

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
                decoration: InputDecoration(
                  labelText: tr(locale, 'confirm_password'),
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'পাসওয়ার্ড নিশ্চিত করুন';
                  }
                  if (value != _passwordController.text) {
                    return 'পাসওয়ার্ড মিলছে না';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 330.ms).slideY(begin: 0.1),
              const SizedBox(height: 24),

              GradientButton(
                label: tr(locale, 'register'),
                icon: Icons.arrow_forward_rounded,
                isLoading: _isLoading,
                onPressed: _register,
              ).animate().fadeIn(delay: 380.ms).slideY(begin: 0.2),
              const SizedBox(height: 10),

              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'রেজিস্টার করলে আপনি আমাদের ',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push('/privacy'),
                    child: const Text(
                      'গোপনীয়তা নীতি',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(
                    '-তে সম্মত হচ্ছেন',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 10),

              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'অ্যাকাউন্ট আছে? ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'লগইন করুন',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 430.ms),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected
                ? null
                : (isDark ? AppTheme.darkSurface : AppTheme.lightBackground),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            boxShadow: isSelected
                ? AppTheme.softShadow(AppTheme.primaryColor)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? AppTheme.onPrimary : AppTheme.primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppTheme.onPrimary : null,
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? AppTheme.onPrimary.withValues(alpha: 0.7)
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
