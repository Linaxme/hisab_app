import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/strings.dart';
import '../widgets/auth_scaffold.dart';

class CreateShopScreen extends ConsumerStatefulWidget {
  const CreateShopScreen({super.key});

  @override
  ConsumerState<CreateShopScreen> createState() => _CreateShopScreenState();
}

class _CreateShopScreenState extends ConsumerState<CreateShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _createShop() async {
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

      await shopRepository.createShop(
        name: _shopNameController.text.trim(),
        ownerUid: currentUser.uid,
      );

      // Navigation will be handled by router redirect
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create shop. Please try again.';
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
      icon: Icons.add_business_rounded,
      title: tr(locale, 'create_shop'),
      subtitle: 'Set up your shop to start managing your business',
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
                controller: _shopNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _createShop(),
                decoration: InputDecoration(
                  labelText: tr(locale, 'shop_name'),
                  prefixIcon: const Icon(Icons.storefront_rounded),
                  hintText: tr(locale, 'shop_name_hint'),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your shop name';
                  }
                  if (value.length < 2) {
                    return 'Shop name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: tr(locale, 'create_shop_button'),
                icon: Icons.arrow_forward_rounded,
                isLoading: _isLoading,
                onPressed: _createShop,
              ),
              const SizedBox(height: 20),
              const AuthInfoTile(
                icon: Icons.lightbulb_rounded,
                color: AppTheme.primaryColor,
                title: 'What happens next?',
                message:
                    'After creating your shop, you\'ll get an invite code that you can share with your staff members.',
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
