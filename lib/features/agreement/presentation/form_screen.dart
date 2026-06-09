import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/auth/data/agent_profile_store.dart';

class FormScreen extends ConsumerStatefulWidget {
  const FormScreen({super.key});

  @override
  ConsumerState<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends ConsumerState<FormScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _saving = false;

  // Field controllers
  final _buyerNameCtrl = TextEditingController();
  final _buyerEmailCtrl = TextEditingController();
  final _propertyScopeCtrl = TextEditingController();
  final _compensationCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));

  // Per-step validation
  String? _stepError;

  @override
  void dispose() {
    _pageController.dispose();
    _buyerNameCtrl.dispose();
    _buyerEmailCtrl.dispose();
    _propertyScopeCtrl.dispose();
    _compensationCtrl.dispose();
    super.dispose();
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_buyerNameCtrl.text.trim().isEmpty) {
          setState(() => _stepError = "Buyer's name is required.");
          return false;
        }
      case 1:
        final email = _buyerEmailCtrl.text.trim();
        if (!email.contains('@') || !email.contains('.')) {
          setState(() => _stepError = 'Enter a valid email address.');
          return false;
        }
      case 2:
        if (_propertyScopeCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Property scope is required.');
          return false;
        }
      case 3:
        if (_compensationCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Compensation is required.');
          return false;
        }
      case 4:
        if (!_endDate.isAfter(_startDate)) {
          setState(() => _stepError = 'End date must be after start date.');
          return false;
        }
    }
    setState(() => _stepError = null);
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < 4) {
      setState(() => _step++);
      _pageController.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() {
        _step--;
        _stepError = null;
      });
      _pageController.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.go('/agreements');
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final profile = await ref.read(agentProfileStoreProvider).load();
      final agreement = await ref
          .read(agreementRepositoryProvider)
          .create(
            agentId: user.uid,
            agentName: profile?.agentName ?? user.displayName ?? '',
            agentEmail: profile?.agentEmail ?? user.email ?? '',
            brokerageName: profile?.brokerageName ?? '',
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
    final cs = Theme.of(context).colorScheme;
    const totalSteps = 5;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text(_stepTitle(_step)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / totalSteps,
            backgroundColor: cs.surfaceContainerHighest,
            color: cs.primary,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _StepPage(
            prompt: "What's the buyer's name?",
            hint: 'Full legal name',
            controller: _buyerNameCtrl,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            error: _step == 0 ? _stepError : null,
            onSubmit: _next,
          ),
          _StepPage(
            prompt: "What's the buyer's email?",
            hint: 'email@example.com',
            controller: _buyerEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            error: _step == 1 ? _stepError : null,
            onSubmit: _next,
          ),
          _StepPage(
            prompt: 'What property are you showing?',
            hint: 'e.g. 123 Main St or any home in Denver metro',
            controller: _propertyScopeCtrl,
            keyboardType: TextInputType.streetAddress,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            error: _step == 2 ? _stepError : null,
            onSubmit: _next,
          ),
          _StepPage(
            prompt: "What's your buyer agent compensation?",
            hint: 'e.g. 2.5% or \$10,000',
            controller: _compensationCtrl,
            error: _step == 3 ? _stepError : null,
            onSubmit: _next,
          ),
          _DateStepPage(
            startDate: _startDate,
            endDate: _endDate,
            error: _step == 4 ? _stepError : null,
            onStartChanged: (d) => setState(() => _startDate = d),
            onEndChanged: (d) => setState(() => _endDate = d),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : _next,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child:
                _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_step < 4 ? 'Next' : 'Proceed to signatures'),
          ),
        ),
      ),
    );
  }

  String _stepTitle(int step) => switch (step) {
    0 => 'Buyer name',
    1 => 'Buyer email',
    2 => 'Property',
    3 => 'Compensation',
    4 => 'Agreement dates',
    _ => 'New agreement',
  };
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.prompt,
    required this.hint,
    required this.controller,
    required this.onSubmit,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.error,
  });

  final String prompt;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            autofocus: true,
            textInputAction: maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
            onSubmitted: maxLines == 1 ? (_) => onSubmit() : null,
            decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder(), errorText: error),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _DateStepPage extends StatelessWidget {
  const _DateStepPage({
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
    this.error,
  });

  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;
  final String? error;

  Future<void> _pick(
    BuildContext context, {
    required bool isStart,
    required DateTime current,
    required DateTime min,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: min,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How long does the agreement last?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'NAR rules require a defined term. 90 days is common for a showing.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          _DateTile(
            label: 'Start date',
            date: startDate,
            onTap:
                () => _pick(
                  context,
                  isStart: true,
                  current: startDate,
                  min: now.subtract(const Duration(days: 1)),
                  onChanged: onStartChanged,
                ),
          ),
          const SizedBox(height: 16),
          _DateTile(
            label: 'End date',
            date: endDate,
            onTap:
                () => _pick(
                  context,
                  isStart: false,
                  current: endDate,
                  min: startDate.add(const Duration(days: 1)),
                  onChanged: onEndChanged,
                ),
          ),
          if (error != null) ...[const SizedBox(height: 12), Text(error!, style: TextStyle(color: cs.error, fontSize: 13))],
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  static final _fmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(border: Border.all(color: cs.outline), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: cs.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                Text(_fmt.format(date), style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
