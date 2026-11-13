import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/strings.dart';
import '../widgets/auth_scaffold.dart';

class JoinShopScreen extends ConsumerStatefulWidget {
  const JoinShopScreen({super.key});

  @override
  ConsumerState<JoinShopScreen> createState() => _JoinShopScreenState();
}

class _JoinShopScreenState extends ConsumerState<JoinShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinShop() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shopRepository = ref.read(shopRepositoryProvider);
      final authRepository = ref.read(authRepositoryProvider);
      final currentUser = authRepository.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final shopId = await shopRepository.joinShop(
        inviteCode: _inviteCodeController.text.trim(),
        userId: currentUser.uid,
      );

      if (shopId == null) {
        setState(() {
          _errorMessage = 'Invalid invite code. Please check and try again.';
        });
        return;
      }

      // Navigation will be handled by router redirect
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to join shop. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);

    return AuthScaffold(
      icon: Icons.group_add_rounded,
      title: tr(locale, 'join_shop'),
      subtitle: 'Enter the invite code provided by your shop owner',
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
                controller: _inviteCodeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                onFieldSubmitted: (_) => _joinShop(),
                decoration: InputDecoration(
                  labelText: tr(locale, 'invite_code'),
                  prefixIcon: const Icon(Icons.key_rounded),
                  hintText: tr(locale, 'invite_code_hint'),
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                  ),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the invite code';
                  }
                  if (value.length != 6) {
                    return 'Invite code must be 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: tr(locale, 'join_shop_button'),
                icon: Icons.arrow_forward_rounded,
                isLoading: _isLoading,
                onPressed: _joinShop,
              ),
              const SizedBox(height: 20),
              const AuthInfoTile(
                icon: Icons.help_rounded,
                color: AppTheme.warningColor,
                title: 'Don\'t have a code?',
                message:
                    'Ask your shop owner for the invite code. They can find it in Settings > Staff Management.',
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: Text(tr(locale, 'logout')),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
