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

/// App admin only: premium price list and bKash payments to approve.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isSuperAdminProvider)) {
      return const Scaffold(body: Center(child: Text('এই পেজ শুধু অ্যাডমিনের জন্য')));
    }
    final pending = ref.watch(pendingPremiumRequestsProvider);
    final recent = (ref.watch(recentPremiumRequestsProvider).valueOrNull ?? const <PremiumRequestModel>[])
        .where((r) => !r.isPending)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ScreenHeader(
              title: 'অ্যাডমিন',
              subtitle: 'প্রিমিয়াম পেমেন্ট ও দাম',
              onBack: context.isWide ? null : () => context.canPop() ? context.pop() : context.go('/more'),
            ),
            const SizedBox(height: 16),
            Text('যাচাই বাকি', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            pending.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('লোড করা যায়নি: $e'),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('কোনো পেমেন্ট বাকি নেই', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  : Column(children: [for (final r in list) _PendingCard(request: r)]),
            ),
            const SizedBox(height: 20),
            const _ConfigCard(),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('আগের পেমেন্ট', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final r in recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r.shopName} · ${r.months} মাস · ${CurrencyFormatter.formatNoDecimal(r.amount)}'),
                  subtitle: Text('${formatDayMonthYear(r.createdAt)} · TrxID ${r.trxId} · ${r.senderNumber}'),
                  trailing: StatusPill(
                    label: r.isApproved ? 'চালু' : 'বাতিল',
                    color: r.isApproved ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends ConsumerStatefulWidget {
  final PremiumRequestModel request;

  const _PendingCard({required this.request});

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final r = widget.request;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'পেমেন্ট পেয়েছেন?' : 'বাতিল করবেন?'),
        content: Text(approve
            ? 'বিকাশে TrxID ${r.trxId} দিয়ে ${CurrencyFormatter.formatNoDecimal(r.amount)} এসেছে কিনা মিলিয়ে নিন। '
                '"${r.shopName}" দোকানে ${r.months} মাস চালু হবে।'
            : 'এই পেমেন্ট পাওয়া যায়নি বলে দেখাবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('না')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: approve ? null : FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(approve ? 'চালু করুন' : 'বাতিল'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(premiumRepositoryProvider);
      if (approve) {
        final until = await repo.approve(r);
        messenger.showSnackBar(SnackBar(content: Text('${r.shopName}: ${formatDayMonthYear(until)} পর্যন্ত চালু')));
      } else {
        await repo.reject(r);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('হয়নি: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.shopName, style: Theme.of(context).textTheme.titleMedium),
          Text('${r.userName} · ${r.email}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text('${r.months} মাস · ${CurrencyFormatter.formatNoDecimal(r.amount)} · ${formatDayMonthYear(r.createdAt)}'),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  'TrxID ${r.trxId} · ${r.senderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'TrxID কপি',
                onPressed: () => Clipboard.setData(ClipboardData(text: r.trxId)),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(false),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                  child: const Text('বাতিল'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide(true),
                  child: const Text('চালু করুন'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends ConsumerStatefulWidget {
  const _ConfigCard();

  @override
  ConsumerState<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends ConsumerState<_ConfigCard> {
  final _monthly = TextEditingController();
  final _yearly = TextEditingController();
  final _bkash = TextEditingController();
  final _note = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_monthly, _yearly, _bkash, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(premiumRepositoryProvider).saveConfig(PremiumConfigModel(
        monthlyPrice: double.tryParse(_monthly.text.trim()) ?? 0,
        yearlyPrice: double.tryParse(_yearly.text.trim()) ?? 0,
        bkashNumber: _bkash.text.trim(),
        instructions: _note.text.trim(),
      ));
      messenger.showSnackBar(const SnackBar(content: Text('সেভ হয়েছে')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('সেভ হয়নি: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(premiumConfigProvider).valueOrNull;
    if (config != null && !_loaded) {
      _loaded = true;
      String n(double v) => v > 0 ? v.toStringAsFixed(0) : '';
      _monthly.text = n(config.monthlyPrice);
      _yearly.text = n(config.yearlyPrice);
      _bkash.text = config.bkashNumber;
      _note.text = config.instructions;
    }
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('স্টক অ্যাড-অনের দাম ও বিকাশ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _monthly,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'মাসিক দাম', prefixText: '৳ '),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _yearly,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(
                    labelText: '১২ মাসের দাম',
                    prefixText: '৳ ',
                    helperText: 'খালি থাকলে মাসিক × ১২',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bkash,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'বিকাশ নম্বর (টাকা আসবে)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'বাড়তি নির্দেশনা (ঐচ্ছিক, যেমন "পার্সোনাল নম্বর, Send Money করুন")'),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'সেভ হচ্ছে…' : 'সেভ করুন'),
          ),
        ],
      ),
    );
  }
}
