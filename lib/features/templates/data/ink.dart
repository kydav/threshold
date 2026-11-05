import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Signature-pad PNGs: crop to the ink, and put two signers' initials side
/// by side in one box.
class InkImage {
  const InkImage._();

  /// Crops a pad PNG to its strokes plus a small margin, so the ink fills
  /// the box it's stamped into instead of shrinking with the pad's empty
  /// space. Returns [png] unchanged if it can't be read or has no alpha.
  static Uint8List trim(Uint8List png) {
    final src = img.decodePng(png);
    if (src == null || src.numChannels < 4) return png;
    final crop = img.findTrim(src);
    if (crop[2] <= 0 || crop[3] <= 0) return png;
    final pad = (src.height * 0.04).round().clamp(2, 12);
    final x = (crop[0] - pad).clamp(0, src.width - 1);
    final y = (crop[1] - pad).clamp(0, src.height - 1);
    final w = (crop[2] + 2 * pad).clamp(1, src.width - x);
    final h = (crop[3] + 2 * pad).clamp(1, src.height - y);
    return img.encodePng(img.copyCrop(src, x: x, y: y, width: w, height: h));
  }

  /// [first] and [second] next to each other on one transparent strip, at
  /// the same height, with a gap between them.
  static Uint8List sideBySide(Uint8List first, Uint8List second) {
    final a = img.decodePng(first);
    final b = img.decodePng(second);
    if (a == null || b == null) return first;
    final height = a.height > b.height ? a.height : b.height;
    img.Image fit(img.Image i) =>
        i.height == height ? i : img.copyResize(i, height: height);
    final left = fit(a);
    final right = fit(b);
    final gap = (height * 0.35).round();
    final out = img.Image(
      width: left.width + gap + right.width,
      height: height,
      numChannels: 4,
    );
    img.compositeImage(out, left, dstX: 0, dstY: 0);
    img.compositeImage(out, right, dstX: left.width + gap, dstY: 0);
    return img.encodePng(out);
  }
}
