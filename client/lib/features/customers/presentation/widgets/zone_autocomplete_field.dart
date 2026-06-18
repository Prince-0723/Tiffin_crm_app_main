import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/routing/nominatim_geocode_service.dart';

/// Zone / area text field with debounced Nominatim place suggestions.
class ZoneAutocompleteField extends StatefulWidget {
  const ZoneAutocompleteField({
    super.key,
    required this.controller,
    this.onPlaceSelected,
  });

  final TextEditingController controller;
  final void Function(String label, LatLng latLng)? onPlaceSelected;

  @override
  State<ZoneAutocompleteField> createState() => _ZoneAutocompleteFieldState();
}

class _ZoneAutocompleteFieldState extends State<ZoneAutocompleteField> {
  Timer? _debounce;
  List<NominatimPlaceHit> _suggestions = [];
  bool _loading = false;
  bool _showDropdown = false;
  bool _suppressSearch = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (_suppressSearch) return;
    _debounce?.cancel();
    final q = widget.controller.text.trim();
    if (q.length < 2) {
      setState(() {
        _suggestions = [];
        _showDropdown = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch(q));
  }

  Future<void> _fetch(String q) async {
    if (q != widget.controller.text.trim()) return;
    setState(() {
      _loading = true;
      _showDropdown = true;
    });
    try {
      final hits = await NominatimGeocodeService.searchPlaces(q, limit: 5);
      if (!mounted || widget.controller.text.trim() != q) return;
      setState(() {
        _suggestions = hits;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _loading = false;
      });
    }
  }

  void _select(NominatimPlaceHit hit) {
    _suppressSearch = true;
    widget.controller.text = hit.displayName;
    _debounce?.cancel();
    setState(() {
      _showDropdown = false;
      _suggestions = [];
    });
    widget.onPlaceSelected?.call(hit.displayName, hit.latLng);
    _suppressSearch = false;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.controller.text.trim();
    final showPanel = _showDropdown && q.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2E),
          ),
          decoration: const InputDecoration(
            labelText: 'Delivery Zone',
            hintText: 'Optional',
            hintStyle: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
            labelStyle: TextStyle(
              fontSize: 13,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w500,
            ),
            floatingLabelStyle: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B21D4),
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(
              Icons.map_outlined,
              size: 20,
              color: Color(0xFF9E9E9E),
            ),
            filled: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF0F0F0), width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFCCBBEE), width: 1),
            ),
          ),
        ),
        if (showPanel) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6B21D4),
                          ),
                        ),
                      ),
                    )
                  : _suggestions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'No results found',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888888),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFF0F0F0),
                          ),
                          itemBuilder: (_, i) {
                            final hit = _suggestions[i];
                            return InkWell(
                              onTap: () => _select(hit),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.place_outlined,
                                      size: 18,
                                      color: Color(0xFF6B21D4),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        hit.displayName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1A1A2E),
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ],
    );
  }
}
