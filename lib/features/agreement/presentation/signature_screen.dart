import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/agreement/data/colorado_pdf_service.dart';
import 'package:threshold/features/agreement/data/pdf_service.dart';

class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({required this.agreementId, super.key});
  final String agreementId;

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final _agentPadKey = GlobalKey<SfSignaturePadState>();
  final _buyerPadKey = GlobalKey<SfSignaturePadState>();

  bool _agentSigned = false;
  bool _buyerSigned = false;
  bool _processing = false;
  AgreementModel? _agreement;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(agreementRepositoryProvider).get(widget.agreementId);
    if (mounted) setState(() => _agreement = a);
  }

  Future<void> _finalize() async {
    if (!_agentSigned || !_buyerSigned || _agreement == null) return;
    setState(() => _processing = true);
    try {
      final agentImg = await _agentPadKey.currentState!.toImage(pixelRatio: 2.0);
      final agentBytes =
          (await agentImg.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();

      final buyerImg = await _buyerPadKey.currentState!.toImage(pixelRatio: 2.0);
      final buyerBytes =
          (await buyerImg.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();

      String? path;
      if (_agreement!.formState == 'Colorado') {
        path = await ref.read(coloradoPdfServiceProvider).generate(
              agreement: _agreement!,
              agentSignatureBytes: agentBytes,
              buyerSignatureBytes: buyerBytes,
            );
      } else {
        path = await ref.read(pdfServiceProvider).generate(
              agreement: _agreement!,
              agentSignatureBytes: agentBytes,
              buyerSignatureBytes: buyerBytes,
            );
      }

      if (path != null && mounted) {
        ref.read(agreementListProvider.notifier).refresh();
        context.go('/agreements');
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_agreement == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Signatures')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryCard(context, _agreement!),
            const SizedBox(height: 24),
            _SignatureBlock(
              label: 'Agent signature — ${_agreement!.agentName}',
              padKey: _agentPadKey,
              signed: _agentSigned,
              onStrokeEnd: () => setState(() => _agentSigned = true),
              onClear: () {
                _agentPadKey.currentState?.clear();
                setState(() => _agentSigned = false);
              },
            ),
            const SizedBox(height: 20),
            _SignatureBlock(
              label: 'Buyer signature — ${_agreement!.buyerName}',
              padKey: _buyerPadKey,
              signed: _buyerSigned,
              onStrokeEnd: () => setState(() => _buyerSigned = true),
              onClear: () {
                _buyerPadKey.currentState?.clear();
                setState(() => _buyerSigned = false);
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: (_agentSigned && _buyerSigned && !_processing) ? _finalize : null,
              icon: _processing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generate & send PDF'),
            ),
            if (!_agentSigned || !_buyerSigned)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Both parties must sign before generating the PDF.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, AgreementModel a) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agreement summary', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _row('Buyer', a.buyerName),
            _row('Property', a.propertyScope),
            _row('Compensation', a.compensation),
            _row('Term', '${_fmt(a.startDate)} – ${_fmt(a.endDate)}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
            Expanded(child: Text(value)),
          ],
        ),
      );

  String _fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
}

class _SignatureBlock extends StatelessWidget {
  const _SignatureBlock({
    required this.label,
    required this.padKey,
    required this.signed,
    required this.onStrokeEnd,
    required this.onClear,
  });

  final String label;
  final GlobalKey<SfSignaturePadState> padKey;
  final bool signed;
  final VoidCallback onStrokeEnd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
            if (signed) Icon(Icons.check_circle, color: cs.primary, size: 20),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: signed ? cs.primary : cs.outline, width: signed ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
            color: cs.surface,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SfSignaturePad(
              key: padKey,
              backgroundColor: Colors.transparent,
              strokeColor: cs.onSurface,
              minimumStrokeWidth: 1.5,
              maximumStrokeWidth: 3.0,
              onDrawEnd: onStrokeEnd,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('Sign above', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}
