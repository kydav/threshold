import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:threshold/core/services/delivery_service.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_deal.dart';
import 'package:threshold/features/templates/data/template_pdf_service.dart';
import 'package:threshold/features/templates/data/template_repository.dart';

final _pdfProvider = Provider(
  (ref) => TemplatePdfService(ref.read(templateRepositoryProvider)),
);

enum _Step { review, details, buyer1, buyer2, agent, done }

/// The buyer's side, on the agent's phone: read the filled-in agreement,
/// agree to sign electronically, add any details, initial and sign. Then the
/// agent signs and the signed PDF is emailed to everyone.
class TemplateSignScreen extends ConsumerStatefulWidget {
  const TemplateSignScreen({required this.deal, super.key});

  final TemplateDeal deal;

  @override
  ConsumerState<TemplateSignScreen> createState() => _TemplateSignScreenState();
}

class _TemplateSignScreenState extends ConsumerState<TemplateSignScreen> {
  _Step _step = _Step.review;
  bool _consent1 = false;
  bool _consent2 = false;
  DateTime? _consentAt;
  bool _working = false;
  String? _error;

  final _initials1 = GlobalKey<SfSignaturePadState>();
  final _signature1 = GlobalKey<SfSignaturePadState>();
  final _initials2 = GlobalKey<SfSignaturePadState>();
  final _signature2 = GlobalKey<SfSignaturePadState>();
  final _agentSig = GlobalKey<SfSignaturePadState>();

  TemplateDeal get deal => widget.deal;

  /// Buyer fields still empty after autofill that aren't ink: address,
  /// phone, any box the buyer checks.
  List<TemplateField> get _detailFields => [
    for (final f in deal.active(FieldFiller.buyer))
      if (!f.kind.isInk &&
          f.kind != FieldKind.date &&
          deal.values[f.id] == null)
        f,
  ];

  bool get _needsAgentSig => deal
      .active(FieldFiller.agentSign)
      .any((f) => f.kind == FieldKind.signature);

  _Step _next(_Step s) => switch (s) {
    _Step.review => _detailFields.isEmpty ? _Step.buyer1 : _Step.details,
    _Step.details => _Step.buyer1,
    _Step.buyer1 => deal.hasBuyer2 ? _Step.buyer2 : _afterBuyers,
    _Step.buyer2 => _afterBuyers,
    _Step.agent || _Step.done => _Step.done,
  };

  _Step get _afterBuyers => _needsAgentSig ? _Step.agent : _Step.done;

  Future<Uint8List?> _png(GlobalKey<SfSignaturePadState> key) async {
    final state = key.currentState;
    if (state == null || state.toPathList().isEmpty) return null;
    final image = await state.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  /// Stamps one signer's initials and signature into every matching box.
  Future<bool> _applyInk(
    int buyer,
    GlobalKey<SfSignaturePadState> initials,
    GlobalKey<SfSignaturePadState> signature, {
    required String name,
    required String email,
    required String role,
  }) async {
    final fields =
        role == 'Agent'
            ? deal.active(FieldFiller.agentSign)
            : deal
                .active(FieldFiller.buyer)
                .where((f) => TemplateDeal.buyerIndex(f) == buyer)
                .toList();
    final needsInitials = fields.any((f) => f.kind == FieldKind.initials);
    final sig = await _png(signature);
    final ini = needsInitials ? await _png(initials) : null;
    if (sig == null || (needsInitials && ini == null)) {
      setState(
        () =>
            _error =
                needsInitials
                    ? 'Please add both initials and a signature.'
                    : 'Please sign above.',
      );
      return false;
    }
    for (final f in fields) {
      if (f.kind == FieldKind.signature) deal.values[f.id] = sig;
      // The footer initials boxes are shared; the first buyer's go there.
      if (f.kind == FieldKind.initials && ini != null) deal.values[f.id] = ini;
    }
    deal.events.add(
      SignatureEvent(
        name: name,
        role: role,
        email: email,
        consentedAt: _consentAt ?? DateTime.now(),
        signedAt: DateTime.now(),
      ),
    );
    return true;
  }

  Future<void> _continue() async {
    setState(() => _error = null);
    switch (_step) {
      case _Step.review:
        if (!_consent1 || (deal.hasBuyer2 && !_consent2)) {
          setState(() => _error = 'Each buyer needs to agree to continue.');
          return;
        }
        _consentAt = DateTime.now();
      case _Step.details:
        break;
      case _Step.buyer1:
        if (!await _applyInk(
          1,
          _initials1,
          _signature1,
          name: deal.buyerName,
          email: deal.buyerEmail,
          role: 'Buyer',
        )) {
          return;
        }
      case _Step.buyer2:
        if (!await _applyInk(
          2,
          _initials2,
          _signature2,
          name: deal.buyer2Name,
          email: deal.buyer2Email,
          role: 'Buyer',
        )) {
          return;
        }
      case _Step.agent:
        final profile = ref.read(userProfileProvider);
        if (!await _applyInk(
          0,
          _agentSig,
          _agentSig,
          name: profile?.fullName ?? 'Agent',
          email: profile?.email ?? '',
          role: 'Agent',
        )) {
          return;
        }
      case _Step.done:
        return;
    }
    final next = _next(_step);
    if (next == _Step.done) {
      await _finish();
    } else {
      setState(() => _step = next);
    }
  }

  Future<void> _finish() async {
    setState(() => _working = true);
    try {
      final profile = ref.read(userProfileProvider);
      final repo = ref.read(agreementRepositoryProvider);
      final now = DateTime.now();
      final record = await repo.create(
        agentId: FirebaseAuth.instance.currentUser?.uid ?? '',
        agentName: profile?.fullName ?? '',
        agentEmail: profile?.email ?? '',
        brokerageName: profile?.brokerageName ?? '',
        buyerName: deal.buyerName,
        buyerEmail: deal.buyerEmail,
        propertyScope:
            deal.summary.isEmpty ? deal.template.title : deal.summary,
        compensation: deal.summary,
        startDate: now,
        endDate: deal.endDate ?? now,
        formState: 'Custom',
        formData: {
          'templateId': deal.template.id,
          'templateTitle': deal.template.title,
          if (deal.hasBuyer2) 'buyer2Name': deal.buyer2Name,
          if (deal.hasBuyer2) 'buyer2Email': deal.buyer2Email,
        },
      );

      final pdf = await ref
          .read(_pdfProvider)
          .render(
            template: deal.template,
            values: deal.values,
            agreementId: record.id,
            events: deal.events,
          );
      final dir = await getApplicationDocumentsDirectory();
      final safe = deal.buyerName.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
      final file = File(
        '${dir.path}/agreement_${safe}_${record.id.substring(0, 8)}.pdf',
      );
      await file.writeAsBytes(pdf.bytes);

      final signed = record.copyWith(
        status: AgreementStatus.pendingDelivery,
        localPdfPath: file.path,
        signedAt: now,
      );
      await repo.save(signed);
      // Delivery retries on reconnect if this fails (no signal at the door).
      await ref.read(deliveryServiceProvider).deliver(signed);
      await ref.read(agreementListProvider.notifier).refresh();
      if (mounted) setState(() => _step = _Step.done);
    } catch (e) {
      setState(() => _error = 'Could not finish: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _Step.review || _step == _Step.done,
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (_step) {
            _Step.review => 'Review the agreement',
            _Step.details => 'A few details',
            _Step.buyer1 => 'Initial and sign',
            _Step.buyer2 => '${deal.buyer2Name}: initial and sign',
            _Step.agent => 'Agent signature',
            _Step.done => 'All signed',
          }),
          automaticallyImplyLeading: _step == _Step.review,
        ),
        body: switch (_step) {
          _Step.review => _review(),
          _Step.details => _details(),
          _Step.buyer1 => _inkStep(deal.buyerName, _initials1, _signature1, 1),
          _Step.buyer2 => _inkStep(deal.buyer2Name, _initials2, _signature2, 2),
          _Step.agent => _agentStep(),
          _Step.done => _done(),
        },
        bottomNavigationBar:
            _step == _Step.done
                ? null
                : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: _working ? null : _continue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                          child:
                              _working
                                  ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    _step == _Step.review
                                        ? 'I have read it, continue'
                                        : _next(_step) == _Step.done
                                        ? 'Finish and send copies'
                                        : 'Continue',
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _review() {
    final repo = ref.read(templateRepositoryProvider);
    final names = [
      deal.buyerName,
      if (deal.hasBuyer2) deal.buyer2Name,
    ].join(' and ');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Hi $names. This is the agreement your agent filled in. Read it '
          'through, and ask about anything that is unclear before you sign.',
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < deal.template.pages.length; i++) ...[
          FutureBuilder<File>(
            future: repo.pageFile(deal.template, i),
            builder:
                (_, snap) =>
                    snap.hasData
                        ? InteractiveViewer(
                          maxScale: 4,
                          child: FilledPage(
                            file: snap.data!,
                            page: deal.template.pages[i],
                            fields: deal.template.fields.where(
                              (f) => f.page == i + 1,
                            ),
                            values: deal.values,
                          ),
                        )
                        : const AspectRatio(
                          aspectRatio: 0.77,
                          child: ColoredBox(color: Colors.black12),
                        ),
          ),
          const SizedBox(height: 12),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent1,
          onChanged: (v) => setState(() => _consent1 = v ?? false),
          title: Text(
            '${deal.buyerName}: I agree to sign this agreement electronically '
            'and to receive my copy by email.',
          ),
        ),
        if (deal.hasBuyer2)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent2,
            onChanged: (v) => setState(() => _consent2 = v ?? false),
            title: Text(
              '${deal.buyer2Name}: I agree to sign this agreement '
              'electronically and to receive my copy by email.',
            ),
          ),
      ],
    );
  }

  Widget _details() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final f in _detailFields)
          if (f.kind == FieldKind.checkbox)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(f.label),
              value: deal.values[f.id] == true,
              onChanged: (v) => setState(() => deal.values[f.id] = v ?? false),
            )
          else
            TextFormField(
              decoration: InputDecoration(labelText: f.label),
              onChanged: (v) => deal.values[f.id] = v.trim(),
            ),
      ],
    );
  }

  Widget _inkStep(
    String name,
    GlobalKey<SfSignaturePadState> initials,
    GlobalKey<SfSignaturePadState> signature,
    int buyer,
  ) {
    final initialCount =
        deal
            .active(FieldFiller.buyer)
            .where(
              (f) =>
                  f.kind == FieldKind.initials &&
                  TemplateDeal.buyerIndex(f) == buyer,
            )
            .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        if (initialCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Your initials (used on all $initialCount pages)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          _Pad(padKey: initials, height: 110),
        ],
        const SizedBox(height: 16),
        Text('Your signature', style: Theme.of(context).textTheme.labelLarge),
        _Pad(padKey: signature, height: 170),
      ],
    );
  }

  Widget _agentStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Hand the phone back to your agent to sign.'),
        const SizedBox(height: 16),
        Text('Agent signature', style: Theme.of(context).textTheme.labelLarge),
        _Pad(padKey: _agentSig, height: 170),
      ],
    );
  }

  Widget _done() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_outlined, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text('Signed', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Everyone gets a copy by email. If there was no signal, it '
              'sends as soon as the phone is back online.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.padKey, required this.height});

  final GlobalKey<SfSignaturePadState> padKey;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          height: height,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SfSignaturePad(
            key: padKey,
            strokeColor: const Color(0xFF0B1F6B),
            minimumStrokeWidth: 1.5,
            maximumStrokeWidth: 3.5,
          ),
        ),
        TextButton(
          onPressed: () => padKey.currentState?.clear(),
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

/// A page with the deal's values drawn into their boxes, for review.
class FilledPage extends StatelessWidget {
  const FilledPage({
    required this.file,
    required this.page,
    required this.fields,
    required this.values,
    super.key,
  });

  final File file;
  final TemplatePage page;
  final Iterable<TemplateField> fields;
  final Map<String, Object> values;

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
                if (values[f.id] case final Object v)
                  Positioned(
                    left: f.box.left * scale,
                    top: f.box.top * scale,
                    width: f.box.width * scale,
                    height: f.box.height * scale,
                    child: switch (v) {
                      final Uint8List png => Image.memory(
                        png,
                        alignment: Alignment.bottomLeft,
                      ),
                      true => const FittedBox(child: Text('X')),
                      false => const SizedBox.shrink(),
                      _ => Align(
                        alignment: Alignment.bottomLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$v',
                            style: const TextStyle(color: Color(0xFF0B1F6B)),
                          ),
                        ),
                      ),
                    },
                  ),
            ],
          ),
        );
      },
    );
  }
}
