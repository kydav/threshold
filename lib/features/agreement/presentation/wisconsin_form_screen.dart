import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/auth/data/user_profile.dart';

class WisconsinFormScreen extends ConsumerStatefulWidget {
  const WisconsinFormScreen({super.key});

  @override
  ConsumerState<WisconsinFormScreen> createState() =>
      _WisconsinFormScreenState();
}

class _WisconsinFormScreenState extends ConsumerState<WisconsinFormScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _saving = false;
  String? _stepError;

  static const int _totalSteps = 8;

  // Step 0 — Buyer info
  final _buyerNameCtrl = TextEditingController();
  final _buyerAddressCtrl = TextEditingController();
  final _buyerEmailCtrl = TextEditingController();
  bool _commEmail = true;
  bool _commMail = false;

  // Step 1 — Firm representation
  // Values map to PDF radio export names: not_same_agent, neutral_firm, no_same_firm
  String? _firmRepresentation;

  // Step 2 — Co-buyer
  bool _hasCoBuyer = false;
  final _buyer2NameCtrl = TextEditingController();

  // Step 3 — Term
  DateTime _termStart = DateTime.now();
  DateTime _termEnd = DateTime.now().add(const Duration(days: 90));

  // Step 4 — Compensation (each multiline; PDF service splits by \n into form lines)
  final _commissionCtrl = TextEditingController();
  final _otherCompCtrl = TextEditingController();
  final _purchasePriceRangeCtrl = TextEditingController();

  // Step 5 — Excluded properties
  final _excludedPropertiesCtrl = TextEditingController();
  final _excludedPropertiesPriorCtrl = TextEditingController();
  final _exclusionDateCtrl = TextEditingController();

  // Step 6 — Confidential / non-confidential
  final _confidentialCtrl = TextEditingController();
  final _nonConfidentialCtrl = TextEditingController();

  // Step 7 — Additional provisions
  final _additionalProvisionsCtrl = TextEditingController();

  static final _dateFmt = DateFormat('MMMM d, yyyy');

  @override
  void dispose() {
    _pageController.dispose();
    _buyerNameCtrl.dispose();
    _buyerAddressCtrl.dispose();
    _buyerEmailCtrl.dispose();
    _buyer2NameCtrl.dispose();
    _commissionCtrl.dispose();
    _otherCompCtrl.dispose();
    _purchasePriceRangeCtrl.dispose();
    _excludedPropertiesCtrl.dispose();
    _excludedPropertiesPriorCtrl.dispose();
    _exclusionDateCtrl.dispose();
    _confidentialCtrl.dispose();
    _nonConfidentialCtrl.dispose();
    _additionalProvisionsCtrl.dispose();
    super.dispose();
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_buyerNameCtrl.text.trim().isEmpty) {
          setState(() => _stepError = "Buyer's full legal name is required.");
          return false;
        }
        final email = _buyerEmailCtrl.text.trim();
        if (!email.contains('@') || !email.contains('.')) {
          setState(() => _stepError = 'Enter a valid email address.');
          return false;
        }
      case 1:
        if (_firmRepresentation == null) {
          setState(
            () => _stepError = 'Please select a firm representation option.',
          );
          return false;
        }
      case 2:
        if (_hasCoBuyer && _buyer2NameCtrl.text.trim().isEmpty) {
          setState(() => _stepError = "Co-buyer's name is required.");
          return false;
        }
      case 4:
        if (_commissionCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Commission description is required.');
          return false;
        }
    }
    setState(() => _stepError = null);
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    FocusScope.of(context).unfocus();
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/agreements');
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final profile = ref.read(userProfileProvider);

      final agentName =
          '${profile?.firstName ?? ''} ${profile?.lastName ?? ''}'.trim();

      final buyerName = _buyerNameCtrl.text.trim();
      final displayBuyerName =
          _hasCoBuyer && _buyer2NameCtrl.text.trim().isNotEmpty
              ? '$buyerName and ${_buyer2NameCtrl.text.trim()}'
              : buyerName;

      final commission = _commissionCtrl.text.trim();

      final agreement = await ref
          .read(agreementRepositoryProvider)
          .create(
            agentId: user.uid,
            agentName:
                agentName.isNotEmpty ? agentName : user.displayName ?? '',
            agentEmail: profile?.email ?? user.email ?? '',
            brokerageName: profile?.brokerageName ?? '',
            buyerName:
                displayBuyerName.isNotEmpty
                    ? displayBuyerName
                    : user.email ?? '',
            buyerEmail: _buyerEmailCtrl.text.trim(),
            propertyScope: 'Wisconsin',
            compensation: commission,
            startDate: _termStart,
            endDate: _termEnd,
            formState: 'Wisconsin',
            formData: {
              'buyer_name': buyerName,
              'buyer_address': _buyerAddressCtrl.text.trim(),
              'buyer_email': _buyerEmailCtrl.text.trim(),
              'comm_email': _commEmail,
              'comm_mail': _commMail,
              'firm_representation': _firmRepresentation ?? '',
              'has_co_buyer': _hasCoBuyer,
              'buyer_name_2': _hasCoBuyer ? _buyer2NameCtrl.text.trim() : '',
              'term_start': _termStart.toIso8601String(),
              'term_end': _termEnd.toIso8601String(),
              'commission': _commissionCtrl.text.trim(),
              'other_compensation': _otherCompCtrl.text.trim(),
              'purchase_price_range': _purchasePriceRangeCtrl.text.trim(),
              'excluded_properties': _excludedPropertiesCtrl.text.trim(),
              'excluded_properties_prior':
                  _excludedPropertiesPriorCtrl.text.trim(),
              'exclusion_date': _exclusionDateCtrl.text.trim(),
              'confidential_info': _confidentialCtrl.text.trim(),
              'non_confidential': _nonConfidentialCtrl.text.trim(),
              'additional_provisions': _additionalProvisionsCtrl.text.trim(),
            },
          );

      if (mounted) context.go('/agreements/${agreement.id}/sign');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: Text(_stepTitle(_step)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / _totalSteps,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
        ),
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buyerInfoStep(),
            _firmRepresentationStep(),
            _coBuyerStep(),
            _termStep(),
            _compensationStep(),
            _excludedPropertiesStep(),
            _confidentialStep(),
            _additionalProvisionsStep(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_stepError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _stepError!,
                      style: TextStyle(color: cs.error, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                FilledButton(
                  onPressed: _saving ? null : _next,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child:
                      _saving
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(
                            _step < _totalSteps - 1
                                ? 'Next'
                                : 'Proceed to signatures',
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Steps ──────────────────────────────────────────────────────────────────

  Widget _buyerInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buyer information',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Used to fill the WB-36 Buyer Agency Agreement form.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _buyerNameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Buyer's full legal name *",
              hintText: 'As it appears on ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _buyerAddressCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Buyer address',
              hintText: '123 Main St, City, WI 53000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _buyerEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Buyer email *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Communication preference',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'How the buyer prefers to receive notices.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email'),
            value: _commEmail,
            onChanged: (v) => setState(() => _commEmail = v ?? true),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mail'),
            value: _commMail,
            onChanged: (v) => setState(() => _commMail = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _firmRepresentationStep() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Firm representation',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Select how the buyer\'s brokerage may represent other parties in the same transaction.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _radioOption(
            value: 'not_same_agent',
            title: 'Multiple representation — with designated agency',
            subtitle:
                'The brokerage may represent both buyer and seller, each with their own assigned agent.',
          ),
          const SizedBox(height: 12),
          _radioOption(
            value: 'neutral_firm',
            title: 'Multiple representation — without designated agency',
            subtitle:
                'The brokerage may represent both buyer and seller without assigning separate agents.',
          ),
          const SizedBox(height: 12),
          _radioOption(
            value: 'no_same_firm',
            title: 'I reject multiple representation',
            subtitle:
                'The brokerage may not represent both the buyer and the seller in the same transaction.',
          ),
        ],
      ),
    );
  }

  Widget _radioOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = _firmRepresentation == value;
    return GestureDetector(
      onTap: () => setState(() {
        _firmRepresentation = value;
        _stepError = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? cs.primaryContainer.withOpacity(0.3) : cs.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: value,
              groupValue: _firmRepresentation,
              onChanged: (v) => setState(() {
                _firmRepresentation = v;
                _stepError = null;
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coBuyerStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Co-buyer',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add a co-buyer'),
            value: _hasCoBuyer,
            onChanged: (v) => setState(() => _hasCoBuyer = v ?? false),
          ),
          if (_hasCoBuyer) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _buyer2NameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autofocus: true,
              onSubmitted: (_) => _next(),
              decoration: const InputDecoration(
                labelText: "Co-buyer's full legal name",
                hintText: 'As it appears on ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _termStep() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agreement term',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Text('Start date', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _dateTile(_dateFmt.format(_termStart), () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _termStart,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _termStart = d);
          }, cs),
          const SizedBox(height: 20),
          Text('End date', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _dateTile(_dateFmt.format(_termEnd), () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _termEnd,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (d != null) setState(() => _termEnd = d);
          }, cs),
        ],
      ),
    );
  }

  Widget _compensationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compensation',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Describe the commission and other compensation as they will appear on the form.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Text('Commission *', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _commissionCtrl,
            maxLines: 3,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. 2.5% of purchase price',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Other compensation',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otherCompCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Optional',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Purchase price range",
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _purchasePriceRangeCtrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'e.g. \$300,000 – \$400,000 (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _excludedPropertiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Excluded properties',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Properties that are excluded from this agreement.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'Excluded properties',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _excludedPropertiesCtrl,
            maxLines: 2,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Optional',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Previously-seen excluded properties',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _excludedPropertiesPriorCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Optional',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Exclusion period end date',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _exclusionDateCtrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'e.g. 12/31/2025 (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidentialStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confidential info',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Information that may or may not be kept confidential under this agreement.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'Confidential information',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confidentialCtrl,
            maxLines: 3,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Optional',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Non-confidential information',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nonConfidentialCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Optional',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _additionalProvisionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional provisions',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Optional. Any additional terms agreed upon by the parties.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _additionalProvisionsCtrl,
            maxLines: 6,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Leave blank if none.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _dateTile(String label, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: cs.primary),
            const SizedBox(width: 16),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _stepTitle(int step) => switch (step) {
    0 => 'Buyer info',
    1 => 'Firm representation',
    2 => 'Co-buyer',
    3 => 'Agreement term',
    4 => 'Compensation',
    5 => 'Excluded properties',
    6 => 'Confidential info',
    7 => 'Additional provisions',
    _ => 'New agreement',
  };
}
