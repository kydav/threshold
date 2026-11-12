import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/features/templates/data/form_capture_service.dart';
import 'package:threshold/features/templates/data/form_imports.dart';
import 'package:threshold/features/templates/presentation/scan_review_screen.dart';

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

  /// Scanned pages go through a review first, where a bad page can be
  /// retaken or removed before anything is read.
  Future<({List<Uint8List> pages, Uint8List? pdf})?> _scan() async {
    final scanned = await _capture.scan();
    if (scanned == null || scanned.isEmpty || !mounted) return null;
    setState(() => _step = null);
    final reviewed = await Navigator.of(context).push<List<Uint8List>>(
      MaterialPageRoute(
        builder: (_) => ScanReviewScreen(pages: scanned, capture: _capture),
      ),
    );
    if (reviewed == null || reviewed.isEmpty) return null;
    return (pages: reviewed, pdf: null);
  }

  Future<({List<Uint8List> pages, Uint8List? pdf})?> _pdf() async {
    final picked = await _capture.pickPdf();
    return picked == null ? null : (pages: picked.pages, pdf: picked.pdf);
  }

  Future<void> _run(
    Future<({List<Uint8List> pages, Uint8List? pdf})?> Function() source,
  ) async {
    setState(() {
      _error = null;
      _step = 'Opening…';
    });
    try {
      final picked = await source();
      if (picked == null || picked.pages.isEmpty) {
        setState(() => _step = null);
        return;
      }
      final images = picked.pages;

      final pages = <CapturedPage>[];
      for (var i = 0; i < images.length; i++) {
        setState(() => _step = 'Reading page ${i + 1} of ${images.length}…');
        pages.add(await _capture.prepare(images[i]));
      }

      setState(() => _step = 'Sending to Threshold…');
      final template = await ref
          .read(formImportsProvider.notifier)
          .start(pages, pdf: picked.pdf);
      if (!mounted) return;
      if (template != null) {
        // Someone already set up this form: it's ready now.
        context.pushReplacement('/templates/${template.id}/review');
        return;
      }
      // Reading it takes a minute or two; that happens on the server. The
      // form waits on My forms, and the agent can leave the app meanwhile.
      context.go('/templates');
    } on TooManyPagesException catch (e) {
      setState(() {
        _step = null;
        _error =
            'This PDF has ${e.pages} pages. Threshold reads up to '
            '$kMaxFormPages at a time: save just the agreement and any '
            'addenda you need as their own PDF, then try again.';
      });
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
                        onPressed: () => _run(_scan),
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('Scan paper pages'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _run(_pdf),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Upload a PDF'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tip: scan on a flat surface in good light. The '
                        'scanner snaps each page on its own once it is '
                        'sharp. To take each one yourself, tap Auto at the '
                        'top of the scanner to switch to Manual. You can '
                        'check every page and retake any before it is read.',
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
