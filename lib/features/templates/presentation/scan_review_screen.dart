import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:threshold/features/templates/data/form_capture_service.dart';

/// Shows the scanned pages before anything is read, so a blurry or
/// half-caught page can be retaken, removed or followed by more pages.
/// Pops with the final pages, or null if the agent backs out.
class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({
    required this.pages,
    required this.capture,
    super.key,
  });

  final List<Uint8List> pages;
  final FormCaptureService capture;

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late final List<Uint8List> _pages = [...widget.pages];
  bool _busy = false;

  Future<void> _retake(int i) async {
    setState(() => _busy = true);
    try {
      final shot = await widget.capture.scan(maxPages: 1);
      if (shot != null && shot.isNotEmpty && mounted) {
        setState(() => _pages[i] = shot.first);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMore() async {
    final room = kMaxFormPages - _pages.length;
    if (room <= 0) return;
    setState(() => _busy = true);
    try {
      final more = await widget.capture.scan(maxPages: room);
      if (more != null && mounted) setState(() => _pages.addAll(more));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(int i) => setState(() => _pages.removeAt(i));

  Future<void> _open(int i) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Page ${i + 1}',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Retake this page'),
                  onTap: () => Navigator.pop(ctx, 'retake'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove this page'),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
              ],
            ),
          ),
    );
    switch (action) {
      case 'retake':
        await _retake(i);
      case 'remove':
        _remove(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final full = _pages.length >= kMaxFormPages;
    return Scaffold(
      appBar: AppBar(title: Text('Check your pages (${_pages.length})')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Make sure every page is sharp and whole. Tap a page to '
                'retake or remove it.',
                style: text.bodyMedium,
              ),
            ),
            Expanded(
              child:
                  _pages.isEmpty
                      ? Center(
                        child: Text('No pages yet.', style: text.bodyLarge),
                      )
                      : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 8.5 / 12,
                            ),
                        itemCount: _pages.length,
                        itemBuilder:
                            (context, i) => _PageTile(
                              number: i + 1,
                              image: _pages[i],
                              onTap: _busy ? null : () => _open(i),
                            ),
                      ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy || full ? null : _addMore,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      full ? '$kMaxFormPages pages is the most' : 'Add pages',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        _busy || _pages.isEmpty
                            ? null
                            : () => Navigator.pop(context, _pages),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: Text(
                      _pages.length == 1
                          ? 'Use this page'
                          : 'Use these ${_pages.length} pages',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({required this.number, required this.image, this.onTap});

  final int number;
  final Uint8List image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Page $number. Tap to retake or remove.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.memory(
                  image,
                  fit: BoxFit.contain,
                  cacheWidth: 400,
                  gaplessPlayback: true,
                ),
              ),
            ),
            Positioned(
              left: 6,
              top: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(color: scheme.onInverseSurface),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
