import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_deal.dart';

TemplateField field(
  String id, {
  String label = '',
  FieldKind kind = FieldKind.text,
  FieldFiller by = FieldFiller.buyer,
  Rect box = const Rect.fromLTWH(0, 0, 100, 20),
  int page = 1,
}) => TemplateField(
  id: id,
  page: page,
  section: '',
  label: label,
  kind: kind,
  filledBy: by,
  choiceGroup: '',
  box: box,
  currentlyFilled: false,
);

FormTemplate template(List<TemplateField> fields) => FormTemplate(
  id: 't',
  title: 'Form',
  formId: '',
  pages: const [TemplatePage(file: 'page_1.jpg', width: 1176, height: 1568)],
  fields: fields,
  createdAt: DateTime(2026),
);

void main() {
  group('TemplateDeal.buyerIndex', () {
    test('reads second-buyer fields from the id or label', () {
      expect(TemplateDeal.buyerIndex(field('buyer_signature_2')), 2);
      expect(TemplateDeal.buyerIndex(field('buyer_2_date')), 2);
      expect(
        TemplateDeal.buyerIndex(
          field('sig_b', label: 'Second buyer signature'),
        ),
        2,
      );
      expect(TemplateDeal.buyerIndex(field('buyer_signature_1')), 1);
      expect(TemplateDeal.buyerIndex(field('buyer_initials_p2')), 1);
    });
  });

  group('SplitDate', () {
    test('groups day/month/year fields and fills them', () {
      final day = field('end_date_day', by: FieldFiller.agentPerDeal);
      final month = field('end_date_month', by: FieldFiller.agentPerDeal);
      final year = field(
        'end_date_year',
        by: FieldFiller.agentPerDeal,
        box: const Rect.fromLTWH(0, 0, 40, 20),
      );
      final groups = SplitDate.group([day, month, year]);
      expect(groups.keys, ['end_date']);

      final values = <String, Object>{};
      groups['end_date']!.fill(values, DateTime(2026, 6, 8));
      expect(values, {
        'end_date_day': '8th',
        'end_date_month': 'June',
        // A narrow blank after a printed "20" takes two digits.
        'end_date_year': '26',
      });
    });

    test('uses st/nd/rd and the teens correctly', () {
      final day = field('d_day');
      final values = <String, Object>{};
      final g = SplitDate.group([day])['d']!;
      for (final (n, want) in [
        (1, '1st'),
        (2, '2nd'),
        (3, '3rd'),
        (11, '11th'),
        (12, '12th'),
        (13, '13th'),
        (21, '21st'),
        (22, '22nd'),
      ]) {
        g.fill(values, DateTime(2026, 1, n));
        expect(values['d_day'], want);
      }
    });
  });

  group('TemplateDeal', () {
    test('autofill puts buyer names in name blanks and dates today', () {
      final deal =
          TemplateDeal(
              template([
                field('buyer_name_1', label: 'Buyer name'),
                field('buyer_name_2', label: 'Second buyer name'),
                field('buyer_date_1', label: 'Date', kind: FieldKind.date),
                field(
                  'agents_name',
                  label: 'Agent name',
                  by: FieldFiller.agentOnce,
                ),
              ]),
            )
            ..buyerName = 'Tina'
            ..hasBuyer2 = true
            ..buyer2Name = 'Sam';
      deal.autofill();
      expect(deal.values['buyer_name_1'], 'Tina');
      expect(deal.values['buyer_name_2'], 'Sam');
      expect(deal.values['buyer_date_1'], isA<String>());
      expect(deal.values.containsKey('agents_name'), isFalse);
    });

    test('drops second-buyer fields when there is one buyer', () {
      final deal = TemplateDeal(
        template([
          field('buyer_signature_1', kind: FieldKind.signature),
          field('buyer_signature_2', kind: FieldKind.signature),
        ]),
      );
      expect(deal.active(FieldFiller.buyer).map((f) => f.id), [
        'buyer_signature_1',
      ]);
      deal.hasBuyer2 = true;
      expect(deal.active(FieldFiller.buyer), hasLength(2));
    });

    test('active() reads top-to-bottom, then left-to-right on a row', () {
      final deal = TemplateDeal(
        template([
          field('b', box: const Rect.fromLTWH(300, 100, 50, 20)),
          field('c', box: const Rect.fromLTWH(10, 300, 50, 20)),
          field('a', box: const Rect.fromLTWH(10, 105, 50, 20)),
        ]),
      );
      expect(deal.active(FieldFiller.buyer).map((f) => f.id), ['a', 'b', 'c']);
    });
  });
}
