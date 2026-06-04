import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../models/customer_model.dart';
import '../../data/customer_api.dart';
import '../widgets/contact_picker_bottom_sheet.dart';
import '../widgets/contacts_permission_sheet.dart';

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _areaController = TextEditingController(text: c?.area ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _areaController.dispose();
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
        if (!widget._isEditMode) 'status': 'active',
      };
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
    return Scaffold(
      backgroundColor: const Color(0xFFEDE9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B21D4),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget._isEditMode ? 'Edit Customer' : 'Add Customer',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
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
                _OrDivider(),
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
                    isLast: true,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (_) => null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'WhatsApp uses the same number as phone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6B21D4),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(
                      0xFF6B21D4,
                    ).withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7B6FA0),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFEEEDFE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF6B21D4).withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: const SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 20,
                  color: Color(0xFF6B21D4),
                ),
                SizedBox(width: 10),
                Text(
                  'Import from Contacts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B21D4),
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
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFCCBBEE), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR FILL MANUALLY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFCCBBEE), thickness: 1)),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B21D4).withValues(alpha: 0.06),
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2E),
          ),
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
            labelStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w500,
            ),
            floatingLabelStyle: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B21D4),
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9E9E9E)),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            errorStyle: const TextStyle(fontSize: 0, height: 0),
            border: InputBorder.none,
            enabledBorder: !isLast
                ? const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFF0F0F0), width: 1),
                  )
                : InputBorder.none,
            focusedBorder: !isLast
                ? const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFCCBBEE), width: 1),
                  )
                : InputBorder.none,
            errorBorder: !isLast
                ? const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935), width: 1),
                  )
                : const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935), width: 1),
                  ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
            ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE53935).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: Color(0xFFE53935),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB71C1C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
