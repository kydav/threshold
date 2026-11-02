import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
