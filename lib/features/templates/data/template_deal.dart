import 'package:intl/intl.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_pdf_service.dart';

/// One signing in progress, built from a template: who the buyers are and
/// every value filled so far. Lives in memory until the PDF is generated.
class TemplateDeal {
  TemplateDeal(this.template) {
    values.addAll(template.agentValues);
  }

  final FormTemplate template;
  String buyerName = '';
  String buyerEmail = '';
  bool hasBuyer2 = false;

  /// When the agreement ends, if the form has an end-date field.
  DateTime? endDate;
  String buyer2Name = '';
  String buyer2Email = '';
  final FieldValues values = {};
  final List<SignatureEvent> events = [];

  /// Which buyer a field belongs to: 2 for a second buyer's line, else 1.
  static int buyerIndex(TemplateField f) {
    final id = f.id.toLowerCase();
    final label = f.label.toLowerCase();
    if (RegExp(r'_2($|_)').hasMatch(id) ||
        label.contains('second') ||
        label.contains('buyer 2') ||
        label.contains('co-buyer')) {
      return 2;
    }
    return 1;
  }

  /// Fields this deal actually uses (second-buyer lines drop out when there
  /// is only one buyer), in reading order.
  List<TemplateField> active(FieldFiller filler) {
    final list =
        template.fields
            .where((f) => f.filledBy == filler)
            .where((f) => hasBuyer2 || buyerIndex(f) == 1)
            .toList()
          ..sort((a, b) {
            final byPage = a.page.compareTo(b.page);
            if (byPage != 0) return byPage;
            final byRow = a.box.top.compareTo(b.box.top);
            return byRow.abs() > 0 && (a.box.top - b.box.top).abs() > 12
                ? byRow
                : a.box.left.compareTo(b.box.left);
          });
    return list;
  }

  /// Fills the parts that follow from facts already known: buyer names go in
  /// name blanks, and every date beside a signature or initials is today.
  void autofill() {
    final today = DateFormat('M/d/yyyy').format(DateTime.now());
    for (final f in template.fields) {
      final label = f.label.toLowerCase();
      final isBuyerSide =
          f.filledBy == FieldFiller.buyer ||
          f.filledBy == FieldFiller.agentSign;
      if (f.kind == FieldKind.date && isBuyerSide) {
        values[f.id] = today;
      } else if (f.filledBy == FieldFiller.buyer &&
          f.kind == FieldKind.text &&
          label.contains('name') &&
          !label.contains('agent')) {
        final name = buyerIndex(f) == 2 ? buyer2Name : buyerName;
        if (name.isNotEmpty) values[f.id] = name;
      }
    }
  }

  /// Display label for the agreement history and email.
  String get summary {
    String? pick(bool Function(String) test) {
      for (final f in active(FieldFiller.agentPerDeal)) {
        final v = values[f.id];
        if (v is String && v.isNotEmpty && test(f.label.toLowerCase())) {
          return v;
        }
      }
      return null;
    }

    final fee = [
      pick((l) => l.contains('percent') || l.contains('%')),
      pick((l) => l.contains('fee') && l.contains(r'$')),
    ].whereType<String>().join(' / ');
    final area = pick((l) => l.contains('count') || l.contains('propert'));
    return [if (area != null) area, if (fee.isNotEmpty) 'Fee $fee'].join(' · ');
  }
}

/// A date shown as separate day / month / year blanks on the form.
class SplitDate {
  SplitDate({required this.key, this.day, this.month, this.year});

  final String key;
  TemplateField? day;
  TemplateField? month;
  TemplateField? year;

  /// Groups `end_date_day` / `end_date_month` / `end_date_year` style fields.
  static Map<String, SplitDate> group(Iterable<TemplateField> fields) {
    final out = <String, SplitDate>{};
    final re = RegExp(r'^(.*)_(day|month|year)$');
    for (final f in fields) {
      final m = re.firstMatch(f.id);
      if (m == null || f.kind == FieldKind.checkbox) continue;
      final g = out.putIfAbsent(m.group(1)!, () => SplitDate(key: m.group(1)!));
      switch (m.group(2)) {
        case 'day':
          g.day = f;
        case 'month':
          g.month = f;
        case 'year':
          g.year = f;
      }
    }
    return out;
  }

  void fill(FieldValues values, DateTime d) {
    if (day != null) values[day!.id] = _ordinal(d.day);
    if (month != null) values[month!.id] = DateFormat.MMMM().format(d);
    if (year != null) {
      // A short blank (e.g. after a printed "20") takes two digits.
      values[year!.id] =
          year!.box.width < 60 ? DateFormat('yy').format(d) : '${d.year}';
    }
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
