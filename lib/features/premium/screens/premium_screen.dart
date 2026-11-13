import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/models.dart';
import '../../../widgets/modern_widgets.dart';
import '../../stock/screens/stock_screen.dart' show formatDayMonthYear;

/// Add-on status for everyone; on the web the owner can also pay by bKash here.
/// The Android app shows no prices or payment links (Play policy).
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(shopPremiumProvider).valueOrNull;
    final active = premium?.isStockActive ?? false;
    final isOwner = ref.watch(currentUserProvider).valueOrNull?.isOwner ?? false;
    final requests = ref.watch(myPremiumRequestsProvider).valueOrNull ?? const <PremiumRequestModel>[];
    final hasPending = requests.any((r) => r.isPending);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ScreenHeader(
              title: 'প্রিমিয়াম',
              onBack: context.isWide ? null : () => context.canPop() ? context.pop() : context.go('/more'),
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusCard(active: active, until: premium?.stockUntil),
                    if (kIsWeb && isOwner) ...[
                      const SizedBox(height: 16),
                      if (hasPending)
                        const _Notice(
                          icon: Icons.hourglass_top_rounded,
                          color: AppTheme.warningColor,
                          text: 'আপনার পেমেন্ট যাচাই হচ্ছে। যাচাই হলে অ্যাড-অন নিজে থেকেই চালু হয়ে যাবে।',
                        )
                      else
                        const _PaymentForm(),
                    ],
                    if (requests.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('আপনার পেমেন্ট', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final r in requests) _RequestTile(request: r),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool active;
  final DateTime? until;

  const _StatusCard({required this.active, this.until});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.inventory_rounded,
            color: active ? AppTheme.successColor : AppTheme.warningColor,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('স্টক অ্যাড-অন', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  active
                      ? '${formatDayMonthYear(until!)} পর্যন্ত চালু'
                      : until == null
                          ? 'চালু নেই'
                          : 'মেয়াদ শেষ হয়েছে ${formatDayMonthYear(until!)}',
                  style: TextStyle(color: active ? AppTheme.successColor : AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Notice({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _PaymentForm extends ConsumerStatefulWidget {
  const _PaymentForm();

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  final _trx = TextEditingController();
  final _sender = TextEditingController();
  int _months = 1;
  bool _sending = false;

  @override
  void dispose() {
    _trx.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _submit(PremiumConfigModel config) async {
    final trx = _trx.text.trim().toUpperCase();
    final sender = _sender.text.trim();
    if (trx.length < 6 || sender.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সঠিক TrxID আর যে নম্বর থেকে পাঠিয়েছেন সেটা দিন')),
      );
      return;
    }
    final user = ref.read(currentUserProvider).valueOrNull;
    final shop = ref.read(currentShopProvider).valueOrNull;
    if (user == null || shop == null) return;

    setState(() => _sending = true);
    try {
      await ref.read(premiumRepositoryProvider).submitRequest(PremiumRequestModel(
        id: '',
        shopId: shop.id,
        shopName: shop.name,
        uid: user.uid,
        userName: user.name,
        email: user.email,
        months: _months,
        amount: config.priceFor(_months),
        trxId: trx,
        senderNumber: sender,
        createdAt: DateTime.now(),
      ));
      _trx.clear();
      _sender.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('পাঠানো যায়নি: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(premiumConfigProvider);
    return config.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('লোড করা যায়নি: $e'),
      data: (config) {
        if (!config.isReady) {
          return const _Notice(
            icon: Icons.info_outline_rounded,
            color: AppTheme.infoColor,
            text: 'পেমেন্টের তথ্য এখনো দেওয়া হয়নি। একটু পরে আবার দেখুন।',
          );
        }
        final amount = config.priceFor(_months);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context, radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('চালু করুন', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 1,
                    label: Text('১ মাস · ${CurrencyFormatter.formatNoDecimal(config.priceFor(1))}'),
                  ),
                  ButtonSegment(
                    value: 12,
                    label: Text('১২ মাস · ${CurrencyFormatter.formatNoDecimal(config.priceFor(12))}'),
                  ),
                ],
                selected: {_months},
                onSelectionChanged: (s) => setState(() => _months = s.first),
              ),
              const SizedBox(height: 16),
              _Step(n: '১', child: Row(
                children: [
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      const TextSpan(text: 'বিকাশ থেকে '),
                      TextSpan(
                        text: config.bkashNumber,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
                      ),
                      const TextSpan(text: ' নম্বরে '),
                      TextSpan(
                        text: CurrencyFormatter.formatNoDecimal(amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' Send Money করুন'),
                    ])),
                  ),
                  IconButton(
                    tooltip: 'নম্বর কপি',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: config.bkashNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('নম্বর কপি হয়েছে')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ],
              )),
              if (config.instructions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 8),
                  child: Text(config.instructions, style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              const _Step(n: '২', child: Text('বিকাশের মেসেজে পাওয়া TrxID আর যে নম্বর থেকে পাঠিয়েছেন সেটা নিচে দিন')),
              const SizedBox(height: 8),
              TextField(
                controller: _trx,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'TrxID', hintText: 'যেমন 8N7A6D5K3L'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _sender,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'যে বিকাশ নম্বর থেকে পাঠিয়েছেন'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _sending ? null : () => _submit(config),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: Text(_sending ? 'পাঠানো হচ্ছে…' : 'পেমেন্ট জমা দিন'),
              ),
              const SizedBox(height: 8),
              const Text(
                'যাচাই হলে সাধারণত কয়েক ঘণ্টার মধ্যে চালু হয়ে যাবে, অ্যাপেও।',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final Widget child;

  const _Step({required this.n, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryColor,
            child: Text(n, style: const TextStyle(fontSize: 12, color: AppTheme.onPrimary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: child)),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final PremiumRequestModel request;

  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (request.status) {
      'approved' => ('চালু হয়েছে', AppTheme.successColor),
      'rejected' => ('পাওয়া যায়নি', AppTheme.errorColor),
      _ => ('যাচাই হচ্ছে', AppTheme.warningColor),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(context, radius: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${request.months} মাস · ${CurrencyFormatter.formatNoDecimal(request.amount)}'),
                Text(
                  '${formatDayMonthYear(request.createdAt)} · TrxID ${request.trxId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusPill(label: label, color: color),
        ],
      ),
    );
  }
}
