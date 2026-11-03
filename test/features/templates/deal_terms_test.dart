import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_deal.dart';

TemplateField f(
  String id, {
  String label = '',
  FieldKind kind = FieldKind.text,
  FieldFiller by = FieldFiller.agentPerDeal,
  String group = '',
  String dependsOn = '',
  String continues = '',
  String choice = '',
  bool isDefault = false,
  FieldRole? role,
  Rect box = const Rect.fromLTWH(0, 0, 400, 20),
}) => TemplateField(
  id: id,
  page: 1,
  section: '',
  label: label,
  kind: kind,
  filledBy: by,
  choiceGroup: choice,
  box: box,
  currentlyFilled: false,
  role: role,
  groupTitle: group,
  dependsOn: dependsOn,
  continues: continues,
  defaultChecked: isDefault,
);

FormTemplate template(
  List<TemplateField> fields, {
  Map<String, Object>? defaults,
  List<SummaryLine> summary = const [],
}) => FormTemplate(
  id: 't',
  title: 'Form 6',
  formId: '',
  pages: const [TemplatePage(file: 'p.jpg', width: 1176, height: 1568)],
  fields: fields,
  createdAt: DateTime(2026),
  dealDefaults: defaults,
  summary: summary,
);

void main() {
  test('the "(the Buyer)" blank gets every buyer, never asked', () {
    final deal =
        TemplateDeal(
            template([
              f(
                'buyer_names',
                label: 'Buyer name(s)',
                role: FieldRole.buyerNames,
              ),
            ]),
          )
          ..buyerName = 'Dana Reed'
          ..hasBuyer2 = true
          ..buyer2Name = 'Sam Reed';
    deal.autofill();
    expect(deal.values['buyer_names'], 'Dana Reed and Sam Reed');
    deal
      ..hasBuyer2 = false
      ..autofill();
    expect(deal.values['buyer_names'], 'Dana Reed');
  });

  test('old templates without roles still recognise buyer-name blanks', () {
    expect(
      FieldRole.infer('buyer_names', 'Buyer name(s)', FieldKind.text),
      FieldRole.buyerNames,
    );
    expect(
      FieldRole.infer('x', 'County/Counties', FieldKind.text),
      FieldRole.area,
    );
  });

  test('a blank under an option only applies once the option is picked', () {
    final county = f('rep_county', kind: FieldKind.checkbox, choice: 'rep');
    final property = f('rep_property', kind: FieldKind.checkbox, choice: 'rep');
    final counties = f('counties', dependsOn: 'rep_county');
    final address = f('address_1', dependsOn: 'rep_property');
    final deal = TemplateDeal(template([county, property, counties, address]));
    deal.values
      ..['rep_county'] = true
      ..['counties'] = 'Iron'
      ..['address_1'] = '1 Main St';
    expect(deal.applies(counties), isTrue);
    expect(deal.applies(address), isFalse);
    deal.autofill();
    // The address typed before switching options doesn't print.
    expect(deal.values.containsKey('address_1'), isFalse);
    expect(deal.values['counties'], 'Iron');
  });

  test('a long answer wraps over its continuation lines', () {
    final l1 = f('addr_1', box: const Rect.fromLTWH(0, 0, 300, 20));
    final l2 = f(
      'addr_2',
      continues: 'addr_1',
      box: const Rect.fromLTWH(0, 30, 300, 20),
    );
    final deal = TemplateDeal(template([l1, l2]));
    expect(deal.lineChain(l1).map((x) => x.id), ['addr_1', 'addr_2']);
    deal.values['addr_1'] =
        '123 North Main Street, Cedar City, Utah 84720 and 45 South Elm Avenue';
    deal.autofill();
    final line1 = deal.values['addr_1']! as String;
    final line2 = deal.values['addr_2']! as String;
    expect(line1.length, lessThanOrEqualTo(42));
    expect(
      '$line1 $line2',
      '123 North Main Street, Cedar City, Utah 84720 and 45 South Elm Avenue',
    );
  });

  test('deals start from the form defaults and the usual terms', () {
    final shall = f('shall', kind: FieldKind.checkbox, choice: 'med');
    final may = f(
      'may',
      kind: FieldKind.checkbox,
      choice: 'med',
      isDefault: true,
    );
    final fee = f(
      'fee_pct',
      kind: FieldKind.percent,
      role: FieldRole.feePercent,
    );
    var deal = TemplateDeal(template([shall, may, fee]));
    expect(deal.values['may'], isTrue);
    expect(deal.values.containsKey('shall'), isFalse);

    // Saved usual terms win over the form's default.
    deal = TemplateDeal(
      template(
        [shall, may, fee],
        defaults: {'shall': true, 'may': false, 'fee_pct': '3'},
      ),
    );
    expect(deal.values['shall'], isTrue);
    expect(deal.values['may'], isFalse);
    expect(deal.values['fee_pct'], '3');
  });

  test("a signed deal's terms carry forward, but not its names or places", () {
    final t = template([
      f('fee_pct', kind: FieldKind.percent, role: FieldRole.feePercent),
      f('counties', role: FieldRole.area),
      f('no_addendum', kind: FieldKind.checkbox, choice: 'add'),
    ]);
    final deal = TemplateDeal(t);
    deal.values
      ..['fee_pct'] = '2.5'
      ..['counties'] = 'Iron'
      ..['no_addendum'] = true;
    deal.rememberTerms();
    expect(t.dealDefaults, {'fee_pct': '2.5', 'no_addendum': true});
  });

  test('the AI overview fills values and drops what does not apply', () {
    final deal = TemplateDeal(
      template(
        [
          f('fee', kind: FieldKind.percent),
          f('area_county', kind: FieldKind.checkbox, choice: 'area'),
          f('area_property', kind: FieldKind.checkbox, choice: 'area'),
          f('county', dependsOn: 'area_county', role: FieldRole.area),
          f('end_date_month'),
          f('end_date_day'),
          f('end_date_year'),
          f('protection'),
        ],
        summary: const [
          SummaryLine('You agree to pay {fee} of the price.'),
          SummaryLine('It covers {county}.', ifChecked: 'area_county'),
          SummaryLine('It covers one property.', ifChecked: 'area_property'),
          SummaryLine('It ends on {end_date}.'),
          SummaryLine('Protection lasts {protection} days.'),
        ],
      ),
    );
    deal.values.addAll({
      'fee': '3',
      'area_county': true,
      'county': 'Larimer',
      'end_date_month': '2',
      'end_date_day': '1',
      'end_date_year': '2027',
    });
    expect(deal.overview, [
      'You agree to pay 3% of the price.',
      'It covers Larimer.',
      'It ends on 2/1/2027.',
    ]);
  });

  test('second-buyer lines are recognised by id or label', () {
    expect(TemplateDeal.buyerIndex(f('buyer2_address')), 2);
    expect(TemplateDeal.buyerIndex(f('address_2')), 2);
    expect(TemplateDeal.buyerIndex(f('x', label: 'Buyer #2 phone')), 2);
    expect(TemplateDeal.buyerIndex(f('buyer_address')), 1);
  });
}
