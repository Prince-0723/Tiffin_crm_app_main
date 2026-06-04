import 'package:flutter/material.dart';

import 'storefront_logo_icon.dart';

/// Sidebar header: white shop with façade cut-outs in header violet.
class DrawerStorefrontIcon extends StatelessWidget {
  const DrawerStorefrontIcon({
    super.key,
    this.size = 44,
    required this.headerBackgroundColor,
  });

  final double size;
  final Color headerBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return StorefrontLogoIcon(
      size: size,
      bodyColor: Colors.white,
      cutoutColor: headerBackgroundColor,
    );
  }
}
