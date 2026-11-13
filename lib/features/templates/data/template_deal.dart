import 'package:intl/intl.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_pdf_service.dart';

/// One signing in progress, built from a template: who the buyers are and
/// every value filled so far. Lives in memory until the PDF is generated.
class TemplateDeal {
  TemplateDeal(this.template) {
    values.addAll(template.agentValues);
    // Start from this form's usual terms (set at import, then the last
    // deal's), and the form's own default options.
    values.addAll(template.dealDefaults);
    final groupsSet = {
      for (final f in template.fields)
        if (f.choiceGroup.isNotEmpty && values[f.id] == true) f.choiceGroup,
    };
    for (final f in template.fields) {
      if (f.kind == FieldKind.checkbox &&
          f.defaultChecked &&
          !values.containsKey(f.id) &&
          (f.choiceGroup.isEmpty || !groupsSet.contains(f.choiceGroup))) {
        values[f.id] = true;
      }
    }
  }

  /// The form's AI overview with this deal's values in: a sentence drops
  /// out when its option isn't picked or a value it needs is still blank.
  List<String> get overview {
    final out = <String>[];
    for (final line in template.summary) {
      if (line.ifChecked.isNotEmpty && values[line.ifChecked] != true) {
        continue;
      }
      var missing = false;
      final text = line.text.replaceAllMapped(RegExp(r'\{([a-zA-Z0-9_]+)\}'), (
        m,
      ) {
        final v = _overviewValue(m[1]!);
        if (v == null) missing = true;
        return v ?? '';
      });
      if (!missing && text.trim().isNotEmpty) out.add(text.trim());
    }
    return out;
  }

  /// A value as it reads in a sentence: $ on money, % on a percent, and a
  /// date split over day/month/year blanks put back together.
  String? _overviewValue(String id) {
    final f = field(id);
    final v = values[id];
    if (v is String && v.trim().isNotEmpty) {
      final t = v.trim();
      return switch (f?.kind) {
        FieldKind.currency => t.startsWith(r'$') ? t : '\$$t',
        FieldKind.percent => t.endsWith('%') ? t : '$t%',
        _ => t,
      };
    }
    if (f == null || f.kind == FieldKind.date || id.endsWith('_date')) {
      final base = id.replaceAll(RegExp(r'_date$'), '');
      final parts = [
        for (final p in ['month', 'day', 'year'])
          values['${base}_$p'] ?? values['${base}_date_$p'],
      ];
      if (parts.every((p) => p is String && p.trim().isNotEmpty)) {
        return parts.map((p) => (p! as String).trim()).join('/');
      }
      if (f?.role == FieldRole.endDate || base.contains('end')) {
        if (endDate case final d?) return DateFormat.yMMMMd().format(d);
      }
    }
    return null;
  }

  /// Field by id.
  TemplateField? field(String id) =>
      template.fields.where((f) => f.id == id).firstOrNull;

  /// Whether [f] applies right now: everything it depends on is checked.
  bool applies(TemplateField f) {
    var dep = f.dependsOn;
    final seen = <String>{};
    while (dep.isNotEmpty && seen.add(dep)) {
      if (values[dep] != true) return false;
      dep = field(dep)?.dependsOn ?? '';
    }
    return hasBuyer2 || buyerIndex(f) == 1;
  }

  /// The lines one answer wraps over, starting at [head].
  List<TemplateField> lineChain(TemplateField head) {
    final chain = [head];
    while (true) {
      final next =
          template.fields
              .where((f) => f.continues == chain.last.id)
              .firstOrNull;
      if (next == null || chain.contains(next)) return chain;
      chain.add(next);
    }
  }

  /// Wraps [text] over [lines] by how many characters each blank holds, so
  /// a long address flows onto the continuation lines.
  static Map<String, String> wrapOver(String text, List<TemplateField> lines) {
    final out = <String, String>{};
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final queue = words.toList();
    for (var i = 0; i < lines.length && queue.isNotEmpty; i++) {
      final b = lines[i].box;
      // Text is stamped at about 70% of the blank's height; average glyph
      // width is about half the font size.
      final capacity = (b.width / (b.height * 0.36)).floor().clamp(8, 400);
      final last = i == lines.length - 1;
      final buf = StringBuffer();
      while (queue.isNotEmpty) {
        final w = queue.first;
        final candidate = buf.isEmpty ? w : '$buf $w';
        if (!last && candidate.length > capacity && buf.isNotEmpty) break;
        buf
          ..clear()
          ..write(candidate);
        queue.removeAt(0);
      }
      out[lines[i].id] = buf.toString();
    }
    return out;
  }

  /// All the buyers' names together, for a "(the Buyer)" blank.
  String get buyerNames => [
    buyerName,
    if (hasBuyer2 && buyer2Name.isNotEmpty) buyer2Name,
  ].where((n) => n.isNotEmpty).join(' and ');

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
    if (f.role == FieldRole.buyer2Name ||
        RegExp(r'(buyer_?2|_2)($|_)').hasMatch(id) ||
        label.contains('second') ||
        RegExp(r'buyer\s*#?\s*2').hasMatch(label) ||
        label.contains('co-buyer')) {
      return 2;
    }
    return 1;
  }

  /// A first-buyer initials box that every buyer initials: the form has no
  /// separate second-buyer initials on that page, so a second buyer's go
  /// beside the first's.
  bool isSharedInitials(TemplateField f) =>
      f.kind == FieldKind.initials &&
      f.filledBy == FieldFiller.buyer &&
      buyerIndex(f) == 1 &&
      !template.fields.any(
        (o) =>
            o.page == f.page &&
            o.kind == FieldKind.initials &&
            buyerIndex(o) == 2,
      );

  /// The boxes [buyer] signs or initials: their own lines, and for a second
  /// buyer also the shared initials.
  List<TemplateField> inkFields(int buyer) =>
      active(FieldFiller.buyer)
          .where(
            (f) =>
                buyerIndex(f) == buyer ||
                (buyer == 2 && hasBuyer2 && isSharedInitials(f)),
          )
          .toList();

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
  /// Wraps long answers over their lines, and clears anything that no longer
  /// applies (a county typed before switching to "specific properties").
  void autofill() {
    final today = DateFormat('M/d/yyyy').format(DateTime.now());
    for (final f in template.fields) {
      switch (f.role) {
        case FieldRole.buyerNames:
          values[f.id] = buyerNames;
          continue;
        case FieldRole.buyer1Name:
          if (buyerName.isNotEmpty) values[f.id] = buyerName;
          continue;
        case FieldRole.buyer2Name:
          if (hasBuyer2 && buyer2Name.isNotEmpty) values[f.id] = buyer2Name;
          continue;
        default:
      }
      if (f.continues.isEmpty &&
          template.fields.any((x) => x.continues == f.id)) {
        final text = values[f.id];
        if (text is String) values.addAll(wrapOver(text, lineChain(f)));
      }
    }
    for (final f in template.fields) {
      if (f.dependsOn.isNotEmpty && !applies(f)) values.remove(f.id);
    }
    for (final f in template.fields) {
      final label = f.label.toLowerCase();
      final isBuyerSide =
          f.filledBy == FieldFiller.buyer ||
          f.filledBy == FieldFiller.agentSign;
      if (f.kind == FieldKind.date && isBuyerSide) {
        values[f.id] = today;
      } else if (f.role == FieldRole.other &&
          f.filledBy == FieldFiller.buyer &&
          f.kind == FieldKind.text &&
          label.contains('name') &&
          !label.contains('agent')) {
        final name = buyerIndex(f) == 2 ? buyer2Name : buyerName;
        if (name.isNotEmpty) values[f.id] = name;
      }
    }
  }

  /// The agent's name, brokerage and license on any line the form's own
  /// details left blank (a field the check missed, or one in the agent's
  /// signature block). Never overwrites what the agent typed.
  void fillAgentDetails({
    required String name,
    required String brokerage,
    String license = '',
  }) {
    for (final f in template.fields) {
      if (f.kind != FieldKind.text || f.filledBy == FieldFiller.buyer) {
        continue;
      }
      final v = switch (f.role) {
        FieldRole.agentName => name,
        FieldRole.brokerageName => brokerage,
        FieldRole.agentLicense => license,
        _ => '',
      };
      final current = values[f.id];
      if (v.isEmpty || (current is String && current.trim().isNotEmpty)) {
        continue;
      }
      values[f.id] = v;
    }
  }

  /// Remembers this deal's terms as the starting point for the next one:
  /// the fee, protection period and every option picked. Not names, dates or
  /// addresses, which change every deal.
  void rememberTerms() {
    const keep = {
      FieldRole.feeAmount,
      FieldRole.feePercent,
      FieldRole.protectionMonths,
    };
    for (final f in template.fields) {
      if (f.filledBy != FieldFiller.agentPerDeal) continue;
      final v = values[f.id];
      if (f.kind == FieldKind.checkbox) {
        template.dealDefaults[f.id] = v == true;
      } else if (keep.contains(f.role) && v is String && v.isNotEmpty) {
        template.dealDefaults[f.id] = v;
      }
    }
  }

  /// Display label for the agreement history and email.
  String get summary =>
      [if (area != null) area!, if (fee != null) 'Fee $fee'].join(' · ');

  String? _pick(bool Function(String) test) {
    for (final f in active(FieldFiller.agentPerDeal)) {
      final v = values[f.id];
      if (v is String && v.trim().isNotEmpty && test(f.label.toLowerCase())) {
        return v.trim();
      }
    }
    return null;
  }

  /// Where the buyer is represented (counties or properties), if asked.
  String? get area =>
      _pick((l) => l.contains('count') || l.contains('propert'));

  /// The fee as written on the form, with its unit: "2.5%", "$5,000".
  String? get fee {
    String? unit(String? v, {required bool percent}) {
      if (v == null) return null;
      if (percent) return v.endsWith('%') ? v : '$v%';
      return v.startsWith(r'$') ? v : '\$$v';
    }

    final parts =
        [
          unit(
            _pick((l) => l.contains('percent') || l.contains('%')),
            percent: true,
          ),
          unit(
            _pick((l) => l.contains('fee') && l.contains(r'$')),
            percent: false,
          ),
        ].whereType<String>();
    return parts.isEmpty ? null : parts.join(' / ');
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
