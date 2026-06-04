import 'package:flutter/material.dart';

import '../../../../screens/finance/finance_screen.dart';

/// Finance section entry point (drawer-driven navigation — no internal bottom nav).
class FinanceShell extends StatelessWidget {
  const FinanceShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const FinanceScreen();
  }
}
