import 'package:flutter/material.dart';

/// Flat storefront: sign slab, segmented awning with vertical grooves,
/// facade with square window (left) and tall door (right) in [cutoutColor].
class StorefrontLogoIcon extends StatelessWidget {
  const StorefrontLogoIcon({
    super.key,
    this.size = 44,
    required this.bodyColor,
    required this.cutoutColor,
  });

  final double size;
  final Color bodyColor;
  final Color cutoutColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StorefrontPainter(
          bodyColor: bodyColor,
          cutoutColor: cutoutColor,
        ),
      ),
    );
  }
}

class _StorefrontPainter extends CustomPainter {
  _StorefrontPainter({
    required this.bodyColor,
    required this.cutoutColor,
  });

  final Color bodyColor;
  final Color cutoutColor;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    final ink = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cut = Paint()
      ..color = cutoutColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final fl = w * 0.10;
    final fr = w * 0.90;
    final span = fr - fl;
    final facadeTop = h * 0.355;
    final facadeBot = h * 0.94;
    final rFac = Radius.circular(w * 0.058);

    // Main facade block
    final facade =
        RRect.fromLTRBR(fl, facadeTop, fr, facadeBot, rFac);
    canvas.drawRRect(facade, ink);

    // Awning: five purple segments separated by groove stripes in cutoutColor
    final awBot = facadeTop + h * 0.012;
    final awInnerTop = h * 0.165;
    final gapW = w * 0.02;
    const nSeg = 5;
    final segW = (span - gapW * (nSeg - 1)) / nSeg;
    var xCursor = fl;
    for (var i = 0; i < nSeg; i++) {
      if (i > 0) {
        canvas.drawRect(
          Rect.fromLTRB(
            xCursor,
            awInnerTop + h * 0.015,
            xCursor + gapW,
            awBot - h * 0.015,
          ),
          cut,
        );
        xCursor += gapW;
      }
      final seg = RRect.fromLTRBR(
        xCursor,
        awInnerTop,
        xCursor + segW,
        awBot,
        Radius.circular(segW * 0.32),
      );
      canvas.drawRRect(seg, ink);
      xCursor += segW;
    }

    // Roof / sign slab
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * 0.07,
        h * 0.045,
        w * 0.93,
        awInnerTop + h * 0.025,
        Radius.circular(w * 0.045),
      ),
      ink,
    );

    // Window — left
    final winLeft = fl + w * 0.068;
    final winW = w * 0.245;
    final winTop = facadeTop + h * 0.11;
    final winH = h * 0.325;
    canvas.drawRRect(
      RRect.fromLTRBR(
        winLeft,
        winTop,
        winLeft + winW,
        winTop + winH,
        const Radius.circular(2),
      ),
      cut,
    );

    // Door — right strip
    final doorW = w * 0.175;
    final doorRight = fr - w * 0.058;
    final doorTop = facadeTop + h * 0.13;
    final doorBot = facadeBot - h * 0.058;
    canvas.drawRRect(
      RRect.fromLTRBR(
        doorRight - doorW,
        doorTop,
        doorRight,
        doorBot,
        const Radius.circular(2),
      ),
      cut,
    );
  }

  @override
  bool shouldRepaint(covariant _StorefrontPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.cutoutColor != cutoutColor;
}
