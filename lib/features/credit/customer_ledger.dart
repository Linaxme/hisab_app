import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/models.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/entry_form.dart';
import 'screens/credit_screen.dart';

const _whatsAppGreen = Color(0xFF25D366);

/// All credit sales of one customer, matched by phone number or else by name.
class CustomerAccount {
  final String key;
  final String? name;
  final String? phone;
  final List<CreditSaleModel> credits;

  const CustomerAccount({required this.key, this.name, this.phone, required this.credits});

  double get total => credits.fold(0, (sum, c) => sum + c.amount);
  double get collected => credits.fold(0, (sum, c) => sum + c.collectedAmount);
  double get remaining => credits.fold(0, (sum, c) => sum + (c.remainingAmount > 0 ? c.remainingAmount : 0));
  int get pendingCount => credits.where((c) => !c.isFullyPaid).length;
  DateTime get lastDate => credits.map((c) => c.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

String? _clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

String _customerKey(CreditSaleModel c) {
  final digits = c.customerPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  if (digits.length >= 10) return 'p:${digits.substring(digits.length - 10)}';
  final name = _clean(c.customerName)?.toLowerCase();
  return name == null ? '_unknown' : 'n:$name';
}

List<CustomerAccount> groupByCustomer(List<CreditSaleModel> credits) {
  final groups = <String, List<CreditSaleModel>>{};
  for (final c in credits) {
    groups.putIfAbsent(_customerKey(c), () => []).add(c);
  }
  final accounts = [
    for (final MapEntry(:key, :value) in groups.entries)
      () {
        final newestFirst = [...value]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return CustomerAccount(
          key: key,
          name: newestFirst.map((c) => _clean(c.customerName)).nonNulls.firstOrNull,
          phone: newestFirst.map((c) => _clean(c.customerPhone)).nonNulls.firstOrNull,
          credits: newestFirst,
        );
      }(),
  ];
  accounts.sort((a, b) {
    final byDue = b.remaining.compareTo(a.remaining);
    return byDue != 0 ? byDue : b.lastDate.compareTo(a.lastDate);
  });
  return accounts;
}

String _reminderText(WidgetRef ref, CustomerAccount account, String fallbackName) {
  final locale = ref.read(languageProvider);
  return tr(locale, 'reminder_msg', params: {
    'name': account.name ?? fallbackName,
    'shop': ref.read(currentShopProvider).valueOrNull?.name ?? '',
    'amount': CurrencyFormatter.formatNoDecimal(account.remaining),
  });
}

Future<void> _launch(BuildContext context, WidgetRef ref, Future<bool> Function() open) async {
  final ok = await open();
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(ref.read(languageProvider), 'launch_failed'))),
    );
  }
}

/// Credit grouped per customer with one-tap reminders.
class CustomerLedgerView extends ConsumerWidget {
  final String query;

  const CustomerLedgerView({super.key, this.query = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final credits = ref.watch(creditSalesProvider);

    return credits.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(tr(locale, 'load_error'))),
      data: (all) {
        var accounts = groupByCustomer(all);
        if (query.isNotEmpty) {
          accounts = accounts
              .where((a) =>
                  (a.name?.toLowerCase().contains(query) ?? false) ||
                  (a.phone?.contains(query) ?? false))
              .toList();
        }
        if (accounts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline_rounded, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(tr(locale, 'no_pending_credit')),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          itemCount: accounts.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4),
                child: Text(
                  tr(locale, 'customers_count', params: {'count': '${accounts.length}'}),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            final account = accounts[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CustomerCard(account: account)
                  .animate()
                  .fadeIn(delay: (30 * (i.clamp(0, 10))).ms, duration: 220.ms)
                  .slideY(begin: 0.06),
            );
          },
        );
      },
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  final CustomerAccount account;

  const _CustomerCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    String t(String key) => tr(locale, key);
    String money(double v) => CurrencyFormatter.formatNoDecimal(v);
    final name = account.name ?? t('unknown_customer');
    final cleared = account.remaining <= 0;
    final ratio = account.total <= 0 ? 1.0 : (account.collected / account.total).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showAppPanel(context, _CustomerDetailPanel(accountKey: account.key, hostContext: context)),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(context, radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Avatar(name: name, color: cleared ? AppTheme.successColor : AppTheme.warningColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                        ),
                        Text(
                          [
                            account.phone ?? t('no_phone'),
                            if (account.pendingCount > 0)
                              tr(locale, 'credit_count', params: {'count': '${account.pendingCount}'}),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  cleared
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            t('all_cleared'),
                            style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t('ledger_due'), style: Theme.of(context).textTheme.bodySmall),
                            Text(money(account.remaining), style: AppTheme.numeric(fontSize: 19, color: AppTheme.warningColor)),
                          ],
                        ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.successColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${t('ledger_paid')} ${money(account.collected)}',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.successColor, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${t('ledger_total')} ${money(account.total)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (!cleared) ...[
                const SizedBox(height: 12),
                _ReminderButtons(account: account),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderButtons extends ConsumerWidget {
  final CustomerAccount account;

  const _ReminderButtons({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final phone = account.phone;
    String text() => _reminderText(ref, account, tr(locale, 'unknown_customer'));

    return Row(
      children: [
        Expanded(
          child: _ContactButton(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: _whatsAppGreen,
            onTap: () => _launch(context, ref, () => ContactLauncher.whatsApp(phone: phone, text: text())),
          ),
        ),
        if (phone != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _ContactButton(
              icon: Icons.sms_rounded,
              label: 'SMS',
              color: AppTheme.infoColor,
              onTap: () => _launch(context, ref, () => ContactLauncher.sms(phone: phone, text: text())),
            ),
          ),
          const SizedBox(width: 8),
          _ContactButton(
            icon: Icons.call_rounded,
            label: tr(locale, 'call'),
            color: AppTheme.primaryColor,
            onTap: () => _launch(context, ref, () => ContactLauncher.call(phone)),
          ),
        ],
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;

  const _Avatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        name.characters.first.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 17),
      ),
    );
  }
}

class _CustomerDetailPanel extends ConsumerWidget {
  final String accountKey;
  final BuildContext hostContext;

  const _CustomerDetailPanel({required this.accountKey, required this.hostContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    String t(String key) => tr(locale, key);
    String money(double v) => CurrencyFormatter.formatNoDecimal(v);
    final all = ref.watch(creditSalesProvider).valueOrNull ?? const <CreditSaleModel>[];
    final account = groupByCustomer(all).where((a) => a.key == accountKey).firstOrNull;

    if (account == null) {
      return AppPanelFrame(title: t('ledger_view'), subtitle: '', child: const SizedBox(height: 80));
    }

    return AppPanelFrame(
      title: account.name ?? t('unknown_customer'),
      subtitle: account.phone ?? t('no_phone'),
      trailing: account.remaining > 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(t('ledger_due'), style: Theme.of(context).textTheme.bodySmall),
                Text(money(account.remaining), style: AppTheme.numeric(fontSize: 20, color: AppTheme.warningColor)),
              ],
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (account.remaining > 0) ...[
            _ReminderButtons(account: account),
            const SizedBox(height: 14),
          ],
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: account.credits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final credit = account.credits[i];
                final paid = credit.isFullyPaid;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormatter.formatDisplayFromString(credit.date),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t('ledger_total')} ${money(credit.amount)} · ${t('ledger_paid')} ${money(credit.collectedAmount)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (paid)
                        const Icon(Icons.verified_rounded, color: AppTheme.successColor)
                      else
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(context).pop();
                            showEntryForm(hostContext, CollectionFormSheet(creditSale: credit));
                          },
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            money(credit.remainingAmount),
                            style: AppTheme.numeric(fontSize: 13, color: AppTheme.warningColor),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
