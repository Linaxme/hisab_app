import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/strings.dart';
import '../widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
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
    if (error.contains('user-not-found')) {
      return 'এই ইমেইলে কোনো অ্যাকাউন্ট নেই।';
    } else if (error.contains('wrong-password')) {
      return 'পাসওয়ার্ড ভুল হয়েছে।';
    } else if (error.contains('invalid-email')) {
      return 'ইমেইল ঠিক নয়।';
    } else if (error.contains('user-disabled')) {
      return 'এই অ্যাকাউন্ট বন্ধ করা হয়েছে।';
    } else if (error.contains('invalid-credential')) {
      return 'ইমেইল বা পাসওয়ার্ড ভুল।';
    }
    return 'লগইন ব্যর্থ। আবার চেষ্টা করুন।';
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);

    return AuthScaffold(
      title: 'স্বাগতম',
      subtitle: 'আপনার দোকানের হিসাবে লগইন করুন',
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
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
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
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _login(),
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
                  return null;
                },
              ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.1),
              const SizedBox(height: 24),
              GradientButton(
                label: tr(locale, 'login'),
                icon: Icons.arrow_forward_rounded,
                isLoading: _isLoading,
                onPressed: _login,
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'অ্যাকাউন্ট নেই? ',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text(
                      'রেজিস্টার করুন',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 380.ms),
            ],
          ),
        ),
      ],
    );
  }
}
