import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/features/templates/data/form_capture_service.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

/// Scan a paper form or pick a PDF, then read and map it into a template.
class TemplateCaptureScreen extends ConsumerStatefulWidget {
  const TemplateCaptureScreen({super.key});

  @override
  ConsumerState<TemplateCaptureScreen> createState() =>
      _TemplateCaptureScreenState();
}

class _TemplateCaptureScreenState extends ConsumerState<TemplateCaptureScreen> {
  final _capture = FormCaptureService();

  /// What's happening right now; null when idle.
  String? _step;
  String? _error;

  Future<void> _run(Future<List<Uint8List>?> Function() source) async {
    setState(() {
      _error = null;
      _step = 'Opening…';
    });
    try {
      final images = await source();
      if (images == null || images.isEmpty) {
        setState(() => _step = null);
        return;
      }

      final pages = <CapturedPage>[];
      for (var i = 0; i < images.length; i++) {
        setState(() => _step = 'Reading page ${i + 1} of ${images.length}…');
        pages.add(await _capture.prepare(images[i]));
      }

      setState(
        () =>
            _step =
                'Finding every blank and signature line…\n'
                'This takes about a minute.',
      );
      final map = await _capture.mapFields(pages);

      setState(() => _step = 'Cleaning up the pages…');
      final repo = ref.read(templateRepositoryProvider);
      final template = await repo.create(pages: pages, map: map);
      ref.invalidate(templatesProvider);

      if (!mounted) return;
      context.pushReplacement('/templates/${template.id}/review');
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _step = null;
        _error = e.message ?? 'Could not read the form. Please try again.';
      });
    } catch (e) {
      setState(() {
        _step = null;
        _error = 'Something went wrong: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final busy = _step != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Add a form')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              busy
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _step!,
                          textAlign: TextAlign.center,
                          style: text.bodyLarge,
                        ),
                      ],
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Use a blank copy if you have one. A filled-in copy '
                        'works too: Threshold erases the old answers.',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _run(_capture.scan),
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('Scan paper pages'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _run(_capture.pickPdf),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Upload a PDF'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tip: scan on a flat surface in good light. The '
                        'scanner snaps each page when it is sharp.',
                        style: text.bodySmall,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          _error!,
                          style: text.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
        ),
      ),
    );
  }
}
