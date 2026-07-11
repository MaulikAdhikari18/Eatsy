import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// A row styled like a receipt/invoice line: "Label ........ 312"
/// with the value rendered in monospace. Used throughout the
/// nutrition-label design system (Food Log, Goals, Meal Plan).
class DottedLeaderRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;
  final double labelFontSize;
  final double valueFontSize;
  final FontWeight labelFontWeight;

  const DottedLeaderRow({
    super.key,
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
    this.labelFontSize = 13,
    this.valueFontSize = 13,
    this.labelFontWeight = FontWeight.w500,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: labelFontSize,
            fontWeight: labelFontWeight,
            color: labelColor ?? colors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '.' * 120,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: colors.divider,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: AppFonts.mono(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w600,
            color: valueColor ?? colors.textPrimary,
          ),
        ),
      ],
    );
  }
}