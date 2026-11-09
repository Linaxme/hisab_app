import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/models.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/entry_form.dart';
import '../credit/screens/credit_screen.dart';
import '../deposits/screens/deposits_screen.dart';
import '../expenses/screens/expenses_screen.dart';
import '../returns/screens/returns_screen.dart';
import '../sales/screens/sales_screen.dart';

class _EntryAction {
  final String labelKey;
  final String subKey;
  final IconData icon;
  final Color color;

  /// Null means "collect credit", which first asks which customer.
  final Widget? form;

  const _EntryAction(this.labelKey, this.subKey, this.icon, this.color, this.form);
}

const _actions = [
  _EntryAction('add_sale', 'entry_sale_sub', Icons.point_of_sale_rounded, AppTheme.successColor, SaleFormSheet()),
  _EntryAction('add_expense', 'entry_expense_sub', Icons.receipt_long_rounded, AppTheme.errorColor, ExpenseFormSheet()),
  _EntryAction('add_credit', 'entry_credit_sub', Icons.handshake_rounded, AppTheme.warningColor, CreditSaleFormSheet()),
  _EntryAction('entry_collect', 'entry_collect_sub', Icons.call_received_rounded, AppTheme.primaryColor, null),
  _EntryAction('add_deposit', 'entry_deposit_sub', Icons.savings_rounded, AppTheme.accentColor, DepositFormSheet()),
  _EntryAction('add_return', 'entry_return_sub', Icons.assignment_return_rounded, AppTheme.violetColor, ReturnFormSheet()),
];

/// The single "add anything" menu behind the centre + button and the
/// sidebar's New Entry button.
Future<void> showNewEntrySheet(BuildContext hostContext) {
  return showAppPanel(hostContext, _NewEntryPanel(hostContext: hostContext));
}

class _NewEntryPanel extends ConsumerWidget {
  final BuildContext hostContext;

  const _NewEntryPanel({required this.hostContext});

  void _open(BuildContext context, _EntryAction action) {
    Navigator.of(context).pop();
    final form = action.form;
    if (form == null) {
      showAppPanel(hostContext, _CollectPicker(hostContext: hostContext));
    } else {
      showEntryForm(hostContext, form);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final columns = context.isWide ? 3 : 2;

    return AppPanelFrame(
      title: tr(locale, 'new_entry'),
      subtitle: tr(locale, 'new_entry_sub'),
      child: GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: columns == 3 ? 1.25 : 1.35,
        children: [
          for (final (i, action) in _actions.indexed)
            _ActionTile(
              label: tr(locale, action.labelKey),
              subtitle: tr(locale, action.subKey),
              icon: action.icon,
              color: action.color,
              onTap: () => _open(context, action),
            )
                .animate()
                .fadeIn(delay: (40 * i).ms, duration: 220.ms)
                .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.16), AppTheme.darkCard],
            ),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: AppTheme.softShadow(color),
                ),
                child: Icon(icon, color: AppTheme.onColor(color), size: 22),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectPicker extends ConsumerWidget {
  final BuildContext hostContext;

  const _CollectPicker({required this.hostContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final pending = ref.watch(pendingCreditSalesProvider);

    return AppPanelFrame(
      title: tr(locale, 'entry_collect'),
      subtitle: tr(locale, 'pick_credit_customer'),
      child: pending.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Center(child: Text(tr(locale, 'load_error'))),
        data: (credits) {
          if (credits.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 48, color: AppTheme.successColor),
                  const SizedBox(height: 12),
                  Text(tr(locale, 'no_pending_credit')),
                ],
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            itemCount: credits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _CreditRow(
              credit: credits[i],
              fallbackName: tr(locale, 'unknown_customer'),
              onTap: () {
                Navigator.of(context).pop();
                showEntryForm(hostContext, CollectionFormSheet(creditSale: credits[i]));
              },
            ),
          );
        },
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final CreditSaleModel credit;
  final String fallbackName;
  final VoidCallback onTap;

  const _CreditRow({required this.credit, required this.fallbackName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (credit.customerName?.trim().isNotEmpty ?? false) ? credit.customerName!.trim() : fallbackName;
    return Material(
      color: AppTheme.darkCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.warningColor.withValues(alpha: 0.15),
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: const TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (credit.customerPhone?.isNotEmpty ?? false)
                      Text(credit.customerPhone!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatNoDecimal(credit.remainingAmount),
                style: AppTheme.numeric(fontSize: 16, color: AppTheme.warningColor),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
