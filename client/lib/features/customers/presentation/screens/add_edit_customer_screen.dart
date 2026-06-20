import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../models/customer_model.dart';
import '../../data/customer_api.dart';
import '../../utils/customer_location_payload.dart';
import '../widgets/contact_picker_bottom_sheet.dart';
import '../widgets/contacts_permission_sheet.dart';
import '../widgets/customer_location_pick_sheet.dart';
import '../widgets/zone_autocomplete_field.dart';

class AddEditCustomerScreen extends StatefulWidget {
  const AddEditCustomerScreen({super.key, this.customer});

  final CustomerModel? customer;

  bool get _isEditMode => customer != null;

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _areaController;
  late final TextEditingController _zoneController;
  bool _isSaving = false;
  double? _mapLat;
  double? _mapLng;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _areaController = TextEditingController(text: c?.area ?? '');
    _zoneController = TextEditingController(text: c?.zone ?? '');
    final loc = c?.location;
    if (loc != null && (loc.lat != 0 || loc.lng != 0)) {
      _mapLat = loc.lat;
      _mapLng = loc.lng;
    }
  }

  bool get _hasMapPin => hasValidCustomerMapPin(_mapLat, _mapLng);

  Future<void> _openLocationPicker() async {
    LatLng? initial;
    if (_hasMapPin) {
      initial = LatLng(_mapLat!, _mapLng!);
    }
    final result = await showCustomerLocationPickSheet(
      context,
      initialPosition: initial,
      initialAddress: _addressController.text.trim(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _mapLat = result.lat;
      _mapLng = result.lng;
      _addressController.text = result.address;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    final status = await Permission.contacts.request();
    if (!mounted) return;
    if (status.isGranted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ContactPickerBottomSheet(
          onContactSelected: (name, phone) {
            _nameController.text = name;
            final digits = phone.replaceAll(RegExp(r'\D'), '');
            _phoneController.text = digits.length > 10
                ? digits.substring(digits.length - 10)
                : digits;
            AppSnackbar.success(context, 'Contact imported successfully');
          },
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (ctx) =>
            ContactsPermissionSheet(onCancel: () => Navigator.pop(ctx)),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');

    setState(() => _isSaving = true);
    try {
      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': phone,
        'address': _addressController.text.trim(),
        'whatsapp': phone,
        'area': _areaController.text.trim(),
        'zone': _zoneController.text.trim(),
        if (!widget._isEditMode) 'status': 'active',
      };
      if (_hasMapPin) {
        body.addAll(
          buildCustomerLocationUpdateBody(
            lat: _mapLat!,
            lng: _mapLng!,
            address: _addressController.text.trim(),
          ),
        );
      }
      final saved = widget._isEditMode
          ? await CustomerApi.update(widget.customer!.id, body)
          : await CustomerApi.create(body);
      if (mounted) {
        AppSnackbar.success(
          context,
          widget._isEditMode ? 'Customer updated' : 'Customer added',
        );
        context.pop(saved);
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xFFEDE9F8),
      appBar: AppBar(
        // AppBarTheme in app_theme.dart already sets backgroundColor to AppColors.primary
        // and foregroundColor to AppColors.onPrimary — no overrides needed here.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget._isEditMode ? 'Edit Customer' : 'Add Customer',
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).padding.bottom + 40,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget._isEditMode) ...[
                _ImportContactButton(onTap: _importFromContacts),
                const SizedBox(height: 20),
                const _OrDivider(),
                const SizedBox(height: 20),
              ],
              const _SectionLabel(text: 'Customer details'),
              const SizedBox(height: 10),
              _FormCard(
                children: [
                  _Field(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                    required: true,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      return null;
                    },
                  ),
                  _Field(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    required: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (d.isEmpty) return 'Phone number is required';
                      return null;
                    },
                  ),
                  _Field(
                    controller: _areaController,
                    label: 'Area',
                    hint: 'Optional',
                    icon: Icons.location_city_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (_) => null,
                  ),
                  _Field(
                    controller: _addressController,
                    label: 'Address',
                    icon: Icons.home_outlined,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (_) => null,
                  ),
                  ZoneAutocompleteField(
                    controller: _zoneController,
                    onPlaceSelected: (_, latLng) {
                      if (!_hasMapPin) {
                        setState(() {
                          _mapLat = latLng.latitude;
                          _mapLng = latLng.longitude;
                        });
                      }
                    },
                  ),

                ],
              ),
              const SizedBox(height: 12),
              Text(
                'WhatsApp uses the same number as phone.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          widget._isEditMode
                              ? 'Update Customer'
                              : 'Save Customer',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting private widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ImportContactButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ImportContactButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.primary.withOpacity(0.35),
              width: 1.2,
            ),
          ),
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Import from Contacts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;
    final hintColor = Theme.of(context).hintColor;
    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR FILL MANUALLY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: hintColor,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(color: dividerColor, thickness: 1)),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool required;
  final bool isLast;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.required = false,
    this.isLast = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;

    BorderSide enabledSide = BorderSide(color: dividerColor, width: 1);
    BorderSide focusedSide = BorderSide(color: cs.primary.withOpacity(0.5), width: 1);
    BorderSide errorSide = BorderSide(color: cs.error, width: 1);
    BorderSide focusedErrorSide = BorderSide(color: cs.error, width: 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            // Override the global InputDecorationTheme for this flat card style
            filled: false,
            labelText: required ? '$label *' : label,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withOpacity(0.6)),
            labelStyle: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelStyle: TextStyle(
              fontSize: 12,
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(icon, size: 20, color: cs.onSurfaceVariant),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            errorStyle: const TextStyle(fontSize: 0, height: 0),
            border: InputBorder.none,
            enabledBorder: !isLast
                ? UnderlineInputBorder(borderSide: enabledSide)
                : InputBorder.none,
            focusedBorder: !isLast
                ? UnderlineInputBorder(borderSide: focusedSide)
                : InputBorder.none,
            errorBorder: UnderlineInputBorder(borderSide: errorSide),
            focusedErrorBorder: UnderlineInputBorder(borderSide: focusedErrorSide),
          ),
        ),
        if (validator != null)
          _ErrorBanner(controller: controller, validator: validator!),
      ],
    );
  }
}

class _ErrorBanner extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?) validator;
  const _ErrorBanner({required this.controller, required this.validator});

  @override
  State<_ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<_ErrorBanner> {
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validate);
    super.dispose();
  }

  void _validate() {
    final err = widget.validator(widget.controller.text);
    if (err != _error) setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) {
    if (_error == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: cs.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}