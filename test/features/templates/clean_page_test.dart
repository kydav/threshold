import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

void main() {
  test('cleanPage erases blue ink and filled boxes, keeps black print', () {
    final page = img.Image(width: 200, height: 100)
      ..clear(img.ColorRgb8(255, 255, 255));
    // Black print, blue pen, and black "typed" text inside a filled field.
    img.fillRect(
      page,
      x1: 10,
      y1: 10,
      x2: 30,
      y2: 20,
      color: img.ColorRgb8(20, 20, 20),
    );
    img.fillRect(
      page,
      x1: 60,
      y1: 10,
      x2: 80,
      y2: 20,
      color: img.ColorRgb8(30, 40, 160),
    );
    img.fillRect(
      page,
      x1: 120,
      y1: 40,
      x2: 140,
      y2: 50,
      color: img.ColorRgb8(20, 20, 20),
    );

    final field = TemplateField(
      id: 'company',
      page: 1,
      section: '',
      label: 'Company',
      kind: FieldKind.text,
      filledBy: FieldFiller.agentOnce,
      choiceGroup: '',
      box: const Rect.fromLTRB(110, 35, 150, 60),
      currentlyFilled: true,
    );
    final out =
        img.decodeJpg(
          cleanPage(Uint8List.fromList(img.encodeJpg(page)), [
            field,
          ]),
        )!;

    bool isWhite(int x, int y) => out.getPixel(x, y).luminance > 230;
    expect(isWhite(20, 15), isFalse, reason: 'black print stays');
    expect(isWhite(70, 15), isTrue, reason: 'blue ink goes');
    expect(isWhite(130, 45), isTrue, reason: 'filled field is cleared');
  });
}
