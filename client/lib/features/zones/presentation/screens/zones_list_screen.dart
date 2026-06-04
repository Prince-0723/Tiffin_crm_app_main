import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/router/app_routes.dart';
import '../../data/zone_api.dart';
import '../../models/zone_model.dart';
import 'add_edit_zone_screen.dart';

class ZonesListScreen extends StatefulWidget {
  const ZonesListScreen({super.key});

  @override
  State<ZonesListScreen> createState() => _ZonesListScreenState();
}

class _ZonesListScreenState extends State<ZonesListScreen> {
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
  bool _loading = true;
  List<ZoneModel> _zones = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final zones = await ZoneApi.list(limit: 100);
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ErrorHandler.show(context, e);
    }
  }

  Future<void> _openCreate() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddEditZoneScreen()));
    await _load();
  }

  Future<void> _openEdit(ZoneModel zone) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddEditZoneScreen(zone: zone)));
    await _load();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _zoneColor(ZoneModel z) {
    if (z.color.isEmpty) return _violet100;
    try {
      final hex = z.color.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return _violet100;
  }

  String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
          'Delivery Zones',
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
                  '${_zones.length} zones',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openCreate,
        backgroundColor: _violet600,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_location_alt_outlined, size: 18),
        label: const Text(
          'Add Zone',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: _violet600,
                strokeWidth: 2.5,
              ),
            )
          : _zones.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() => SafeArea(
    child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _violet100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.map_outlined, size: 36, color: _violet600),
        ),
        const SizedBox(height: 16),
        const Text(
          'No delivery zones',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Create zones to manage delivery areas',
          style: TextStyle(fontSize: 13, color: _textSecondary),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _openCreate,
          icon: const Icon(Icons.add_location_alt_outlined, size: 16),
          label: const Text(
            'Create First Zone',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _violet600,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(AppRoutes.dashboard),
          style: TextButton.styleFrom(foregroundColor: _textSecondary),
          child: const Text(
            'Back to Dashboard',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
    ),
  );

  // ── List ──────────────────────────────────────────────────────────────────
  Widget _buildList() => ListView.builder(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.of(context).padding.bottom + 100,
    ),
    itemCount: _zones.length,
    itemBuilder: (context, i) => _buildZoneCard(_zones[i]),
  );

  // ── Zone card ─────────────────────────────────────────────────────────────
  Widget _buildZoneCard(ZoneModel z) {
    final zColor = _zoneColor(z);
    final initial = _initial(z.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openEdit(z),
        borderRadius: BorderRadius.circular(14),
        splashColor: _violet100,
        highlightColor: _violet50,
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
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left color accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: z.color.isNotEmpty ? zColor : _violet600,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        // Zone icon/initial
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: z.color.isNotEmpty
                                ? zColor.withValues(alpha: 0.15)
                                : _violet100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: z.color.isNotEmpty
                                    ? zColor.withValues(alpha: 1)
                                    : _violet700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name + description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                z.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (z.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  z.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: z.isActive
                                      ? _successSoft
                                      : _dangerSoft,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: z.isActive
                                        ? _success.withValues(alpha: 0.25)
                                        : _danger.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: z.isActive ? _success : _danger,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      z.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: z.isActive ? _success : _danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: _textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
