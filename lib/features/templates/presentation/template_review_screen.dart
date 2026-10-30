import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

Color fillerColor(FieldFiller f) => switch (f) {
  FieldFiller.agentOnce => const Color(0xFF3478F6),
  FieldFiller.agentPerDeal => const Color(0xFFF59E0B),
  FieldFiller.buyer => const Color(0xFF16A34A),
  FieldFiller.agentSign => const Color(0xFF9333EA),
};

final _templateProvider = FutureProvider.family<FormTemplate?, String>((
  ref,
  id,
) async {
  final all = await ref.watch(templateRepositoryProvider).all();
  return all.where((t) => t.id == id).firstOrNull;
});

/// Check what the AI found: drag a box to fix its position, tap it to change
/// what it is, and fill in your own details once.
class TemplateReviewScreen extends ConsumerWidget {
  const TemplateReviewScreen({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(_templateProvider(templateId));
    return t.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data:
          (template) =>
              template == null
                  ? const Scaffold(body: Center(child: Text('Form not found')))
                  : _Review(template: template),
    );
  }
}

class _Review extends ConsumerStatefulWidget {
  const _Review({required this.template});

  final FormTemplate template;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  late final TextEditingController _title = TextEditingController(
    text: widget.template.title,
  );
  final Map<String, TextEditingController> _agent = {};
  bool _saving = false;

  FormTemplate get t => widget.template;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    for (final f in t.fieldsBy(FieldFiller.agentOnce)) {
      _agent[f.id] = TextEditingController(
        text: t.agentValues[f.id] ?? _guessFromProfile(f, profile),
      );
    }
  }

  /// Prefills the agent's details from their profile where the label makes
  /// the match obvious; the agent can correct anything.
  String _guessFromProfile(TemplateField f, UserProfile? p) {
    if (p == null) return '';
    final l = f.label.toLowerCase();
    if (l.contains('company') || l.contains('brokerage')) {
      return p.brokerageName;
    }
    if (l.contains('agent') || l.contains('licensee')) return p.fullName;
    if (l.contains('phone')) return p.phone;
    if (l.contains('email')) return p.email;
    return '';
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _agent.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    t.title = _title.text.trim().isEmpty ? t.title : _title.text.trim();
    t.agentValues
      ..clear()
      ..addAll({for (final e in _agent.entries) e.key: e.value.text.trim()});
    await ref.read(templateRepositoryProvider).save(t);
    ref.invalidate(templatesProvider);
    if (mounted) context.go('/templates');
  }

  Future<void> _edit(TemplateField f) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FieldSheet(field: f),
    );
    if (changed == null) return;
    setState(() {
      if (!changed) t.fields.remove(f); // false = delete
      _agent.putIfAbsent(
        f.id,
        () => TextEditingController(text: t.agentValues[f.id] ?? ''),
      );
      if (f.filledBy != FieldFiller.agentOnce) _agent.remove(f.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(templateRepositoryProvider);
    final agentFields = t.fieldsBy(FieldFiller.agentOnce).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check your form'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Form name'),
          ),
          const SizedBox(height: 12),
          const _Legend(),
          const SizedBox(height: 8),
          Text(
            'Drag a box if it is in the wrong spot. Tap it to change or '
            'remove it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < t.pages.length; i++) ...[
            FutureBuilder<File>(
              future: repo.pageFile(t, i),
              builder:
                  (_, snap) =>
                      snap.hasData
                          ? _PageEditor(
                            file: snap.data!,
                            page: t.pages[i],
                            fields:
                                t.fields.where((f) => f.page == i + 1).toList(),
                            onTap: _edit,
                            onMoved: () => setState(() {}),
                          )
                          : const AspectRatio(
                            aspectRatio: 0.77,
                            child: ColoredBox(color: Colors.black12),
                          ),
            ),
            const SizedBox(height: 16),
          ],
          if (agentFields.isNotEmpty) ...[
            Text(
              'Your details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Filled in on every agreement from this form.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final f in agentFields)
              if (_agent[f.id] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _agent[f.id],
                    decoration: InputDecoration(labelText: f.label),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final f in FieldFiller.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: fillerColor(f), width: 2),
                ),
              ),
              const SizedBox(width: 4),
              Text(f.label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

/// One page with its field boxes drawn on top; boxes can be dragged.
class _PageEditor extends StatelessWidget {
  const _PageEditor({
    required this.file,
    required this.page,
    required this.fields,
    required this.onTap,
    required this.onMoved,
  });

  final File file;
  final TemplatePage page;
  final List<TemplateField> fields;
  final void Function(TemplateField) onTap;
  final VoidCallback onMoved;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final scale = c.maxWidth / page.width;
        return SizedBox(
          width: c.maxWidth,
          height: page.height * scale,
          child: Stack(
            children: [
              Positioned.fill(child: Image.file(file, fit: BoxFit.fill)),
              for (final f in fields)
                Positioned(
                  left: f.box.left * scale,
                  top: f.box.top * scale,
                  width: (f.box.width * scale).clamp(12, double.infinity),
                  height: (f.box.height * scale).clamp(12, double.infinity),
                  child: GestureDetector(
                    onTap: () => onTap(f),
                    onPanUpdate: (d) {
                      f.box = f.box.shift(d.delta / scale);
                      onMoved();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: fillerColor(f.filledBy).withValues(alpha: 0.12),
                        border: Border.all(
                          color: fillerColor(f.filledBy),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Change what a field is, or remove it. Pops true when changed, false when
/// the field should be deleted.
class _FieldSheet extends StatefulWidget {
  const _FieldSheet({required this.field});

  final TemplateField field;

  @override
  State<_FieldSheet> createState() => _FieldSheetState();
}

class _FieldSheetState extends State<_FieldSheet> {
  late final TextEditingController _label = TextEditingController(
    text: widget.field.label,
  );
  late FieldFiller _filler = widget.field.filledBy;
  late FieldKind _kind = widget.field.kind;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Section ${widget.field.section}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'What goes here'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FieldFiller>(
            initialValue: _filler,
            decoration: const InputDecoration(labelText: 'Filled by'),
            items: [
              for (final f in FieldFiller.values)
                DropdownMenuItem(value: f, child: Text(f.label)),
            ],
            onChanged: (v) => setState(() => _filler = v ?? _filler),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FieldKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final k in FieldKind.values)
                DropdownMenuItem(value: k, child: Text(k.name)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              widget.field
                ..label = _label.text.trim()
                ..filledBy = _filler
                ..kind = _kind;
              Navigator.of(context).pop(true);
            },
            child: const Text('Done'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Remove this field'),
          ),
        ],
      ),
    );
  }
}
