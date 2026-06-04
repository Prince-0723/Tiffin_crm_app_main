import 'package:flutter/foundation.dart';

/// Bumped when the user selects the Overview tab so [DashboardHomeScreen]
/// refetches (IndexedStack keeps the subtree mounted).
final ValueNotifier<int> overviewDashboardTabSelectedTick = ValueNotifier(0);
