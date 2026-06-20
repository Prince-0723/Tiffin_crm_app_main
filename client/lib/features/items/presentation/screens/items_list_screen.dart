import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../data/item_api.dart';
import '../../models/item_model.dart';

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

class ItemsListScreen extends StatefulWidget {
  const ItemsListScreen({super.key});

  @override
  State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  // ── Violet palette ────────────────────────────────────────────────────────
  static const _violet900 = Color(0xFF2D1B69);
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet500 = Color(0xFF6C42F5);
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
  List<ItemModel> _items = [];
  bool _isLoading = true;
  String? _categoryFilter;
  bool? _activeFilter = true;

  static const _categories = ['roti', 'sabji', 'dal', 'rice', 'other'];

  String _categoryPillLabel() {
    final label = _categoryFilter == null
        ? 'All'
        : (_categoryFilter![0].toUpperCase() + _categoryFilter!.substring(1));
    return 'Category ($label)';
  }

  String _statusPillLabel() {
    final label = _activeFilter == null
        ? 'All'
        : (_activeFilter == true ? 'Active' : 'Inactive');
    return 'Status ($label)';
  }

  Widget _dropdownPill({required String label, required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? _D.violet100 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? _D.border : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? _D.textSecondary : _textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isDark ? const Color(0xFFA78BFA) : _violet600,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCategorySheet(bool isDark) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(String? value, String label) {
          final sel = _categoryFilter == value;
          return InkWell(
            onTap: () async {
              Navigator.pop(ctx);
              setState(() => _categoryFilter = value);
              await _load();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? (isDark ? const Color(0xFFA78BFA) : _violet600) : (isDark ? _D.textSecondary : _textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? (isDark ? _D.textPrimary : _textPrimary)
                            : (isDark ? _D.textSecondary : _textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? _D.surface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? _D.border : _border),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Category',
                            style: TextStyle(
                              color: isDark ? _D.textPrimary : _textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: isDark ? _D.textSecondary : _textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: isDark ? _D.divider : _divider),
                  item(null, 'All'),
                  for (final c in _categories) ...[
                    Container(height: 1, color: isDark ? _D.divider : _divider),
                    item(c, c[0].toUpperCase() + c.substring(1)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStatusSheet(bool isDark) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(bool? value, String label) {
          final sel = _activeFilter == value;
          return InkWell(
            onTap: () async {
              Navigator.pop(ctx);
              setState(() => _activeFilter = value);
              await _load();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? (isDark ? const Color(0xFFA78BFA) : _violet600) : (isDark ? _D.textSecondary : _textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? (isDark ? _D.textPrimary : _textPrimary)
                            : (isDark ? _D.textSecondary : _textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? _D.surface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? _D.border : _border),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Status',
                            style: TextStyle(
                              color: isDark ? _D.textPrimary : _textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: isDark ? _D.textSecondary : _textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: isDark ? _D.divider : _divider),
                  item(true, 'Active'),
                  Container(height: 1, color: isDark ? _D.divider : _divider),
                  item(false, 'Inactive'),
                  Container(height: 1, color: isDark ? _D.divider : _divider),
                  item(null, 'All'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await ItemApi.list(
        limit: 50,
        isActive: _activeFilter,
        category: _categoryFilter,
      );
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditSheet({ItemModel? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditItemSheet(
        item: item,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
        onError: (e) => ErrorHandler.show(ctx, e),
      ),
    );
  }

  void _confirmDelete(ItemModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _D.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Item',
          style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? _D.textPrimary : _textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"?',
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
                await ItemApi.delete(item.id);
                if (mounted) {
                  AppSnackbar.success(context, 'Item deleted');
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  final msg = e.toString();
                  ErrorHandler.show(
                    context,
                    msg.contains('active plan') || msg.contains('400')
                        ? ApiException(
                            'Cannot delete — item is used in an active plan. Disable it instead.',
                          )
                        : e,
                  );
                }
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
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(ItemModel item, bool value) async {
    final prev = item.isActive;
    setState(
      () => _items = _items
          .map(
            (i) => i.id == item.id
                ? ItemModel(
                    id: i.id,
                    name: i.name,
                    unitPrice: i.unitPrice,
                    unit: i.unit,
                    category: i.category,
                    isActive: value,
                    vendorId: i.vendorId,
                  )
                : i,
          )
          .toList(),
    );
    try {
      await ItemApi.update(item.id, {
        'isActive': value,
        'name': item.name,
        'unit': item.unit,
        'category': item.category,
      });
    } catch (e) {
      setState(
        () => _items = _items
            .map(
              (i) => i.id == item.id
                  ? ItemModel(
                      id: i.id,
                      name: i.name,
                      unitPrice: i.unitPrice,
                      unit: i.unit,
                      category: i.category,
                      isActive: prev,
                      vendorId: i.vendorId,
                    )
                  : i,
            )
            .toList(),
      );
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  // ── Category meta ─────────────────────────────────────────────────────────
  static (IconData, Color, Color) _catMeta(String cat, bool isDark) {
    if (isDark) {
      switch (cat.toLowerCase()) {
        case 'roti':
          return (Icons.breakfast_dining, const Color(0xFFF59E0B), const Color(0xFF2D2418));
        case 'sabji':
          return (Icons.lunch_dining, const Color(0xFF10B981), const Color(0xFF122C21));
        case 'dal':
          return (Icons.soup_kitchen, const Color(0xFFF97316), const Color(0xFF2E1C15));
        case 'rice':
          return (Icons.rice_bowl, const Color(0xFFA78BFA), const Color(0xFF241B42));
        default:
          return (Icons.restaurant_rounded, const Color(0xFF94A3B8), const Color(0xFF1E293B));
      }
    } else {
      switch (cat.toLowerCase()) {
        case 'roti':
          return (Icons.breakfast_dining, const Color(0xFF854F0B), const Color(0xFFFAEEDA));
        case 'sabji':
          return (Icons.lunch_dining, const Color(0xFF3B6D11), const Color(0xFFEAF3DE));
        case 'dal':
          return (Icons.soup_kitchen, const Color(0xFF8B4513), const Color(0xFFF5EBE0));
        case 'rice':
          return (Icons.rice_bowl, const Color(0xFF4C2DB8), const Color(0xFFEDE8FD));
        default:
          return (Icons.restaurant_rounded, const Color(0xFF6B7A99), const Color(0xFFF1F0F8));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _D.bg : Colors.white,
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
          'Menu Items',
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
                  '${_items.length} items',
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
        // Filter strip in AppBar bottom
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: isDark ? _D.surface : Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 1, color: isDark ? _D.border : Colors.white.withValues(alpha: 0.08)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      _dropdownPill(
                        label: _categoryPillLabel(),
                        onTap: () => _openCategorySheet(isDark),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _dropdownPill(
                        label: _statusPillLabel(),
                        onTap: () => _openStatusSheet(isDark),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: isDark ? _D.border : _divider),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: _violet600,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
        label: const Text(
          'Add Item',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? const Color(0xFFA78BFA) : _violet600,
                strokeWidth: 2.5,
              ),
            )
          : _items.isEmpty
          ? _buildEmptyState(isDark)
          : RefreshIndicator(
              color: _violet600,
              onRefresh: _load,
              child: ListView.separated(
                cacheExtent: 400,
                padding: EdgeInsets.only(
                  top: 6,
                  bottom: MediaQuery.of(context).padding.bottom + 92,
                ),
                itemCount: _items.length,
                separatorBuilder: (_, _) => Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 16),
                  color: isDark ? _D.divider : _divider,
                ),
                itemBuilder: (ctx, i) =>
                    RepaintBoundary(child: _buildItemCard(_items[i], isDark)),
              ),
            ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: isDark ? _D.violet100 : _violet100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: 36,
            color: isDark ? const Color(0xFFA78BFA) : _violet600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No items found',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? _D.textPrimary : _textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap + Add Item to get started',
          style: TextStyle(fontSize: 13, color: isDark ? _D.textSecondary : _textSecondary),
        ),
      ],
    ),
  );

  // ── Item row (simple list style) ──────────────────────────────────────────
  Widget _buildItemCard(ItemModel item, bool isDark) {
    final (icon, iconColor, iconBg) = _catMeta(item.category, isDark);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? _D.textPrimary : _textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item.unit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? _D.textSecondary : _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? _D.textSecondary : _textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _showAddEditSheet(item: item),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: isDark ? const Color(0xFFA78BFA) : _violet600,
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => _confirmDelete(item),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: isDark ? const Color(0xFFF87171) : _danger,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: item.isActive,
            activeColor: isDark ? const Color(0xFFA78BFA) : _violet600,
            onChanged: (v) => _toggleActive(item, v),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddEditItemSheet extends StatefulWidget {
  const _AddEditItemSheet({
    this.item,
    required this.onSaved,
    required this.onError,
  });
  final ItemModel? item;
  final VoidCallback onSaved;
  final void Function(dynamic) onError;

  @override
  State<_AddEditItemSheet> createState() => _AddEditItemSheetState();
}

class _AddEditItemSheetState extends State<_AddEditItemSheet> {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet500 = Color(0xFF6C42F5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _divider = Color(0xFFEEEBFA);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _success = Color(0xFF0F7B0F);
  static const _successSoft = Color(0xFFE6F4EA);

  final _nameCtrl = TextEditingController();
  String _unit = 'piece';
  String _category = 'roti';
  bool _isActive = true;
  bool _saving = false;

  static const _units = ['piece', 'bowl', 'plate', 'glass', 'other'];
  static const _categories = ['roti', 'sabji', 'dal', 'rice', 'other'];

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    if (i != null) {
      _nameCtrl.text = i.name;
      _unit = i.unit;
      _category = i.category;
      _isActive = i.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      AppSnackbar.error(context, 'Name is required');
      return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'unit': _unit,
        'category': _category,
        'isActive': _isActive,
      };
      if (widget.item != null) {
        await ItemApi.update(widget.item!.id, body);
      } else {
        await ItemApi.create(body);
      }
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) widget.onError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _D.surface : _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? _D.border : _divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? _D.violet100 : _violet100,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFFA78BFA) : _violet700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? 'Edit Item' : 'Add Menu Item',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? _D.textPrimary : _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name field
            _sheetField(_nameCtrl, 'Item Name', Icons.restaurant_outlined, isDark: isDark),
            const SizedBox(height: 18),

            // Unit chips
            _sheetLabel('Unit', isDark),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _units
                  .map(
                    (u) => _ChoiceChip(
                      label: u,
                      selected: _unit == u,
                      onTap: () => setState(() => _unit = u),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Category chips
            _sheetLabel('Category', isDark),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories
                  .map(
                    (c) => _ChoiceChip(
                      label: c[0].toUpperCase() + c.substring(1),
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Status toggle row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141625) : _violet50,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: isDark ? const Color(0xFF2F3347) : _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isActive
                          ? (isDark ? const Color(0xFF0F2A1C) : _successSoft)
                          : (isDark ? _D.divider : _divider),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _isActive
                          ? Icons.check_circle_outline_rounded
                          : Icons.cancel_outlined,
                      size: 16,
                      color: _isActive
                          ? (isDark ? const Color(0xFF4ADE80) : _success)
                          : (isDark ? _D.textSecondary : _textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isActive ? 'Item is Active' : 'Item is Inactive',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? _D.textPrimary : _textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isActive = !_isActive),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 26,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _isActive ? _violet600 : (isDark ? const Color(0xFF242238) : const Color(0xFFD0C8E8)),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: _isActive
                              ? _violet700
                              : (isDark ? const Color(0xFF3B335C) : const Color(0xFFB0A8D0)),
                          width: 1.5,
                        ),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: _isActive
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isActive
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            size: 10,
                            color: _isActive
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
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_violet700, _violet500],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.transparent : _violet600.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isEdit
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.add_circle_outline_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEdit ? 'Save Changes' : 'Add Item',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    required bool isDark,
  }) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFFF8FAFC) : _textPrimary,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : _textSecondary),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, size: 17, color: isDark ? const Color(0xFFA78BFA) : _violet600),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: isDark ? const Color(0xFF141625) : _violet50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: isDark ? const Color(0xFF2F3347) : _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _violet500, width: 1.5),
      ),
    ),
  );

  Widget _sheetLabel(String text, bool isDark) => Row(
    children: [
      Container(
        width: 3,
        height: 12,
        decoration: BoxDecoration(
          color: _violet600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? _D.textSecondary : _textSecondary,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice chip
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _border = Color(0xFFE4DFF7);
  static const _textPrimary = Color(0xFF1A0E45);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _violet600
              : (isDark ? const Color(0xFF141625) : _violet50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _violet700
                : (isDark ? const Color(0xFF2F3347) : _border),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : (isDark ? _D.textPrimary : _textPrimary),
          ),
        ),
      ),
    );
  }
}
