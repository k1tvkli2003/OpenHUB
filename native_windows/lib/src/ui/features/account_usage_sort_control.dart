import 'package:flutter/material.dart';

import '../../models/account_summary.dart';
import '../../state/app_controller.dart';
import '../app_theme.dart';

class AccountUsageSortControl extends StatelessWidget {
  const AccountUsageSortControl({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildControl(context),
    );
  }

  Widget _buildControl(BuildContext context) {
    final order = controller.accountRemainingUsageOrder;
    return Tooltip(
      message:
          'Sets the remaining-usage order for every account list and account picker in OpenHUB.',
      child: Semantics(
        button: true,
        label: order == AccountRemainingUsageOrder.highestFirst
            ? 'Account order: highest remaining usage first'
            : 'Account order: lowest remaining usage first',
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AccountRemainingUsageOrder>(
            value: order,
            isDense: true,
            borderRadius: BorderRadius.circular(AppRadii.control),
            icon: const Padding(
              padding: EdgeInsets.only(left: 5),
              child: Icon(Icons.swap_vert_rounded, color: AppPalette.cyan),
            ),
            selectedItemBuilder: (context) => AccountRemainingUsageOrder.values
                .map(
                  (value) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_label(value, compact: compact)),
                  ),
                )
                .toList(growable: false),
            items: AccountRemainingUsageOrder.values
                .map(
                  (value) => DropdownMenuItem<AccountRemainingUsageOrder>(
                    value: value,
                    child: Text(_label(value)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                controller.setAccountRemainingUsageOrder(value);
              }
            },
          ),
        ),
      ),
    );
  }

  static String _label(
    AccountRemainingUsageOrder order, {
    bool compact = false,
  }) {
    return switch (order) {
      AccountRemainingUsageOrder.highestFirst =>
        compact ? 'High → low' : 'Usage left · high → low',
      AccountRemainingUsageOrder.lowestFirst =>
        compact ? 'Low → high' : 'Usage left · low → high',
    };
  }
}
