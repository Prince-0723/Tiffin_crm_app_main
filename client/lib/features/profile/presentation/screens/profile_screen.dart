import 'package:flutter/material.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/profile_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  // ── Controllers ───────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _initialized = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initialized = true;
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final data = await ProfileApi.getMe();
      if (mounted) {
        setState(() {
          _businessNameCtrl.text =
              data['businessName'] as String? ??
              data['tiffinCenterName'] as String? ??
              '';
          _ownerNameCtrl.text =
              data['name'] as String? ?? data['ownerName'] as String? ?? '';
          _phoneCtrl.text = data['phone'] as String? ?? '';
          final address = data['address'];
          if (address is Map<String, dynamic>) {
            _addressCtrl.text = address['street'] as String? ?? '';
            _cityCtrl.text = address['city'] as String? ?? '';
            _pincodeCtrl.text = address['pincode'] as String? ?? '';
          } else {
            _addressCtrl.text = address as String? ?? '';
            _cityCtrl.text = data['city'] as String? ?? '';
            _pincodeCtrl.text = data['pincode'] as String? ?? '';
          }
          _upiCtrl.text = data['upiId'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ProfileApi.updateProfile({
        'businessName': _businessNameCtrl.text.trim(),
        'name': _ownerNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'upiId': _upiCtrl.text.trim(),
      });
      if (mounted) {
        AppSnackbar.success(context, 'Profile updated successfully');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _initials {
    try {
      final name = _businessNameCtrl.text.trim();
      if (name.isEmpty) return '?';
      final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    } catch (_) {
      return '?';
    }
  }

  String _safe(TextEditingController ctrl) {
    try {
      return ctrl.text;
    } catch (_) {
      return '';
    }
  }

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
          'Business Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: (!_initialized || _loading)
          ? Center(
              child: CircularProgressIndicator(
                color: _violet600,
                strokeWidth: 2.5,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                20,
                16,
                MediaQuery.of(context).padding.bottom + 40,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildIdentityCard(),
                    const SizedBox(height: 24),

                    _sectionLabel('Business Details'),
                    const SizedBox(height: 10),
                    _VioletField(
                      controller: _businessNameCtrl,
                      label: 'Business / Tiffin Center Name',
                      icon: Icons.storefront_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _VioletField(
                      controller: _ownerNameCtrl,
                      label: 'Owner Name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    _VioletField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 22),

                    _sectionLabel('Address'),
                    const SizedBox(height: 10),
                    _VioletField(
                      controller: _addressCtrl,
                      label: 'Street Address',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _VioletField(
                            controller: _cityCtrl,
                            label: 'City',
                            icon: Icons.location_city_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _VioletField(
                            controller: _pincodeCtrl,
                            label: 'Pincode',
                            icon: Icons.pin_drop_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
                    _sectionLabel('UPI for customers'),
                    const SizedBox(height: 6),
                    Text(
                      'Shown in the customer app so they can pay you (e.g. yourname@paytm).',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSecondary.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _VioletField(
                      controller: _upiCtrl,
                      label: 'UPI ID',
                      icon: Icons.currency_rupee_rounded,
                      hint: 'e.g. vendor@oksbi',
                    ),

                    const SizedBox(height: 32),
                    _saveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Identity hero card ────────────────────────────────────────────────────
  Widget _buildIdentityCard() => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _violet900.withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        // Top accent bar
        Container(
          height: 4,
          decoration: const BoxDecoration(
            color: _violet700,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Row(
            children: [
              // ── Square avatar with user icon + initials badge ──────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main square avatar
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _violet700.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _violet700.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 30,
                        color: _violet700.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  // Initials badge bottom-right
                  Positioned(
                    bottom: -5,
                    right: -5,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _violet700,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _surface, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _initials,
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),

              // ── Info ───────────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _safe(_businessNameCtrl).isEmpty
                          ? 'Your Business'
                          : _safe(_businessNameCtrl),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _safe(_ownerNameCtrl).isEmpty
                          ? 'Owner name'
                          : '${_safe(_ownerNameCtrl)}  ·  ${_safe(_phoneCtrl)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 9),
                    // Active badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _successSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _success.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Active Account',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _success,
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

        // ── Meta row ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Divider(color: _divider, height: 1, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Row(
            children: [
              // Location
              Icon(Icons.location_on_outlined, size: 13, color: _textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: _LocationText(
                  city: _safe(_cityCtrl),
                  address: _safe(_addressCtrl),
                ),
              ),
              const SizedBox(width: 16),
              // Profile completeness
              Icon(Icons.task_alt_rounded, size: 13, color: _success),
              const SizedBox(width: 4),
              const Text(
                'Profile complete',
                style: TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ],
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
  Widget _saveButton() => SizedBox(
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Save Profile',
                    style: TextStyle(
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
// Extension helper
// ─────────────────────────────────────────────────────────────────────────────

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

  final TextEditingController? controller;
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
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null) return const SizedBox.shrink();
    return TextFormField(
      controller: ctrl,
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
          color: _textSecondary.withValues(alpha: 0.5),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 18, color: _violet600),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _violet50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Location text helper (avoids .let() extension)
// ─────────────────────────────────────────────────────────────────────────────

class _LocationText extends StatelessWidget {
  const _LocationText({required this.city, required this.address});
  final String city;
  final String address;

  static const _textSecondary = Color(0xFF7B6DAB);

  @override
  Widget build(BuildContext context) {
    final parts = [city, address].where((s) => s.isNotEmpty).toList();
    final label = parts.isEmpty ? 'Location not set' : parts.join(', ');
    return Text(
      label,
      style: const TextStyle(fontSize: 12, color: _textSecondary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
