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

/// A decorative row of variable-width bars mimicking a barcode —
/// purely visual, sits at the top of the nutrition-label hero card.
class BarcodeStrip extends StatelessWidget {
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