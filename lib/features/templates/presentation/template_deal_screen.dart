import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/features/paywall/data/agreement_quota.dart';
import 'package:threshold/features/templates/data/form_template.dart';
import 'package:threshold/features/templates/data/template_deal.dart';
import 'package:threshold/features/templates/data/template_repository.dart';
import 'package:threshold/features/templates/presentation/terms_form.dart';

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
                      : _DealForm(template: t),
        );
  }
}

class _DealForm extends ConsumerStatefulWidget {
  const _DealForm({required this.template});

  final FormTemplate template;

  @override
  ConsumerState<_DealForm> createState() => _DealFormState();
}

class _DealFormState extends ConsumerState<_DealForm> {
  final _formKey = GlobalKey<FormState>();

  // Made once: the screen above rebuilds (going to the sign screen and
  // back), and a fresh deal would drop everything typed so far.
  late final TemplateDeal deal = TemplateDeal(widget.template);
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _name2 = TextEditingController();
  final _email2 = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _name2, _email2]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(deal.template.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const _Heading('Buyer'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Buyer name'),
              textCapitalization: TextCapitalization.words,
              validator: _required,
              onChanged: (v) => deal.buyerName = v.trim(),
            ),
            TextFormField(
              controller: _email,
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
                controller: _name2,
                decoration: const InputDecoration(
                  labelText: 'Second buyer name',
                ),
                textCapitalization: TextCapitalization.words,
                validator: _required,
                onChanged: (v) => deal.buyer2Name = v.trim(),
              ),
              TextFormField(
                controller: _email2,
                decoration: const InputDecoration(
                  labelText: 'Second buyer email',
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => deal.buyer2Email = v.trim(),
              ),
            ],
            const SizedBox(height: 16),
            TermsForm(
              key: ValueKey(deal.hasBuyer2),
              deal: deal,
              fields: deal.active(FieldFiller.agentPerDeal),
              collapseUsual: true,
            ),
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _handOver() async {
    if (!_formKey.currentState!.validate()) return;
    // Check the free limit before the buyer gets the phone, not after
    // they've signed.
    if (!await canSendAgreement(context, ref) || !mounted) return;
    // Read straight from the fields, so what's on screen is what's signed.
    deal
      ..buyerName = _name.text.trim()
      ..buyerEmail = _email.text.trim()
      ..buyer2Name = deal.hasBuyer2 ? _name2.text.trim() : ''
      ..buyer2Email = deal.hasBuyer2 ? _email2.text.trim() : ''
      ..autofill();
    await context.push('/templates/${deal.template.id}/sign', extra: deal);
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
