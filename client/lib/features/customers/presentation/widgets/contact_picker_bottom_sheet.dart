import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';

class ContactPickerBottomSheet extends StatefulWidget {
  const ContactPickerBottomSheet({super.key, required this.onContactSelected});

  final void Function(String name, String phone) onContactSelected;

  @override
  State<ContactPickerBottomSheet> createState() =>
      _ContactPickerBottomSheetState();
}

class _ContactPickerBottomSheetState extends State<ContactPickerBottomSheet> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      if (mounted) {
        setState(() {
          _contacts = contacts
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
          _filteredContacts = List.from(_contacts);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load contacts';
          _loading = false;
        });
      }
    }
  }

  void _filterContacts() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredContacts = List.from(_contacts));
    } else {
      setState(() {
        _filteredContacts = _contacts.where((c) {
          final nameMatch = c.displayName.toLowerCase().contains(query);
          final phoneMatch = c.phones.any(
            (p) => p.number
                .replaceAll(RegExp(r'\D'), '')
                .contains(query.replaceAll(RegExp(r'\D'), '')),
          );
          return nameMatch || phoneMatch;
        }).toList();
      });
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String _stripPhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  void _selectContact(Contact contact) {
    if (contact.phones.isEmpty) {
      widget.onContactSelected(contact.displayName, '');
      Navigator.of(context).pop();
    } else if (contact.phones.length == 1) {
      widget.onContactSelected(
        contact.displayName,
        _stripPhone(contact.phones.first.number),
      );
      Navigator.of(context).pop();
    } else {
      _showPhonePicker(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.9;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const BottomSheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(child: Text(_error))
                : _filteredContacts.isEmpty
                ? Center(
                    child: Text(
                      'No contacts found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final avatarColor = colorFromName(contact.displayName);
                      return AnimatedListItem(
                        index: index,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: avatarColor,
                            child: Text(
                              _initials(contact.displayName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text(contact.displayName),
                          subtitle: Text(
                            contact.phones.isNotEmpty
                                ? contact.phones.first.number
                                : 'No phone',
                          ),
                          trailing: contact.phones.length > 1
                              ? const Icon(Icons.arrow_drop_down)
                              : null,
                          onTap: () => _selectContact(contact),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPhonePicker(Contact contact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select phone number',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ...contact.phones.map(
              (phone) => ListTile(
                title: Text(phone.number),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onContactSelected(
                    contact.displayName,
                    _stripPhone(phone.number),
                  );
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
