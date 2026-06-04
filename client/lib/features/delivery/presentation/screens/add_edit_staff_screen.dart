import 'package:flutter/material.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/delivery_api.dart';
import '../../models/delivery_staff_model.dart';

class AddEditStaffScreen extends StatefulWidget {
  const AddEditStaffScreen({super.key, this.staff});
  final DeliveryStaffModel? staff;

  @override
  State<AddEditStaffScreen> createState() => _AddEditStaffScreenState();
}

class _AddEditStaffScreenState extends State<AddEditStaffScreen> {
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
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _success = Color(0xFF0F7B0F);
  static const _successSoft = Color(0xFFE6F4EA);

  // ── Controllers ───────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _areasCtrl = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    if (s != null) {
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phone;
      _areasCtrl.text = s.areas.join(', ');
      _isActive = s.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _areasCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      AppSnackbar.error(context, 'Name and phone are required');
      return;
    }
    final areasStr = _areasCtrl.text.trim();
    final areas = areasStr.isEmpty
        ? <String>[]
        : areasStr
              .split(',')
              .map((e) => e.trim())
              .where((s) => s.isNotEmpty)
              .toList();

    setState(() => _saving = true);
    try {
      final body = {
        'name': name,
        'phone': phone,
        'areas': areas,
        'isActive': _isActive,
      };
      if (widget.staff != null) {
        await DeliveryApi.updateStaff(widget.staff!.id, body);
      } else {
        await DeliveryApi.createStaff(body);
      }
      if (mounted) {
        AppSnackbar.success(
          context,
          widget.staff != null
              ? '${name} updated successfully'
              : '${name} added to staff',
        );
        if (context.mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.staff != null;

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
          isEdit ? 'Edit Staff Member' : 'Add Delivery Staff',
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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(context).padding.bottom + 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Identity preview card ─────────────────────────────────
              _buildPreviewCard(),
              const SizedBox(height: 24),

              // ── Personal info ─────────────────────────────────────────
              _sectionLabel('Personal Information'),
              const SizedBox(height: 10),
              _VioletField(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              _VioletField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 22),

              // ── Delivery areas ────────────────────────────────────────
              _sectionLabel('Delivery Areas'),
              const SizedBox(height: 10),
              _VioletField(
                controller: _areasCtrl,
                label: 'Areas (comma separated)',
                hint: 'e.g. Vijay Nagar, Palasia, Scheme 54',
                icon: Icons.map_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Separate multiple areas with a comma',
                  style: TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ),

              const SizedBox(height: 22),

              // ── Status ────────────────────────────────────────────────
              _sectionLabel('Status'),
              const SizedBox(height: 10),
              _buildStatusToggle(),

              const SizedBox(height: 32),

              // ── Save button ───────────────────────────────────────────
              _saveButton(isEdit),
            ],
          ),
        ),
      ),
    );
  }

  // ── Preview card ──────────────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _violet900.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top accent
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: _violet700,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Row(
              children: [
                // Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _violet100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _violet700,
                          ),
                        ),
                      ),
                    ),
                    // Active dot
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _isActive ? _success : _textSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: _surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Staff Name' : name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: name.isEmpty ? _textSecondary : _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        phone.isEmpty ? 'Phone number' : phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: phone.isEmpty
                              ? _textSecondary.withValues(alpha: 0.5)
                              : _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _isActive
                              ? _successSoft
                              : const Color(0xFFEEEBFA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _isActive
                                ? _success.withValues(alpha: 0.3)
                                : _border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: _isActive ? _success : _textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _isActive ? _success : _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status toggle card ────────────────────────────────────────────────────
  Widget _buildStatusToggle() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            color: _isActive ? _successSoft : const Color(0xFFEEEBFA),
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
        const SizedBox(width: 14),
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
                    ? 'Staff member is available for deliveries'
                    : 'Staff member will not receive new deliveries',
                style: const TextStyle(fontSize: 11, color: _textSecondary),
              ),
            ],
          ),
        ),
        Switch(
          value: _isActive,
          activeColor: _violet600,
          onChanged: (v) => setState(() => _isActive = v),
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
                        : Icons.person_add_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Update Staff Member' : 'Add Staff Member',
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
// Violet form field
// ─────────────────────────────────────────────────────────────────────────────

class _VioletField extends StatelessWidget {
  const _VioletField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

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
    maxLines: maxLines,
    onChanged: onChanged,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _textPrimary,
    ),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: _textSecondary),
      hintStyle: TextStyle(
        fontSize: 13,
        color: _textSecondary.withOpacity(0.5),
      ),
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
