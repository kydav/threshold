import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/agreement_repository.dart';
import '../../auth/data/auth_service.dart';

class FormScreen extends ConsumerStatefulWidget {
  const FormScreen({super.key});

  @override
  ConsumerState<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends ConsumerState<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _buyerNameCtrl = TextEditingController();
  final _buyerEmailCtrl = TextEditingController();
  final _propertyScopeCtrl = TextEditingController();
  final _compensationCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));
  bool _saving = false;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void dispose() {
    _buyerNameCtrl.dispose();
    _buyerEmailCtrl.dispose();
    _propertyScopeCtrl.dispose();
    _compensationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: isStart ? now.subtract(const Duration(days: 1)) : _startDate,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 90));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final profile = await ref.read(agentProfileProvider.future);
      final agreement =
          await ref.read(agreementRepositoryProvider).create(
                agentId: user.uid,
                agentName: profile?['agentName'] as String? ??
                    user.displayName ??
                    '',
                agentEmail:
                    profile?['agentEmail'] as String? ?? user.email ?? '',
                brokerageName:
                    profile?['brokerageName'] as String? ?? '',
                buyerName: _buyerNameCtrl.text.trim(),
                buyerEmail: _buyerEmailCtrl.text.trim(),
                propertyScope: _propertyScopeCtrl.text.trim(),
                compensation: _compensationCtrl.text.trim(),
                startDate: _startDate,
                endDate: _endDate,
              );
      if (mounted) context.go('/agreements/${agreement.id}/sign');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New agreement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel(context, 'Buyer information'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _buyerNameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Buyer full name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _buyerEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Buyer email',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 24),
              _sectionLabel(context, 'Agreement terms'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _propertyScopeCtrl,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Property scope',
                  hintText: 'e.g. 123 Main St, Denver CO or Any property in Denver metro',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _compensationCtrl,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Buyer agent compensation',
                  hintText: 'e.g. 2.5% or \$10,000',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              _sectionLabel(context, 'Agreement period'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start date',
                      date: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'End date',
                      date: _endDate,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.draw_outlined),
                label: const Text('Proceed to signatures'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  static final _fmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(_fmt.format(date)),
      ),
    );
  }
}
