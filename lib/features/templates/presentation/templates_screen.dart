import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

/// The agent's own forms: add one by scanning or uploading, then start a
/// signing from it.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My forms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/templates/new'),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Add a form'),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load forms: $e')),
        data:
            (list) =>
                list.isEmpty
                    ? const _Empty()
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _TemplateCard(template: list[i]),
                    ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Bring your own form', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Scan the buyer agreement you already use, or upload it as a '
              'PDF. Threshold finds every blank, initial and signature line, '
              'and turns it into a form your buyers can sign on your phone.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});

  final FormTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(templateRepositoryProvider);
    final buyerCount = template.fieldsBy(FieldFiller.buyer).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/templates/${template.id}/deal'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 84,
                child: FutureBuilder<File>(
                  future: repo.pageFile(template, 0),
                  builder:
                      (_, snap) =>
                          snap.hasData
                              ? Image.file(snap.data!, fit: BoxFit.cover)
                              : const ColoredBox(color: Colors.black12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${template.pages.length} pages · '
                      '${template.fields.length} fields · '
                      '$buyerCount for the buyer',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Added ${DateFormat.yMMMd().format(template.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'review') {
                    await context.push('/templates/${template.id}/review');
                  } else if (v == 'delete') {
                    await repo.delete(template.id);
                    ref.invalidate(templatesProvider);
                  }
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(
                        value: 'review',
                        child: Text('Edit fields'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
