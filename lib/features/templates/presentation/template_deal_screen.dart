import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_deal.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

final _templateByIdProvider = FutureProvider.family<FormTemplate?, String>((
  ref,
  id,
) async {
  final all = await ref.watch(templateRepositoryProvider).all();
  return all.where((t) => t.id == id).firstOrNull;
});

/// The agent's part: who the buyer is and this deal's terms. Then the phone
/// goes to the buyer.
class TemplateDealScreen extends ConsumerWidget {
  const TemplateDealScreen({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_templateByIdProvider(templateId))
        .when(
          loading:
              () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data:
              (t) =>
                  t == null
                      ? const Scaffold(
                        body: Center(child: Text('Form not found')),
                      )
                      : _DealForm(deal: TemplateDeal(t)),
        );
  }
}

class _DealForm extends StatefulWidget {
  const _DealForm({required this.deal});

  final TemplateDeal deal;

  @override
  State<_DealForm> createState() => _DealFormState();
}

class _DealFormState extends State<_DealForm> {
  final _formKey = GlobalKey<FormState>();

  TemplateDeal get deal => widget.deal;

  @override
  Widget build(BuildContext context) {
    final perDeal = deal.active(FieldFiller.agentPerDeal);
    final dates = SplitDate.group(perDeal);
    final inDate = {
      for (final g in dates.values) ...[g.day?.id, g.month?.id, g.year?.id],
    };
    final groups = <String, List<TemplateField>>{};
    for (final f in perDeal.where((f) => f.choiceGroup.isNotEmpty)) {
      groups.putIfAbsent(f.choiceGroup, () => []).add(f);
    }
    final shownGroups = <String>{};

    return Scaffold(
      appBar: AppBar(title: Text(deal.template.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const _Heading('Buyer'),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Buyer name'),
              textCapitalization: TextCapitalization.words,
              validator: _required,
              onChanged: (v) => deal.buyerName = v.trim(),
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Buyer email (for their copy)',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: _required,
              onChanged: (v) => deal.buyerEmail = v.trim(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Second buyer'),
              value: deal.hasBuyer2,
              onChanged: (v) => setState(() => deal.hasBuyer2 = v),
            ),
            if (deal.hasBuyer2) ...[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Second buyer name',
                ),
                textCapitalization: TextCapitalization.words,
                validator: _required,
                onChanged: (v) => deal.buyer2Name = v.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Second buyer email',
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => deal.buyer2Email = v.trim(),
              ),
            ],
            const SizedBox(height: 16),
            const _Heading('This agreement'),
            for (final g in dates.values)
              _DateField(
                label: _dateLabel(g),
                onPicked: (d) {
                  g.fill(deal.values, d);
                  if (g.key.contains('end')) deal.endDate = d;
                },
              ),
            for (final f in perDeal)
              if (!inDate.contains(f.id))
                if (f.choiceGroup.isNotEmpty)
                  if (shownGroups.add(f.choiceGroup))
                    _ChoiceGroup(
                      options: groups[f.choiceGroup]!,
                      values: deal.values,
                    )
                  else
                    const SizedBox.shrink()
                else
                  _ValueField(field: f, values: deal.values),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _handOver,
            icon: const Icon(Icons.phone_iphone),
            label: const Text('Hand to buyer to review & sign'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(SplitDate g) {
    final label = (g.day ?? g.month ?? g.year)!.label;
    return label.replaceAll(
      RegExp(r'\s*\((day|month|year)\)', caseSensitive: false),
      '',
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _handOver() {
    if (!_formKey.currentState!.validate()) return;
    deal.autofill();
    context.push('/templates/${deal.template.id}/sign', extra: deal);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _ValueField extends StatefulWidget {
  const _ValueField({required this.field, required this.values});

  final TemplateField field;
  final Map<String, Object> values;

  @override
  State<_ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<_ValueField> {
  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    switch (f.kind) {
      case FieldKind.checkbox:
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: widget.values[f.id] == true,
          onChanged: (v) => setState(() => widget.values[f.id] = v ?? false),
        );
      case FieldKind.date:
        return _DateField(
          label: f.label,
          onPicked:
              (d) => widget.values[f.id] = DateFormat('M/d/yyyy').format(d),
        );
      case FieldKind.signature || FieldKind.initials:
        return const SizedBox.shrink();
      case FieldKind.number || FieldKind.currency || FieldKind.percent:
        return TextFormField(
          initialValue: widget.values[f.id] as String?,
          decoration: InputDecoration(
            labelText: f.label,
            prefixText: f.kind == FieldKind.currency ? r'$ ' : null,
            suffixText: f.kind == FieldKind.percent ? '%' : null,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
          ],
          onChanged: (v) => widget.values[f.id] = v.trim(),
        );
      case FieldKind.text:
        return TextFormField(
          initialValue: widget.values[f.id] as String?,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => widget.values[f.id] = v.trim(),
        );
    }
  }
}

/// "Check one" options shown as a radio list.
class _ChoiceGroup extends StatefulWidget {
  const _ChoiceGroup({required this.options, required this.values});

  final List<TemplateField> options;
  final Map<String, Object> values;

  @override
  State<_ChoiceGroup> createState() => _ChoiceGroupState();
}

class _ChoiceGroupState extends State<_ChoiceGroup> {
  @override
  Widget build(BuildContext context) {
    final picked =
        widget.options.where((o) => widget.values[o.id] == true).firstOrNull;
    return RadioGroup<String>(
      groupValue: picked?.id,
      onChanged:
          (id) => setState(() {
            for (final o in widget.options) {
              widget.values[o.id] = o.id == id;
            }
          }),
      child: Column(
        children: [
          for (final o in widget.options)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: o.id,
              title: Text(o.label),
            ),
        ],
      ),
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({required this.label, required this.onPicked});

  final String label;
  final void Function(DateTime) onPicked;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
        setState(() => _date = d);
        widget.onPicked(d);
      },
    );
  }
}
