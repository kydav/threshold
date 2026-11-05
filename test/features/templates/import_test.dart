import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:threshold/features/templates/data/form_imports.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

import 'template_deal_test.dart' show field;

final _black = img.ColorRgb8(0, 0, 0);

img.Image _page() =>
    img.Image(width: 400, height: 200)..clear(img.ColorRgb8(255, 255, 255));

void main() {
  group('hasInk', () {
    final blank = field('name', box: const Rect.fromLTRB(50, 40, 350, 70));
    final box = field(
      'opt',
      kind: FieldKind.checkbox,
      box: const Rect.fromLTRB(50, 120, 70, 140),
    );

    test('an empty blank (just its underline) is not filled', () {
      final page = _page();
      img.drawLine(page, x1: 50, y1: 69, x2: 350, y2: 69, color: _black);
      expect(hasInk(page, blank), isFalse);
    });

    test('writing above the underline is filled', () {
      final page = _page();
      img.drawLine(page, x1: 50, y1: 69, x2: 350, y2: 69, color: _black);
      img.fillRect(page, x1: 60, y1: 45, x2: 160, y2: 58, color: _black);
      expect(hasInk(page, blank), isTrue);
    });

    test('a checkbox outline alone is not checked; an X is', () {
      final page = _page();
      img.drawRect(page, x1: 50, y1: 120, x2: 70, y2: 140, color: _black);
      expect(hasInk(page, box), isFalse);
      img.drawLine(
        page,
        x1: 52,
        y1: 122,
        x2: 68,
        y2: 138,
        color: _black,
        thickness: 2,
      );
      img.drawLine(
        page,
        x1: 68,
        y1: 122,
        x2: 52,
        y2: 138,
        color: _black,
        thickness: 2,
      );
      expect(hasInk(page, box), isTrue);
    });
  });

  test('PendingImport survives a save and load', () {
    final item = PendingImport(
      id: 'a',
      uid: 'u',
      createdAt: DateTime(2026, 11, 4),
      pageCount: 3,
      status: ImportStatus.reading,
      jobId: 'job1',
    );
    final back = PendingImport.fromMap(item.toMap());
    expect(back.status, ImportStatus.reading);
    expect(back.jobId, 'job1');
    expect(back.pageCount, 3);
    final failed = back.copyWith(status: ImportStatus.failed, error: 'x');
    expect(failed.error, 'x');
    expect(failed.copyWith(status: ImportStatus.reading).error, isNull);
  });
}
