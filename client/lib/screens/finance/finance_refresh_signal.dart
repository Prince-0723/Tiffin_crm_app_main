import 'package:flutter/foundation.dart';

/// Bumped when the user selects the Finance tab on the main dashboard so
/// [FinanceScreen] can refetch (IndexedStack keeps the subtree mounted).
final ValueNotifier<int> financeDashboardTabSelectedTick = ValueNotifier(0);
