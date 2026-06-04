import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../plans/data/plan_api.dart';
import '../../../plans/models/plan_model.dart';

class MealPlansScreen extends StatefulWidget {
  const MealPlansScreen({super.key});

  @override
  State<MealPlansScreen> createState() => _MealPlansScreenState();
}

class _MealPlansScreenState extends State<MealPlansScreen> {
  // ── Violet palette ────────────────────────────────────────────────────────
  static const _violet900 = Color(0xFF2D1B69);
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _bg = Color(0xFFF6F4FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _divider = Color(0xFFEEEBFA);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _success = Color(0xFF0F7B0F);
  static const _successSoft = Color(0xFFE6F4EA);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFCECEB);

  // ── State ─────────────────────────────────────────────────────────────────
  List<PlanModel> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── API (unchanged) ───────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await PlanApi.list(limit: 50, isActive: true);
      if (mounted) setState(() => _plans = list);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(PlanModel plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Plan',
          style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${plan.planName}"?',
          style: const TextStyle(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await PlanApi.delete(plan.id);
                if (mounted) {
                  AppSnackbar.success(context, 'Plan deleted');
                  _load();
                }
              } catch (e) {
                if (mounted) ErrorHandler.show(context, e);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final globalPlans = _plans
        .where((p) => p.customerId == null || p.customerId!.isEmpty)
        .toList();
    final customPlans = _plans
        .where((p) => p.customerId != null && p.customerId!.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _violet700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Meal Plans',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_plans.length} plans',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool?>(AppRoutes.createPlan);
          if (created == true && mounted) _load();
        },
        backgroundColor: _violet600,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
        label: const Text(
          'New Plan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: _violet600,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: _violet600,
              onRefresh: _load,
              child: ListView(
                cacheExtent: 400,
                padding: EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  MediaQuery.of(context).padding.bottom + 100,
                ),
                children: [
                  // ── Global Plans ─────────────────────────────────────────
                  _sectionHeader(
                    'Global Plans',
                    globalPlans.length,
                    Icons.public_rounded,
                  ),
                  const SizedBox(height: 10),
                  if (globalPlans.isEmpty)
                    _emptyCard('No global plans yet')
                  else
                    ...globalPlans.map(
                      (plan) => _PlanCard(
                        plan: plan,
                        isCustom: false,
                        onEdit: () async {
                          final updated = await context.push<bool?>(
                            AppRoutes.createPlan,
                            extra: plan,
                          );
                          if (updated == true && mounted) _load();
                        },
                        onDelete: () => _confirmDelete(plan),
                        onAssign: () => context.push(
                          AppRoutes.planAssignments,
                          extra: plan,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Custom Plans ─────────────────────────────────────────
                  _sectionHeader(
                    'Custom Plans',
                    customPlans.length,
                    Icons.tune_rounded,
                  ),
                  const SizedBox(height: 10),
                  if (customPlans.isEmpty)
                    _emptyCard('No custom plans yet')
                  else
                    ...customPlans.map(
                      (plan) => _PlanCard(
                        plan: plan,
                        isCustom: true,
                        onEdit: () async {
                          final updated = await context.push<bool?>(
                            AppRoutes.createPlan,
                            extra: plan,
                          );
                          if (updated == true && mounted) _load();
                        },
                        onDelete: () => _confirmDelete(plan),
                        onAssign: () => context.push(
                          AppRoutes.planAssignments,
                          extra: plan,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, int count, IconData icon) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: _violet600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _violet100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _violet600,
          ),
        ),
      ),
    ],
  );

  // ── Empty card ────────────────────────────────────────────────────────────
  Widget _emptyCard(String msg) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _violet100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.edit_note_rounded,
            size: 18,
            color: _violet600,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          msg,
          style: const TextStyle(
            fontSize: 13,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan card
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    // ignore: unused_element_parameter
    super.key,
    required this.plan,
    this.isCustom = false,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
  });

  final PlanModel plan;
  final bool isCustom;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssign;

  static const _violet900 = Color(0xFF2D1B69);
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _divider = Color(0xFFEEEBFA);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFCECEB);
  static const _success = Color(0xFF0F7B0F);
  static const _successSoft = Color(0xFFE6F4EA);

  // Plan type meta
  static (Color, Color, IconData) _typeMeta(String type) {
    switch (type.toLowerCase()) {
      case 'monthly':
        return (
          Color(0xFFEDE8FD),
          Color(0xFF4C2DB8),
          Icons.calendar_month_rounded,
        );
      case 'weekly':
        return (Color(0xFFE1F5EE), Color(0xFF0F6E56), Icons.date_range_rounded);
      case 'daily':
        return (Color(0xFFFAEEDA), Color(0xFF854F0B), Icons.today_rounded);
      default:
        return (Color(0xFFEEEBFA), Color(0xFF7B6DAB), Icons.event_rounded);
    }
  }

  // Slot icon
  static IconData _slotIcon(String slot) {
    switch (slot) {
      case 'breakfast':
        return Icons.wb_sunny_rounded;
      case 'lunch':
        return Icons.light_mode_rounded;
      case 'dinner':
        return Icons.nights_stay_rounded;
      case 'evening':
        return Icons.local_cafe_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (typeBg, typeColor, typeIcon) = _typeMeta(plan.planType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _violet900.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
              child: Row(
                children: [
                  // Type icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: typeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeIcon, size: 22, color: typeColor),
                  ),
                  const SizedBox(width: 12),

                  // Name + price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan.planName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Custom badge
                            if (isCustom)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBEAF0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF993556,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  'Custom',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF993556),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              '₹${plan.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _violet700,
                              ),
                            ),
                            Text(
                              ' / plan',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeBg,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                plan.planType[0].toUpperCase() +
                                    plan.planType.substring(1),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: _textSecondary,
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: _danger,
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // ── Meal slots ────────────────────────────────────────────────────
            if (plan.mealSlots.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: plan.mealSlots
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _violet50,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _slotIcon(s.slot),
                                size: 12,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.slot[0].toUpperCase() + s.slot.substring(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],

            // ── Assign button ─────────────────────────────────────────────────
            Divider(
              color: _divider,
              height: 1,
              thickness: 1,
              indent: 0,
              endIndent: 0,
            ),
            InkWell(
              onTap: onAssign,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _violet100,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.person_add_outlined,
                        size: 14,
                        color: _violet600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Assign to Customer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _violet600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: _violet600,
                    ),
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
