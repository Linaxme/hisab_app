import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
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
  final IconData icon;
  final Color color;

  /// Null means "collect credit", which first asks which customer.
  final Widget? form;

  const _EntryAction(this.labelKey, this.icon, this.color, this.form);
}

const _actions = [
  _EntryAction('add_sale', Icons.point_of_sale_rounded, AppTheme.successColor, SaleFormSheet()),
  _EntryAction('add_expense', Icons.receipt_long_rounded, AppTheme.errorColor, ExpenseFormSheet()),
  _EntryAction('add_credit', Icons.handshake_rounded, AppTheme.warningColor, CreditSaleFormSheet()),
  _EntryAction('entry_collect', Icons.call_received_rounded, AppTheme.primaryColor, null),
  _EntryAction('add_deposit', Icons.savings_rounded, AppTheme.accentColor, DepositFormSheet()),
  _EntryAction('add_return', Icons.assignment_return_rounded, AppTheme.violetColor, ReturnFormSheet()),
];

/// The single "add anything" menu behind the centre + button and the
/// sidebar's New Entry button.
Future<void> showNewEntrySheet(BuildContext hostContext) {
  return showAppPanel(
    hostContext,
    _NewEntryPanel(hostContext: hostContext),
    maxWidth: 440,
  );
}

class _NewEntryPanel extends ConsumerWidget {
  final BuildContext hostContext;

  const _NewEntryPanel({required this.hostContext});

  void _open(BuildContext context, _EntryAction action) {
    Navigator.of(context).pop();
    final form = action.form;
    if (form == null) {
      showAppPanel(
        hostContext,
        _CollectPicker(hostContext: hostContext),
        maxWidth: 440,
      );
    } else {
      showEntryForm(hostContext, form);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);

    return AppPanelFrame(
      title: tr(locale, 'new_entry'),
      subtitle: tr(locale, 'new_entry_sub'),
      child: GridView(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 56,
        ),
        children: [
          for (final (i, action) in _actions.indexed)
            _ActionButton(
              label: tr(locale, action.labelKey),
              icon: action.icon,
              color: action.color,
              onTap: () => _open(context, action),
            )
                .animate()
                .fadeIn(delay: (30 * i).ms, duration: 200.ms)
                .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.12),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
