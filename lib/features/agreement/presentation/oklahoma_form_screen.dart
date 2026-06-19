import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/auth/data/user_profile.dart';

class OklahomaFormScreen extends ConsumerStatefulWidget {
  const OklahomaFormScreen({super.key});

  @override
  ConsumerState<OklahomaFormScreen> createState() => _OklahomaFormScreenState();
}

class _OklahomaFormScreenState extends ConsumerState<OklahomaFormScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _saving = false;
  String? _stepError;

  static const int _totalSteps = 6;

  // Step 0 — Buyer name(s)
  final _buyerNameCtrl = TextEditingController();
  bool _hasCoBuyer = false;
  final _buyer2NameCtrl = TextEditingController();

  // Step 1 — Buyer contact
  final _buyerEmailCtrl = TextEditingController();
  final _buyerCellCtrl = TextEditingController();
  final _buyerWorkCtrl = TextEditingController();
  final _buyer2EmailCtrl = TextEditingController();
  final _buyer2CellCtrl = TextEditingController();
  final _buyer2WorkCtrl = TextEditingController();

  // Step 2 — Agreement term
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 60));
  final _postTermDaysCtrl = TextEditingController(text: '60');

  // Step 3 — Compensation
  String _compType = 'percentage'; // 'percentage', 'dollar', 'other'
  final _compValueCtrl = TextEditingController();
  final _retainerCtrl = TextEditingController();
  final _otherCompCtrl = TextEditingController();
  final _postExpDaysCtrl = TextEditingController(text: '60');

  // Step 4 — Broker/license details (OK-specific, optional)
  final _agentLicenseCtrl = TextEditingController();
  final _brokerageLicenseCtrl = TextEditingController();
  final _managingBrokerNameCtrl = TextEditingController();
  final _managingBrokerPhoneCtrl = TextEditingController();
  final _managingBrokerEmailCtrl = TextEditingController();

  // Step 5 — Additional provisions
  final _additionalProvisionsCtrl = TextEditingController();

  static final _dateFmt = DateFormat('MMMM d, yyyy');

  @override
  void dispose() {
    _pageController.dispose();
    _buyerNameCtrl.dispose();
    _buyer2NameCtrl.dispose();
    _buyerEmailCtrl.dispose();
    _buyerCellCtrl.dispose();
    _buyerWorkCtrl.dispose();
    _buyer2EmailCtrl.dispose();
    _buyer2CellCtrl.dispose();
    _buyer2WorkCtrl.dispose();
    _postTermDaysCtrl.dispose();
    _compValueCtrl.dispose();
    _retainerCtrl.dispose();
    _otherCompCtrl.dispose();
    _postExpDaysCtrl.dispose();
    _agentLicenseCtrl.dispose();
    _brokerageLicenseCtrl.dispose();
    _managingBrokerNameCtrl.dispose();
    _managingBrokerPhoneCtrl.dispose();
    _managingBrokerEmailCtrl.dispose();
    _additionalProvisionsCtrl.dispose();
    super.dispose();
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_buyerNameCtrl.text.trim().isEmpty) {
          setState(() => _stepError = "Buyer's name is required.");
          return false;
        }
        if (_hasCoBuyer && _buyer2NameCtrl.text.trim().isEmpty) {
          setState(() => _stepError = "Co-buyer's name is required.");
          return false;
        }
      case 1:
        final email = _buyerEmailCtrl.text.trim();
        if (!email.contains('@') || !email.contains('.')) {
          setState(() => _stepError = 'Enter a valid email address.');
          return false;
        }
        if (_buyerCellCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Cell phone is required.');
          return false;
        }
      case 3:
        if (_compType != 'other' && _compValueCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Compensation amount is required.');
          return false;
        }
        if (_compType == 'other' && _otherCompCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Please describe the compensation arrangement.');
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

      final compensation = switch (_compType) {
        'percentage' => '${_compValueCtrl.text.trim()}% of gross selling price',
        'dollar' => '\$${_compValueCtrl.text.trim()}',
        _ => _otherCompCtrl.text.trim(),
      };

      final agentName =
          '${profile?.firstName ?? ''} ${profile?.lastName ?? ''}'.trim();

      final agreement = await ref
          .read(agreementRepositoryProvider)
          .create(
            agentId: user.uid,
            agentName:
                agentName.isNotEmpty ? agentName : user.displayName ?? '',
            agentEmail: profile?.email ?? user.email ?? '',
            brokerageName: profile?.brokerageName ?? '',
            buyerName:
                _hasCoBuyer
                    ? '${_buyerNameCtrl.text.trim()} and ${_buyer2NameCtrl.text.trim()}'
                    : _buyerNameCtrl.text.trim(),
            buyerEmail: _buyerEmailCtrl.text.trim(),
            propertyScope: 'Oklahoma',
            compensation: compensation,
            startDate: _startDate,
            endDate: _endDate,
            formState: 'Oklahoma',
            formData: {
              'buyer1Name': _buyerNameCtrl.text.trim(),
              'buyerEmail': _buyerEmailCtrl.text.trim(),
              'buyerCellPhone': _buyerCellCtrl.text.trim(),
              'buyerWorkPhone': _buyerWorkCtrl.text.trim(),
              'buyer2Name': _hasCoBuyer ? _buyer2NameCtrl.text.trim() : '',
              'buyer2Email': _hasCoBuyer ? _buyer2EmailCtrl.text.trim() : '',
              'buyer2CellPhone': _hasCoBuyer ? _buyer2CellCtrl.text.trim() : '',
              'buyer2WorkPhone': _hasCoBuyer ? _buyer2WorkCtrl.text.trim() : '',
              'postTerminationDays': _postTermDaysCtrl.text.trim(),
              'compensationType': _compType,
              'compensationValue': _compValueCtrl.text.trim(),
              'retainerFee': _retainerCtrl.text.trim(),
              'otherCompensation': _otherCompCtrl.text.trim(),
              'postExpirationDays': _postExpDaysCtrl.text.trim(),
              'agentLicenseNumber': _agentLicenseCtrl.text.trim(),
              'brokerageLicenseNumber': _brokerageLicenseCtrl.text.trim(),
              'managingBrokerName': _managingBrokerNameCtrl.text.trim(),
              'managingBrokerPhone': _managingBrokerPhoneCtrl.text.trim(),
              'managingBrokerEmail': _managingBrokerEmailCtrl.text.trim(),
              'additionalProvisions': _additionalProvisionsCtrl.text.trim(),
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
            _buyerNameStep(),
            _contactStep(),
            _termStep(),
            _compensationStep(),
            _brokerDetailsStep(),
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

  Widget _buyerNameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Buyer's full legal name",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _buyerNameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction:
                _hasCoBuyer ? TextInputAction.next : TextInputAction.done,
            onSubmitted: _hasCoBuyer ? null : (_) => _next(),
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'As it appears on ID',
              border: OutlineInputBorder(),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add a co-buyer'),
            value: _hasCoBuyer,
            onChanged: (v) => setState(() => _hasCoBuyer = v ?? false),
          ),
          if (_hasCoBuyer) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _buyer2NameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
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

  Widget _contactStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Buyer's contact",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _buyerEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buyerCellCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Cell phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buyerWorkCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Work phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_hasCoBuyer) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              "Co-buyer's contact",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _buyer2EmailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Co-buyer email (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _buyer2CellCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Co-buyer cell phone (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _buyer2WorkCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Co-buyer work phone (optional)',
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
          _dateTile(_dateFmt.format(_startDate), () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _startDate = d);
          }, cs),
          const SizedBox(height: 20),
          Text('Expiration date', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _dateTile(_dateFmt.format(_endDate), () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _endDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (d != null) setState(() => _endDate = d);
          }, cs),
          const SizedBox(height: 20),
          Text(
            'Post-termination protection period',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Days after expiration during which the fee still applies '
            '(default 60 if left blank).',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _postTermDaysCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Days',
              suffixText: 'days',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compensationStep() {
    final cs = Theme.of(context).colorScheme;
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
          const SizedBox(height: 24),
          _radioTile(
            label: 'Percentage of gross selling price',
            subtitle: 'e.g. 3% of purchase price',
            value: 'percentage',
            groupValue: _compType,
            onChanged: (v) => setState(() => _compType = v ?? 'percentage'),
            cs: cs,
          ),
          const SizedBox(height: 8),
          _radioTile(
            label: 'Dollar amount',
            subtitle: 'Fixed flat fee',
            value: 'dollar',
            groupValue: _compType,
            onChanged: (v) => setState(() => _compType = v ?? 'dollar'),
            cs: cs,
          ),
          const SizedBox(height: 8),
          _radioTile(
            label: 'Other arrangement',
            subtitle: 'Describe a custom compensation',
            value: 'other',
            groupValue: _compType,
            onChanged: (v) => setState(() => _compType = v ?? 'other'),
            cs: cs,
          ),
          const SizedBox(height: 20),
          if (_compType != 'other')
            TextField(
              controller: _compValueCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _compType == 'percentage' ? 'Percentage' : 'Dollar amount',
                prefixText: _compType == 'dollar' ? '\$ ' : null,
                suffixText: _compType == 'percentage' ? '%' : null,
                hintText: _compType == 'percentage' ? '3' : '10000',
                border: const OutlineInputBorder(),
              ),
            )
          else
            TextField(
              controller: _otherCompCtrl,
              autofocus: true,
              maxLines: 3,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Describe compensation arrangement',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Retainer fee (optional)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Non-refundable retainer credited toward the compensation.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _retainerCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              prefixText: '\$ ',
              hintText: '0',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Post-expiration protection days',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Days after agreement expires during which commission applies (default 60).',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _postExpDaysCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              suffixText: 'days',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brokerDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Broker & license details',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Required on the Oklahoma form signature block. All fields optional.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _agentLicenseCtrl,
            textInputAction: TextInputAction.next,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Associate broker license number",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brokerageLicenseCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Brokerage license number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Managing broker',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _managingBrokerNameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Managing broker name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _managingBrokerPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Managing broker office telephone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _managingBrokerEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Managing broker email',
              border: OutlineInputBorder(),
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
            'Optional. Any additional terms agreed upon by the parties (§15).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _additionalProvisionsCtrl,
            maxLines: 8,
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

  Widget _radioTile({
    required String label,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
    required ColorScheme cs,
  }) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              selected ? cs.primary.withValues(alpha: 0.06) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.primary : cs.outline,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.primary : null,
                    ),
                  ),
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
        0 => 'Buyer name',
        1 => 'Contact info',
        2 => 'Agreement term',
        3 => 'Compensation',
        4 => 'Broker details',
        5 => 'Additional provisions',
        _ => 'New agreement',
      };
}
