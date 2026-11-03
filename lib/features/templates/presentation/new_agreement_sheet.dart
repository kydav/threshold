import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

/// What the + button starts: the state form, or one of the agent's own.
const _stateForm = 'state';

/// The agent's pick for the + button, kept on this phone (like the forms).
class NewAgreementDefault {
  Future<File> get _file async =>
      File('${(await getApplicationDocumentsDirectory()).path}/new_default');

  /// [_stateForm], a template id, or null for "ask each time".
  Future<String?> read() async {
    try {
      final f = await _file;
      if (!f.existsSync()) return null;
      final v = (await f.readAsString()).trim();
      return v.isEmpty ? null : v;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> write(String? choice) async {
    final f = await _file;
    if (choice == null) {
      if (f.existsSync()) await f.delete();
    } else {
      await f.writeAsString(choice);
    }
  }
}

final newAgreementDefaultProvider = Provider((_) => NewAgreementDefault());

/// The + button: straight to the default when one is set (and still
/// exists), straight to the state form when there are no own forms, else
/// asks.
Future<void> startNewAgreement(BuildContext context, WidgetRef ref) async {
  final templates = await ref.read(templatesProvider.future);
  final choice = await ref.read(newAgreementDefaultProvider).read();
  if (!context.mounted) return;
  if (choice == _stateForm || (choice == null && templates.isEmpty)) {
    await context.push('/agreements/new');
  } else if (templates.any((t) => t.id == choice)) {
    await context.push('/templates/$choice/deal');
  } else {
    await chooseNewAgreement(context, ref);
  }
}

/// The picker (also long-press on +, to change the default).
Future<void> chooseNewAgreement(BuildContext context, WidgetRef ref) async {
  final templates = await ref.read(templatesProvider.future);
  final current = await ref.read(newAgreementDefaultProvider).read();
  if (!context.mounted) return;
  final route = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Sheet(templates: templates, current: current),
  );
  if (route != null && context.mounted) await context.push(route);
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.templates, required this.current});

  final List<FormTemplate> templates;
  final String? current;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  late bool _remember = widget.current != null;

  Future<void> _pick(String choice, String route) async {
    await ref
        .read(newAgreementDefaultProvider)
        .write(_remember ? choice : null);
    if (mounted) Navigator.of(context).pop(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(userProfileProvider)?.state ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('New agreement', style: theme.textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(
              state.isEmpty ? 'Standard agreement' : '$state agreement',
            ),
            subtitle: const Text('The built-in form for your state'),
            trailing: _check(_stateForm),
            onTap: () => _pick(_stateForm, '/agreements/new'),
          ),
          for (final t in widget.templates)
            ListTile(
              leading: const Icon(Icons.edit_document),
              title: Text(t.title),
              subtitle: const Text('Your form'),
              trailing: _check(t.id),
              onTap: () => _pick(t.id, '/templates/${t.id}/deal'),
            ),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Add your own form'),
            subtitle: const Text('Scan it or upload a PDF'),
            onTap: () => Navigator.of(context).pop('/templates/new'),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Always start with my pick'),
            subtitle: const Text('Long-press + to choose again'),
            value: _remember,
            onChanged: (v) async {
              setState(() => _remember = v);
              if (!v) await ref.read(newAgreementDefaultProvider).write(null);
            },
          ),
        ],
      ),
    );
  }

  Widget? _check(String choice) =>
      widget.current == choice ? const Icon(Icons.check_rounded) : null;
}
