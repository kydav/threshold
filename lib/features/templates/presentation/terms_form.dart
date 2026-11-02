import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_deal.dart';

/// The per-deal questions of an imported form, as few and as clear as they
/// can be: grouped under the form's own headings, "check one" options as one
/// choice with the blanks that belong to an option shown right under it once
/// picked, a long answer wrapped over several lines asked once, and buyer
/// names never asked (they come from the buyers already entered).
///
/// [collapseUsual]: groups already answered by this form's usual terms fold
/// into one "Your usual terms" row, so a repeat deal is a glance.
class TermsForm extends StatefulWidget {
  const TermsForm({
    required this.deal,
    required this.fields,
    this.collapseUsual = false,
    super.key,
  });

  final TemplateDeal deal;

  /// The fields to ask about (in reading order).
  final List<TemplateField> fields;
  final bool collapseUsual;

  @override
  State<TermsForm> createState() => _TermsFormState();
}

/// One question group: a heading and its fields in reading order.
class _Group {
  _Group(this.title);

  final String title;
  final List<TemplateField> fields = [];
}

class _TermsFormState extends State<TermsForm> {
  TemplateDeal get deal => widget.deal;

  Map<String, Object> get values => deal.values;

  /// Fields the agent never needs to see: names come from the buyers,
  /// continuation lines are part of their first line, and dependent blanks
  /// show under their option.
  bool _hiddenAtTop(TemplateField f) =>
      f.role.isBuyerName || f.continues.isNotEmpty || f.dependsOn.isNotEmpty;

  List<_Group> _groups() {
    final groups = <String, _Group>{};
    for (final f in widget.fields) {
      if (_hiddenAtTop(f)) continue;
      final title = f.groupTitle.isNotEmpty ? f.groupTitle : f.section;
      groups.putIfAbsent(title, () => _Group(title)).fields.add(f);
    }
    return groups.values.toList();
  }

  /// A group already settled by this form's usual terms (fee, protection,
  /// mediation...). Area, property and date questions always stay open.
  bool _usual(_Group g) {
    if (!widget.collapseUsual) return false;
    for (final f in g.fields) {
      if (f.kind == FieldKind.date ||
          f.role == FieldRole.endDate ||
          f.role == FieldRole.area ||
          f.role == FieldRole.propertyAddress ||
          f.role == FieldRole.excludedProperties ||
          RegExp(r'_(day|month|year)$').hasMatch(f.id)) {
        return false;
      }
      if (f.kind == FieldKind.checkbox) {
        if (f.choiceGroup.isNotEmpty &&
            !g.fields
                .where((o) => o.choiceGroup == f.choiceGroup)
                .any((o) => values[o.id] == true)) {
          return false;
        }
        if (f.choiceGroup.isEmpty &&
            !deal.template.dealDefaults.containsKey(f.id)) {
          return false;
        }
      } else if (!deal.template.dealDefaults.containsKey(f.id)) {
        return false;
      }
    }
    return true;
  }

  String _summary(_Group g) {
    final parts = <String>[];
    for (final f in g.fields) {
      final v = values[f.id];
      if (f.kind == FieldKind.checkbox) {
        if (v == true) parts.add(f.label);
      } else if (v is String && v.isNotEmpty) {
        parts.add(switch (f.kind) {
          FieldKind.percent => '$v%',
          FieldKind.currency => '\$$v',
          _ => v,
        });
      }
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final open = groups.where((g) => !_usual(g)).toList();
    final usual = groups.where(_usual).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in open) ...[
          if (g.title.isNotEmpty) _Heading(g.title),
          ..._groupBody(g),
          const SizedBox(height: 12),
        ],
        if (usual.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: ExpansionTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Your usual terms'),
              subtitle: Text(
                usual
                    .map((g) => _summary(g))
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final g in usual) ...[
                  if (g.title.isNotEmpty) _Heading(g.title),
                  ..._groupBody(g),
                ],
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _groupBody(_Group g) {
    final out = <Widget>[];
    final dates = SplitDate.group(g.fields);
    final inDate = {
      for (final d in dates.values) ...[d.day?.id, d.month?.id, d.year?.id],
    };
    final shownDates = <String>{};
    final shownChoices = <String>{};
    for (final f in g.fields) {
      if (inDate.contains(f.id)) {
        final d = dates.values.firstWhere(
          (d) => d.day?.id == f.id || d.month?.id == f.id || d.year?.id == f.id,
        );
        if (shownDates.add(d.key)) {
          out.add(
            _DateField(
              label: _dateLabel(d),
              quick: d.key.contains('end'),
              onPicked: (date) {
                d.fill(values, date);
                if (d.key.contains('end')) deal.endDate = date;
              },
            ),
          );
        }
        continue;
      }
      if (f.kind == FieldKind.checkbox && f.choiceGroup.isNotEmpty) {
        if (!shownChoices.add(f.choiceGroup)) continue;
        out.add(
          _choice(
            g.fields.where((o) => o.choiceGroup == f.choiceGroup).toList(),
          ),
        );
        continue;
      }
      out.add(_field(f));
      if (f.kind == FieldKind.checkbox && values[f.id] == true) {
        out.addAll(_dependents(f));
      }
    }
    return out;
  }

  /// The blanks that belong to [option], indented under it.
  List<Widget> _dependents(TemplateField option) => [
    for (final d in deal.template.fields)
      if (d.dependsOn == option.id &&
          d.continues.isEmpty &&
          (deal.hasBuyer2 || TemplateDeal.buyerIndex(d) == 1))
        Padding(
          padding: const EdgeInsets.only(left: 40, bottom: 4),
          child: _field(d, autofocus: true),
        ),
  ];

  Widget _choice(List<TemplateField> options) {
    final picked = options.where((o) => values[o.id] == true).firstOrNull;
    return RadioGroup<String>(
      groupValue: picked?.id,
      onChanged:
          (id) => setState(() {
            for (final o in options) {
              values[o.id] = o.id == id;
            }
          }),
      child: Column(
        children: [
          for (final o in options) ...[
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: o.id,
              title: Text(o.label),
            ),
            if (picked?.id == o.id) ..._dependents(o),
          ],
        ],
      ),
    );
  }

  Widget _field(TemplateField f, {bool autofocus = false}) {
    switch (f.kind) {
      case FieldKind.checkbox:
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(f.label),
          value: values[f.id] == true,
          onChanged: (v) => setState(() => values[f.id] = v ?? false),
        );
      case FieldKind.date:
        return _DateField(
          label: f.label,
          quick: f.role == FieldRole.endDate,
          onPicked: (d) {
            values[f.id] = DateFormat('M/d/yyyy').format(d);
            if (f.role == FieldRole.endDate) deal.endDate = d;
          },
        );
      case FieldKind.signature || FieldKind.initials:
        return const SizedBox.shrink();
      case FieldKind.number || FieldKind.currency || FieldKind.percent:
        return TextFormField(
          key: ValueKey(f.id),
          initialValue: values[f.id] as String?,
          autofocus: autofocus,
          decoration: InputDecoration(
            labelText: f.label,
            prefixText: f.kind == FieldKind.currency ? r'$ ' : null,
            suffixText: f.kind == FieldKind.percent ? '%' : null,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
          ],
          onChanged: (v) => values[f.id] = v.trim(),
        );
      case FieldKind.text:
        // One answer wrapped over several printed lines is asked once.
        final lines = deal.lineChain(f).length;
        return TextFormField(
          key: ValueKey(f.id),
          initialValue: values[f.id] as String?,
          autofocus: autofocus,
          minLines: 1,
          maxLines: lines > 1 ? lines + 1 : 1,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => values[f.id] = v.trim(),
        );
    }
  }

  String _dateLabel(SplitDate g) {
    final label = (g.day ?? g.month ?? g.year)!.label;
    return label.replaceAll(
      RegExp(r'\s*\(?(day|month|year)\)?$', caseSensitive: false),
      '',
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _DateField extends StatefulWidget {
  const _DateField({
    required this.label,
    required this.onPicked,
    this.quick = false,
  });

  final String label;
  final void Function(DateTime) onPicked;

  /// One-tap lengths (3 months, 6 months, a year) for an end date.
  final bool quick;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  DateTime? _date;

  void _set(DateTime d) {
    setState(() => _date = d);
    widget.onPicked(d);
  }

  /// [months] from today, on the same day of the month where it exists.
  static DateTime _plusMonths(int months) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, now.day.clamp(1, lastDay));
  }

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.label),
      subtitle: Text(
        _date == null ? 'Pick a date' : DateFormat.yMMMMd().format(_date!),
      ),
      trailing: const Icon(Icons.event_outlined),
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: _date ?? now.add(const Duration(days: 90)),
          firstDate: now.subtract(const Duration(days: 30)),
          lastDate: now.add(const Duration(days: 3650)),
        );
        if (d == null) return;
        _set(d);
      },
    );
    if (!widget.quick) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile,
        Wrap(
          spacing: 8,
          children: [
            for (final (label, months) in [
              ('3 months', 3),
              ('6 months', 6),
              ('1 year', 12),
            ])
              ActionChip(
                label: Text(label),
                onPressed: () => _set(_plusMonths(months)),
              ),
          ],
        ),
      ],
    );
  }
}
