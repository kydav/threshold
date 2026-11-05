import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/ink.dart';
import 'package:threshold/features/templates/data/template_deal.dart';

import 'template_deal_test.dart' show field, template;

Uint8List _strokes(int width, int height, int x, int y, int w, int h) {
  final im = img.Image(width: width, height: height, numChannels: 4);
  img.fillRect(
    im,
    x1: x,
    y1: y,
    x2: x + w,
    y2: y + h,
    color: img.ColorRgba8(11, 31, 107, 255),
  );
  return img.encodePng(im);
}

void main() {
  group('shared initials', () {
    final ini = field('buyer_initials_p1', kind: FieldKind.initials);
    final sig1 = field('buyer_signature', kind: FieldKind.signature);
    final sig2 = field('buyer_signature_2', kind: FieldKind.signature);

    test('a lone initials box is shared, and the second buyer inks it', () {
      final deal = TemplateDeal(template([ini, sig1, sig2]))..hasBuyer2 = true;
      expect(deal.isSharedInitials(ini), isTrue);
      expect(deal.inkFields(1).map((f) => f.id), [
        'buyer_initials_p1',
        'buyer_signature',
      ]);
      expect(
        deal.inkFields(2).map((f) => f.id),
        containsAll(['buyer_initials_p1', 'buyer_signature_2']),
      );
    });

    test('with one buyer, nothing is added for a second', () {
      final deal = TemplateDeal(template([ini, sig1, sig2]));
      expect(deal.inkFields(2), isEmpty);
    });

    test('a page with its own second-buyer initials is not shared', () {
      final ini2 = field('buyer_2_initials_p1', kind: FieldKind.initials);
      final deal = TemplateDeal(template([ini, ini2, sig1, sig2]))
        ..hasBuyer2 = true;
      expect(deal.isSharedInitials(ini), isFalse);
      expect(deal.inkFields(2).map((f) => f.id), [
        'buyer_2_initials_p1',
        'buyer_signature_2',
      ]);
    });
  });

  group('InkImage', () {
    test('trim crops to the strokes plus a margin', () {
      final out = img.decodePng(
        InkImage.trim(_strokes(600, 110, 200, 40, 80, 30)),
      )!;
      expect(out.width, lessThan(120));
      expect(out.height, lessThan(50));
      expect(out.width, greaterThanOrEqualTo(80));
    });

    test('sideBySide puts both at one height with a gap', () {
      final a = _strokes(80, 40, 0, 0, 80, 40);
      final b = _strokes(60, 20, 0, 0, 60, 20);
      final out = img.decodePng(InkImage.sideBySide(a, b))!;
      expect(out.height, 40);
      // b scales to 120 wide at height 40; gap is 35% of the height.
      expect(out.width, 80 + 14 + 120);
    });
  });
}
