import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/delivery_api.dart';
import '../../models/delivery_staff_model.dart';

class _D {
  static const bg = Color(0xFF0E1020);
  static const surface = Color(0xFF1B1F2E);
  static const border = Color(0xFF2F3347);
  static const divider = Color(0xFF2F3347);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const violet100 = Color(0xFF241B42);
  static const violet50 = Color(0xFF141625);
}

class DeliveryStaffListScreen extends StatefulWidget {
  const DeliveryStaffListScreen({super.key});

  @override
  State<DeliveryStaffListScreen> createState() =>
      _DeliveryStaffListScreenState();
}

class _DeliveryStaffListScreenState extends State<DeliveryStaffListScreen> {
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
  List<DeliveryStaffModel> _staff = [];
  bool _loading = true;
  bool _activeOnly = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await DeliveryApi.listStaff(
        limit: 100,
        isActive: _activeOnly ? true : null,
      );
      if (mounted) setState(() => _staff = list);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirmDelete(DeliveryStaffModel staff) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _D.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Staff Member',
          style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? _D.textPrimary : _textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove ${staff.name}? This action cannot be undone.',
          style: TextStyle(color: isDark ? _D.textSecondary : _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? _D.textSecondary : _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await DeliveryApi.deleteStaff(staff.id);
                if (mounted) {
                  AppSnackbar.success(context, '${staff.name} removed');
                  _load();
                }
              } catch (e) {
                if (mounted) ErrorHandler.show(context, e);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFEF4444) : _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _D.bg : _bg,
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
          'Delivery Staff',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          // Staff count badge
          Padding(
            padding: const EdgeInsets.only(right: 14),
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
                  '${_staff.length} staff',
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
        // Toggle moved to bottom strip to prevent overlap
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: _violet700,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Show:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    setState(() => _activeOnly = !_activeOnly);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _activeOnly
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _activeOnly ? 'Active only' : 'All staff',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _activeOnly ? _violet700 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? const Color(0xFFA78BFA) : _violet600,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: _violet600,
              onRefresh: _load,
              child: _staff.isEmpty ? _buildEmptyState(isDark) : _buildList(isDark),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool?>(AppRoutes.addDeliveryStaff);
          if (created == true && mounted) _load();
        },
        backgroundColor: _violet600,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_outlined, size: 18),
        label: const Text(
          'Add Staff',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) => ListView(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).padding.bottom + 24,
    ),
    children: [
      const SizedBox(height: 80),
      Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? _D.violet100 : _violet100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 36,
                color: isDark ? const Color(0xFFA78BFA) : _violet600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No delivery staff',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? _D.textPrimary : _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + Add Staff to get started',
              style: TextStyle(fontSize: 13, color: isDark ? _D.textSecondary : _textSecondary),
            ),
          ],
        ),
      ),
    ],
  );

  // ── Staff list ────────────────────────────────────────────────────────────
  Widget _buildList(bool isDark) => ListView.builder(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.of(context).padding.bottom + 100,
    ),
    itemCount: _staff.length,
    itemBuilder: (context, index) => _buildStaffCard(_staff[index], isDark),
  );

  // ── Staff card ────────────────────────────────────────────────────────────
  Widget _buildStaffCard(DeliveryStaffModel s, bool isDark) {
    final initials = _getInitials(s.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final updated = await context.push<bool?>(
            AppRoutes.editDeliveryStaff,
            extra: s,
          );
          if (updated == true && mounted) _load();
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: isDark ? _D.violet100 : _violet100,
        highlightColor: isDark ? _D.violet50 : _violet50,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? _D.surface : _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? _D.border : _border),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : _violet900.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Top row ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: s.isActive
                            ? (isDark ? _D.violet100 : _violet100)
                            : (isDark ? _D.divider : _divider),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: s.isActive
                                ? (isDark ? const Color(0xFFA78BFA) : _violet700)
                                : (isDark ? _D.textSecondary : _textSecondary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? _D.textPrimary : _textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: s.isActive
                                      ? (isDark ? const Color(0xFF0F2A1C) : _successSoft)
                                      : (isDark ? _D.divider : _divider),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: s.isActive
                                        ? (isDark ? const Color(0xFF1F6B3F) : _success.withValues(alpha: 0.3))
                                        : (isDark ? _D.border : _border),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: s.isActive
                                            ? (isDark ? const Color(0xFF4ADE80) : _success)
                                            : (isDark ? _D.textSecondary : _textSecondary),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      s.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: s.isActive
                                            ? (isDark ? const Color(0xFF4ADE80) : _success)
                                            : (isDark ? _D.textSecondary : _textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 12,
                                color: isDark ? _D.textSecondary : _textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.phone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? _D.textSecondary : _textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (s.areas.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 12,
                                  color: isDark ? _D.textSecondary : _textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    s.areas.join(' · '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? _D.textSecondary : _textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Custom toggle
                    GestureDetector(
                      onTap: () async {
                        try {
                          await DeliveryApi.updateStaff(s.id, {
                            'isActive': !s.isActive,
                          });
                          if (!context.mounted) return;
                          _load();
                        } catch (e) {
                          if (!context.mounted) return;
                          ErrorHandler.show(context, e);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 28,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: s.isActive
                              ? _violet600
                              : (isDark ? const Color(0xFF242238) : const Color(0xFFD0C8E8)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: s.isActive
                                ? _violet700
                                : (isDark ? const Color(0xFF3B335C) : const Color(0xFFB0A8D0)),
                            width: 1.5,
                          ),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: s.isActive
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              s.isActive
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              size: 12,
                              color: s.isActive
                                  ? _violet600
                                  : (isDark ? const Color(0xFF5A527A) : const Color(0xFFB0A8D0)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ───────────────────────────────────────────────────
              Divider(
                color: isDark ? _D.divider : _divider,
                height: 1,
                thickness: 1,
                indent: 14,
                endIndent: 14,
              ),

              // ── Action row ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    _ActionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      color: isDark ? const Color(0xFFA78BFA) : _violet600,
                      bg: isDark ? _D.violet100 : _violet50,
                      onTap: () async {
                        final updated = await context.push<bool?>(
                          AppRoutes.editDeliveryStaff,
                          extra: s,
                        );
                        if (updated == true && mounted) _load();
                      },
                    ),
                    _ActionBtn(
                      icon: Icons.map_outlined,
                      label: 'Track',
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF185FA5),
                      bg: isDark ? const Color(0xFF0E253A) : const Color(0xFFE6F1FB),
                      onTap: () => context.push(AppRoutes.maps, extra: s),
                    ),
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove',
                      color: isDark ? const Color(0xFFF87171) : _danger,
                      bg: isDark ? const Color(0xFF381A1C) : _dangerSoft,
                      onTap: () => _confirmDelete(s),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button for card footer
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
