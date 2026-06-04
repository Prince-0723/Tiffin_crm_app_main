import 'package:flutter/material.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../items/data/item_api.dart';
import '../../../items/models/item_model.dart';
import '../../data/plan_api.dart';
import '../../models/plan_model.dart';

const List<String> _planTypes = ['monthly', 'weekly', 'daily'];
const List<String> _slotLabels = ['breakfast', 'lunch', 'dinner', 'evening'];

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key, this.plan});
  final PlanModel? plan;

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
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
  static const _warning = Color(0xFFBA7517);
  static const _warningSoft = Color(0xFFFAEEDA);

  // ── Controllers ───────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  late String _planType;
  String? _color;
  final Set<String> _selectedSlots = {};
  final Map<String, List<MealSlotItemModel>> _slotItems = {};
  bool _isActive = true;
  bool _saving = false;
  List<ItemModel> _items = [];
  bool _didAutoFillDefaults = false;

  bool get _isNewPlan => widget.plan == null;

  List<MealSlotItemModel> _defaultItemsForSlot() {
    return _items
        .map(
          (i) => MealSlotItemModel(
            itemId: i.id,
            itemName: i.name,
            quantity: 1,
            unitPrice: i.unitPrice,
          ),
        )
        .toList();
  }

  void _ensureDefaultItemsForSlot(String slot) {
    if (!_isNewPlan) return;
    if (_items.isEmpty) return;
    final existing = _slotItems[slot];
    if (existing != null && existing.isNotEmpty) return;
    _slotItems[slot] = _defaultItemsForSlot();
  }

  // ── Slot meta ─────────────────────────────────────────────────────────────
  static (IconData, Color, Color) _slotMeta(String slot) {
    switch (slot) {
      case 'breakfast':
        return (Icons.wb_sunny_rounded, Color(0xFF854F0B), Color(0xFFFAEEDA));
      case 'lunch':
        return (Icons.light_mode_rounded, Color(0xFF3B6D11), Color(0xFFEAF3DE));
      case 'dinner':
        return (
          Icons.nights_stay_rounded,
          Color(0xFF4C2DB8),
          Color(0xFFEDE8FD),
        );
      case 'evening':
        return (Icons.local_cafe_rounded, Color(0xFF993556), Color(0xFFFBEAF0));
      default:
        return (Icons.restaurant_rounded, Color(0xFF7B6DAB), Color(0xFFEEEBFA));
    }
  }

  static (IconData, Color) _planTypeMeta(String type) {
    switch (type) {
      case 'monthly':
        return (Icons.calendar_month_rounded, Color(0xFF4C2DB8));
      case 'weekly':
        return (Icons.date_range_rounded, Color(0xFF0F6E56));
      case 'daily':
        return (Icons.today_rounded, Color(0xFF854F0B));
      default:
        return (Icons.event_rounded, Color(0xFF7B6DAB));
    }
  }

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    if (p != null) {
      _nameCtrl.text = p.planName;
      _priceCtrl.text = p.price.toStringAsFixed(0);
      _planType = p.planType;
      _color = p.color;
      _isActive = p.isActive;
      for (final slot in p.mealSlots) {
        _selectedSlots.add(slot.slot);
        _slotItems[slot.slot] = List.from(slot.items);
      }
    } else {
      _planType = 'monthly';
    }
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final list = await ItemApi.list(limit: 100, isActive: true);
      if (mounted) {
        setState(() {
          _items = list;
          // Auto-fill defaults once for new plans (and only for empty slots).
          if (_isNewPlan && !_didAutoFillDefaults) {
            for (final slot in _selectedSlots) {
              _ensureDefaultItemsForSlot(slot);
            }
            _didAutoFillDefaults = true;
          }
        });
        // Resolve item names for any existing slot items that only have itemId.
        _resolveItemNames(list);
      }
    } catch (_) {}
  }

  void _resolveItemNames(List<ItemModel> items) {
    final nameMap = {for (final i in items) i.id: i.name};
    bool changed = false;
    for (final slot in _slotItems.keys) {
      final resolved = _slotItems[slot]!.map((si) {
        if ((si.itemName == null ||
                si.itemName!.isEmpty ||
                si.itemName!.startsWith('{')) &&
            nameMap.containsKey(si.itemId)) {
          changed = true;
          return MealSlotItemModel(
            itemId: si.itemId,
            itemName: nameMap[si.itemId],
            quantity: si.quantity,
            unitPrice: si.unitPrice,
          );
        }
        return si;
      }).toList();
      _slotItems[slot] = resolved;
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ── API (unchanged) ───────────────────────────────────────────────────────
  Map<String, dynamic> _buildBody() {
    final mealSlots = _selectedSlots.map((slot) {
      final items = _slotItems[slot] ?? [];
      return {'slot': slot, 'items': items.map((e) => e.toJson()).toList()};
    }).toList();
    return {
      'planName': _nameCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
      'planType': _planType,
      if (_color != null && _color!.isNotEmpty) 'color': _color,
      'mealSlots': mealSlots,
      'isActive': _isActive,
    };
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.error(context, 'Enter plan name');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = _buildBody();
      if (widget.plan != null) {
        await PlanApi.update(widget.plan!.id, body);
      } else {
        await PlanApi.create(body);
      }
      if (mounted) {
        AppSnackbar.success(
          context,
          widget.plan != null ? 'Plan updated' : 'Plan created',
        );
        if (context.mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pickItemForSlot(String slot) async {
    if (_items.isEmpty) return;
    final item = await showModalBottomSheet<ItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemPickerSheet(items: _items),
    );
    if (item == null || !mounted) return;
    setState(() {
      _slotItems[slot] ??= [];
      _slotItems[slot]!.add(
        MealSlotItemModel(
          itemId: item.id,
          itemName: item.name,
          quantity: 1,
          unitPrice: item.unitPrice,
        ),
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.plan != null;
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
        title: Text(
          isEdit ? 'Edit Plan' : 'Create Plan',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(context).padding.bottom + 40,
          ),
          children: [
            // ── Plan details ───────────────────────────────────────────────
            _sectionLabel('Plan Details'),
            const SizedBox(height: 10),
            _VioletField(
              controller: _nameCtrl,
              label: 'Plan Name',
              icon: Icons.edit_note_rounded,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            _VioletField(
              controller: _priceCtrl,
              label: 'Price (₹)',
              icon: Icons.currency_rupee_rounded,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),

            const SizedBox(height: 22),

            // ── Plan type ──────────────────────────────────────────────────
            _sectionLabel('Plan Type'),
            const SizedBox(height: 10),
            Row(
              children: _planTypes.map((t) {
                final selected = _planType == t;
                final (icon, color) = _planTypeMeta(t);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: t != _planTypes.last ? 8 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _planType = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? _violet600 : _surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: selected ? _violet700 : _border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: selected ? Colors.white : color,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              t[0].toUpperCase() + t.substring(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : _textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 22),

            // ── Active toggle (edit only) ──────────────────────────────────
            if (isEdit) ...[
              _sectionLabel('Status'),
              const SizedBox(height: 10),
              _buildStatusToggle(),
              const SizedBox(height: 22),
            ],

            // ── Meal slots selector ────────────────────────────────────────
            _sectionLabel('Meal Slots'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slotLabels.map((slot) {
                final sel = _selectedSlots.contains(slot);
                final (icon, iconColor, iconBg) = _slotMeta(slot);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) {
                      _selectedSlots.remove(slot);
                      _slotItems.remove(slot);
                    } else {
                      _selectedSlots.add(slot);
                      // Auto-fill default menu items so user doesn't add manually.
                      _ensureDefaultItemsForSlot(slot);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? iconBg : _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? iconColor.withValues(alpha: 0.4) : _border,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 15,
                          color: sel ? iconColor : _textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          slot[0].toUpperCase() + slot.substring(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? iconColor : _textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Slot item cards ────────────────────────────────────────────
            if (_selectedSlots.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionLabel('Slot Items'),
              const SizedBox(height: 10),
              ..._selectedSlots.map((slot) => _buildSlotCard(slot)),
            ],

            const SizedBox(height: 32),

            // ── Save button ────────────────────────────────────────────────
            _saveButton(isEdit),
          ],
        ),
      ),
    );
  }

  // ── Item name resolver ──────────────────────────────────────────────────────
  String _resolvedName(MealSlotItemModel it) {
    final name = it.itemName ?? '';
    if (name.isNotEmpty && !name.startsWith('{')) return name;
    // Try to find from loaded items list
    final found = _items.where((i) => i.id == it.itemId).toList();
    if (found.isNotEmpty) return found.first.name;
    return 'Item (${it.itemId.length > 8 ? it.itemId.substring(0, 8) : it.itemId}...)';
  }

  // ── Slot card ─────────────────────────────────────────────────────────────
  Widget _buildSlotCard(String slot) {
    final items = _slotItems[slot] ?? [];
    final (icon, iconColor, iconBg) = _slotMeta(slot);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _violet900.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Slot header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  slot[0].toUpperCase() + slot.substring(1),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
                const Spacer(),
                // Item count badge
                if (items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _violet100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length} item${items.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _violet700,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _pickItemForSlot(slot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _violet600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Empty state
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: _textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'No items added yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          // Items list
          else
            ...items.asMap().entries.map((e) {
              final idx = e.key;
              final it = e.value;
              final isLast = idx == items.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        // Item avatar
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _violet50,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: _border),
                          ),
                          child: Center(
                            child: Text(
                              _resolvedName(it).isNotEmpty
                                  ? _resolvedName(it)[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _violet700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _resolvedName(it),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Qty: ${it.quantity}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Qty controls
                        Container(
                          decoration: BoxDecoration(
                            color: _violet50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _qtyBtn(Icons.remove_rounded, () {
                                setState(() {
                                  final list = _slotItems[slot]!;
                                  if (it.quantity > 1) {
                                    list[idx] = MealSlotItemModel(
                                      itemId: it.itemId,
                                      itemName: it.itemName,
                                      quantity: it.quantity - 1,
                                      unitPrice: it.unitPrice,
                                    );
                                  } else {
                                    list.removeAt(idx);
                                  }
                                });
                              }),
                              Container(
                                width: 28,
                                alignment: Alignment.center,
                                child: Text(
                                  '${it.quantity}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                              _qtyBtn(Icons.add_rounded, () {
                                setState(() {
                                  final list = _slotItems[slot]!;
                                  list[idx] = MealSlotItemModel(
                                    itemId: it.itemId,
                                    itemName: it.itemName,
                                    quantity: it.quantity + 1,
                                    unitPrice: it.unitPrice,
                                  );
                                });
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Delete
                        GestureDetector(
                          onTap: () =>
                              setState(() => _slotItems[slot]!.removeAt(idx)),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _dangerSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 15,
                              color: _danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      color: _divider,
                      height: 1,
                      indent: 58,
                      endIndent: 14,
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 32,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Icon(icon, size: 14, color: _violet600),
    ),
  );

  // ── Status toggle ─────────────────────────────────────────────────────────
  Widget _buildStatusToggle() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            color: _isActive ? _successSoft : _divider,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _isActive
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            size: 18,
            color: _isActive ? _success : _textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isActive ? 'Active' : 'Inactive',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              Text(
                _isActive
                    ? 'Plan is visible to customers'
                    : 'Plan is hidden from customers',
                style: const TextStyle(fontSize: 11, color: _textSecondary),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _isActive = !_isActive),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _isActive ? _violet600 : const Color(0xFFD0C8E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isActive ? _violet700 : const Color(0xFFB0A8D0),
                width: 1.5,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: _isActive
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
                  _isActive ? Icons.check_rounded : Icons.close_rounded,
                  size: 12,
                  color: _isActive ? _violet600 : const Color(0xFFB0A8D0),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Row(
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
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _saveButton(bool isEdit) => SizedBox(
    height: 52,
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
            color: _violet600.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: const Color(0xFFCDBEFA),
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
                    isEdit ? 'Update Plan' : 'Create Plan',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Violet field
// ─────────────────────────────────────────────────────────────────────────────

class _VioletField extends StatelessWidget {
  const _VioletField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  static const _violet600 = Color(0xFF5B35D5);
  static const _violet500 = Color(0xFF6C42F5);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _border = Color(0xFFE4DFF7);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _textPrimary,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: _textSecondary),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, size: 18, color: _violet600),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: _violet50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _violet500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFD93025)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFD93025), width: 1.5),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Item picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ItemPickerSheet extends StatelessWidget {
  const _ItemPickerSheet({required this.items});
  final List<ItemModel> items;

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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _violet100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.restaurant_outlined,
                          size: 18,
                          color: _violet700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Select Item',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${items.length} available',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: _divider, height: 1),
                ],
              ),
            ),

            // Items list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, item),
                      borderRadius: BorderRadius.circular(12),
                      splashColor: _violet100,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _violet50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _violet100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  item.name.isNotEmpty
                                      ? item.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _violet700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  if (item.unit.trim().isNotEmpty)
                                    Text(
                                      item.unit,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _violet600,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
