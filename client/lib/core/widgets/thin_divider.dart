import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ThinDivider extends StatelessWidget {
  const ThinDivider({super.key, this.indent, this.endIndent});

  final double? indent;
  final double? endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      thickness: 0.5,
      color: AppColors.border,
      indent: indent ?? 0,
      endIndent: endIndent ?? 0,
    );
  }
}
