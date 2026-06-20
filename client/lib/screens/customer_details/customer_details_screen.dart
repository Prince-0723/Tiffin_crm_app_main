import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import 'tabs/customer_info_tab.dart';
import 'tabs/deliveries_tab.dart';
import 'tabs/meal_plan_tab.dart';
import 'tabs/transactions_tab.dart';

/// Matches Customers list / detail purple palette (no theme changes).
class _P {
  static const g1 = Color(0xFF7B3FE4);
  static const bg = Color(0xFFF0EBFF);
  static const s900 = Color(0xFF0F172A);
  static const s600 = Color(0xFF475569);
}

class _D {
  static const bg = Color(0xFF0E1020);
}

/// Tabbed customer workspace: info, meal plan, transactions, balance, deliveries.
class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _mealPlanGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openAssignPlan() async {
    await context.push(AppRoutes.planAssignments);
    if (!mounted) return;
    setState(() => _mealPlanGeneration++);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _D.bg : _P.bg,
      appBar: AppBar(
        backgroundColor: _P.g1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.customerName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Info'),
            Tab(icon: Icon(Icons.restaurant_menu, size: 20), text: 'Meal Plan'),
            Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'Transactions'),
            Tab(
              icon: Icon(Icons.delivery_dining, size: 20),
              text: 'Deliveries',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CustomerInfoTab(customerId: widget.customerId),
          MealPlanTab(
            key: ValueKey<String>(
              'meal-plan-${widget.customerId}-$_mealPlanGeneration',
            ),
            customerId: widget.customerId,
          ),
          TransactionsTab(
            customerId: widget.customerId,
            customerName: widget.customerName,
          ),
          DeliveriesTab(
            customerId: widget.customerId,
            customerName: widget.customerName,
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              heroTag: 'customer_detail_assign_plan',
              onPressed: _openAssignPlan,
              backgroundColor: _P.g1,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
