import 'package:flutter/material.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/zone_api.dart';
import '../../models/zone_model.dart';

class AddEditZoneScreen extends StatefulWidget {
  const AddEditZoneScreen({super.key, this.zone});
  final ZoneModel? zone;

  @override
  State<AddEditZoneScreen> createState() => _AddEditZoneScreenState();
}

class _AddEditZoneScreenState extends State<AddEditZoneScreen> {
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

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _colorCtrl;
  bool _isActive = true;
  bool _saving = false;

  // Color presets
  static const _colorPresets = [
    '#5B35D5',
    '#0057FF',
    '#0F7B0F',
    '#D93025',
    '#BA7517',
    '#185FA5',
    '#993556',
    '#0F6E56',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.zone?.name ?? '');
    _descCtrl = TextEditingController(text: widget.zone?.description ?? '');
    _colorCtrl = TextEditingController(text: widget.zone?.color ?? '');
    _isActive = widget.zone?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  // ── API (unchanged) ───────────────────────────────────────────────────────
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.error(context, 'Zone name is required');
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.zone == null) {
        await ZoneApi.create(
          ZoneModel(
            id: '',
            name: name,
            description: _descCtrl.text.trim(),
            color: _colorCtrl.text.trim(),
            isActive: _isActive,
          ).toCreateJson(),
        );
      } else {
        await ZoneApi.update(
          widget.zone!.id,
          ZoneModel(
            id: widget.zone!.id,
            name: name,
            description: _descCtrl.text.trim(),
            color: _colorCtrl.text.trim(),
            isActive: _isActive,
          ).toUpdateJson(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivate() async {
    final id = widget.zone?.id;
    if (id == null || id.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ZoneApi.deactivate(id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return _violet600;
  }

  String _zoneName() => _nameCtrl.text.trim();
  String _initial() {
    final n = _zoneName();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.zone != null;

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
          isEdit ? 'Edit Zone' : 'Create Zone',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          if (isEdit)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _saving ? null : _deactivate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'Deactivate',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
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
              // ── Preview card ──────────────────────────────────────────────
              _buildPreviewCard(),
              const SizedBox(height: 24),

              // ── Zone details ──────────────────────────────────────────────
              _sectionLabel('Zone Details'),
              const SizedBox(height: 10),
              _VioletField(
                controller: _nameCtrl,
                label: 'Zone Name',
                icon: Icons.location_on_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              _VioletField(
                controller: _descCtrl,
                label: 'Description (optional)',
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),

              const SizedBox(height: 22),

              // ── Color picker ──────────────────────────────────────────────
              _sectionLabel('Zone Color'),
              const SizedBox(height: 10),
              _buildColorSection(),

              const SizedBox(height: 22),

              // ── Status ────────────────────────────────────────────────────
              _sectionLabel('Status'),
              const SizedBox(height: 10),
              _buildStatusToggle(),

              const SizedBox(height: 32),

              // ── Save button ───────────────────────────────────────────────
              _saveButton(isEdit),
            ],
          ),
        ),
      ),
    );
  }

  // ── Preview card ──────────────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    final accentColor = _colorCtrl.text.trim().isNotEmpty
        ? _parseColor(_colorCtrl.text.trim())
        : _violet600;

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
          // Color accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Row(
              children: [
                // Zone avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _initial(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _zoneName().isEmpty ? 'Zone Name' : _zoneName(),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _zoneName().isEmpty
                              ? _textSecondary
                              : _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _descCtrl.text.trim().isEmpty
                            ? 'No description'
                            : _descCtrl.text.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _descCtrl.text.trim().isEmpty
                              ? _textSecondary.withValues(alpha: 0.5)
                              : _textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _isActive ? _successSoft : _dangerSoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _isActive
                                ? _success.withValues(alpha: 0.3)
                                : _danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: _isActive ? _success : _danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _isActive ? _success : _danger,
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

  // ── Color section ─────────────────────────────────────────────────────────
  Widget _buildColorSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Color presets
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _colorPresets.map((hex) {
          final color = _parseColor(hex);
          final selected =
              _colorCtrl.text.trim().toLowerCase() == hex.toLowerCase();
          return GestureDetector(
            onTap: () {
              setState(() => _colorCtrl.text = hex);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? _textPrimary : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      // Custom hex input
      _VioletField(
        controller: _colorCtrl,
        label: 'Custom color hex (optional)',
        hint: '#FF0000',
        icon: Icons.palette_outlined,
        onChanged: (_) => setState(() {}),
      ),
    ],
  );

  // ── Status toggle ─────────────────────────────────────────────────────────
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
                    ? 'Zone is visible and accepting deliveries'
                    : 'Zone is hidden from delivery assignments',
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
                        : Icons.add_location_alt_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Save Changes' : 'Create Zone',
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
