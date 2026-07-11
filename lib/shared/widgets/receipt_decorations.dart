import 'package:flutter/material.dart';

/// Paints a zigzag "torn receipt edge" — used at the bottom of the
/// nutrition-label hero card on the Dashboard.
class ZigzagEdge extends StatelessWidget {
  final Color color;
  final double height;
  final double toothWidth;

  const ZigzagEdge({
    super.key,
    required this.color,
    this.height = 14,
    this.toothWidth = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ZigzagPainter(color: color, toothWidth: toothWidth),
      ),
    );
  }
}

class _ZigzagPainter extends CustomPainter {
  final Color color;
  final double toothWidth;

  _ZigzagPainter({required this.color, required this.toothWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);

    final teeth = (size.width / toothWidth).ceil();
    for (int i = teeth; i >= 0; i--) {
      final x = i * toothWidth;
      final y = i.isEven ? size.height : 0.0;
      path.lineTo(x, y);
    }
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ZigzagPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.toothWidth != toothWidth;
}

/// A small pill button with a dashed border — used for the PDF export
/// action on Meal Plan, matching the "ticket stub" dashed styling from
/// the design mockup.
class DashedButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const DashedButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(color: color, radius: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

final Color color;
final double height;

const BarcodeStrip({super.key, required this.color, this.height = 16});

// Fixed pseudo-random-looking widths for a consistent barcode look.
static const List<double> _widths = [
2, 1, 3, 1, 2, 1, 2, 3, 1, 2, 1, 3, 2, 1, 2, 1, 3, 1, 2, 2,
];

@override
Widget build(BuildContext context) {
return SizedBox(
height: height,
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: _widths
    .map((w) => Container(
width: w,
height: height,
margin: const EdgeInsets.symmetric(horizontal: 1),
color: color,
))
    .toList(),
),
);
}
}