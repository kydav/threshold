import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:threshold/core/services/analytics_service.dart';
import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/auth/data/user_profile.dart';

class UtahFormScreen extends ConsumerStatefulWidget {
  const UtahFormScreen({super.key});

  @override
  ConsumerState<UtahFormScreen> createState() => _UtahFormScreenState();
}

class _UtahFormScreenState extends ConsumerState<UtahFormScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _saving = false;
  String? _stepError;

  static const int _totalSteps = 6;

  // Step 0 — Buyer name(s)
  final _buyerNameCtrl = TextEditingController();
  bool _hasCoBuyer = false;
  final _buyer2NameCtrl = TextEditingController();

  // Step 1 — Contact & address (needed for signature block)
  final _buyerEmailCtrl = TextEditingController();
  final _buyerPhoneCtrl = TextEditingController();
  final _buyerAddressCtrl = TextEditingController();
  final _buyerCityStateZipCtrl = TextEditingController();
  bool _hasCoBuyerContact = false;
  final _buyer2EmailCtrl = TextEditingController();
  final _buyer2PhoneCtrl = TextEditingController();
  bool _hasSeparateAddresses = false;
  final _buyer2AddressCtrl = TextEditingController();
  final _buyer2CityStateZipCtrl = TextEditingController();

  // Step 2 — Properties location
  String _locationType = 'county'; // 'county' or 'address'
  final _locationValueCtrl = TextEditingController();

  // Step 3 — Brokerage fee
  String _feeType = 'percentage'; // 'percentage' or 'dollar'
  final _feeValueCtrl = TextEditingController();

  // Step 4 — Term & protection period
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));
  final _protectionMonthsCtrl = TextEditingController(text: '3');

  // Step 5 — Dispute resolution
  String _disputeResolution = 'shall'; // 'shall' or 'may'

  static final _dateFmt = DateFormat('MMMM d, yyyy');

  @override
  void dispose() {
    _pageController.dispose();
    _buyerNameCtrl.dispose();
    _buyer2NameCtrl.dispose();
    _buyerEmailCtrl.dispose();
    _buyerPhoneCtrl.dispose();
    _buyerAddressCtrl.dispose();
    _buyerCityStateZipCtrl.dispose();
    _buyer2EmailCtrl.dispose();
    _buyer2PhoneCtrl.dispose();
    _buyer2AddressCtrl.dispose();
    _buyer2CityStateZipCtrl.dispose();
    _locationValueCtrl.dispose();
    _feeValueCtrl.dispose();
    _protectionMonthsCtrl.dispose();
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
        if (_buyerPhoneCtrl.text.trim().isEmpty &&
            _buyerAddressCtrl.text.trim().isEmpty) {
          setState(
            () => _stepError = 'Phone number or street address is required.',
          );
          return false;
        }
      case 2:
        if (_locationValueCtrl.text.trim().isEmpty) {
          setState(
            () =>
                _stepError =
                    _locationType == 'county'
                        ? 'Enter the county name.'
                        : 'Enter the property address(es).',
          );
          return false;
        }
      case 3:
        if (_feeValueCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Brokerage fee is required.');
          return false;
        }
      case 4:
        final months = int.tryParse(_protectionMonthsCtrl.text.trim());
        if (months == null || months < 1) {
          setState(() => _stepError = 'Enter a valid number of months.');
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
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final profile = ref.read(userProfileProvider);

      final locationLabel =
          _locationType == 'county'
              ? 'County: ${_locationValueCtrl.text.trim()}'
              : _locationValueCtrl.text.trim();

      final compensation =
          _feeType == 'percentage'
              ? '${_feeValueCtrl.text.trim()}%'
              : '\$${_feeValueCtrl.text.trim()}';

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
            propertyScope: locationLabel,
            compensation: compensation,
            startDate: DateTime.now(),
            endDate: _endDate,
            formState: 'Utah',
            formData: {
              'buyer1Name': _buyerNameCtrl.text.trim(),
              'buyerPhone': _buyerPhoneCtrl.text.trim(),
              'buyerStreetAddress': _buyerAddressCtrl.text.trim(),
              'buyerCityStateZip': _buyerCityStateZipCtrl.text.trim(),
              'buyer2Name': _hasCoBuyer ? _buyer2NameCtrl.text.trim() : '',
              'buyer2Email':
                  _hasCoBuyer && _hasCoBuyerContact
                      ? _buyer2EmailCtrl.text.trim()
                      : '',
              'buyer2Phone':
                  _hasCoBuyer && _hasCoBuyerContact
                      ? _buyer2PhoneCtrl.text.trim()
                      : '',
              'buyer2StreetAddress':
                  _hasCoBuyer && _hasSeparateAddresses
                      ? _buyer2AddressCtrl.text.trim()
                      : '',
              'buyer2CityStateZip':
                  _hasCoBuyer && _hasSeparateAddresses
                      ? _buyer2CityStateZipCtrl.text.trim()
                      : '',
              'locationType': _locationType,
              'locationValue': _locationValueCtrl.text.trim(),
              'feeType': _feeType,
              'feeValue': _feeValueCtrl.text.trim(),
              'protectionPeriodMonths': _protectionMonthsCtrl.text.trim(),
              'disputeResolution': _disputeResolution,
            },
          );

      AnalyticsService.formSubmitted(formState: 'Utah');
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
            icon: const Icon(Icons.chevron_left),
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
        body: Column(
          children: [
            _DisclaimerBanner(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buyerNameStep(),
                  _contactStep(),
                  _locationStep(),
                  _feeStep(),
                  _termStep(),
                  _disputeStep(),
                ],
              ),
            ),
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
            "Buyer's contact & address",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Used on the signature block.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
            controller: _buyerPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buyerAddressCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Street address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buyerCityStateZipCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'City, State, Zip',
              border: OutlineInputBorder(),
            ),
          ),
          if (_hasCoBuyer) ...[
            const SizedBox(height: 20),
            const Divider(),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Separate contact info for co-buyer'),
              value: _hasCoBuyerContact,
              onChanged: (v) => setState(() => _hasCoBuyerContact = v ?? false),
            ),
            if (_hasCoBuyerContact) ...[
              TextField(
                controller: _buyer2EmailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Co-buyer email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyer2PhoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Co-buyer phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Separate address for co-buyer'),
              value: _hasSeparateAddresses,
              onChanged:
                  (v) => setState(() => _hasSeparateAddresses = v ?? false),
            ),
            if (_hasSeparateAddresses) ...[
              TextField(
                controller: _buyer2AddressCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Co-buyer street address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyer2CityStateZipCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Co-buyer city, State, Zip',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _locationStep() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Properties location',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _radioTile(
            label: 'County',
            subtitle: 'All properties in a county',
            value: 'county',
            groupValue: _locationType,
            onChanged: (v) => setState(() => _locationType = v ?? 'county'),
            cs: cs,
          ),
          const SizedBox(height: 8),
          _radioTile(
            label: 'Address(es)',
            subtitle: 'One or more specific properties',
            value: 'address',
            groupValue: _locationType,
            onChanged: (v) => setState(() => _locationType = v ?? 'address'),
            cs: cs,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _locationValueCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            maxLines: _locationType == 'address' ? 3 : 1,
            keyboardType:
                _locationType == 'address'
                    ? TextInputType.multiline
                    : TextInputType.text,
            textInputAction:
                _locationType == 'address'
                    ? TextInputAction.newline
                    : TextInputAction.done,
            onSubmitted: _locationType == 'address' ? null : (_) => _next(),
            decoration: InputDecoration(
              labelText:
                  _locationType == 'county'
                      ? 'County name'
                      : 'Property address(es)',
              hintText:
                  _locationType == 'county'
                      ? 'e.g. Salt Lake County'
                      : 'e.g. 123 Main St, SLC UT 84101',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeStep() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Brokerage fee',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _radioTile(
            label: 'Percentage',
            subtitle: 'e.g. 3% of purchase price',
            value: 'percentage',
            groupValue: _feeType,
            onChanged: (v) => setState(() => _feeType = v ?? 'percentage'),
            cs: cs,
          ),
          const SizedBox(height: 8),
          _radioTile(
            label: 'Dollar amount',
            subtitle: 'Fixed flat fee',
            value: 'dollar',
            groupValue: _feeType,
            onChanged: (v) => setState(() => _feeType = v ?? 'dollar'),
            cs: cs,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _feeValueCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
            decoration: InputDecoration(
              labelText:
                  _feeType == 'percentage' ? 'Percentage' : 'Dollar amount',
              prefixText: _feeType == 'dollar' ? '\$ ' : null,
              suffixText: _feeType == 'percentage' ? '%' : null,
              hintText: _feeType == 'percentage' ? '3' : '10000',
              border: const OutlineInputBorder(),
            ),
          ),
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
            'Term & protection period',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Text(
            'Effective end date',
            style: Theme.of(context).textTheme.labelLarge,
          ),
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
          const SizedBox(height: 24),
          Text(
            'Protection period',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Months after expiration during which the fee still applies '
            'if the buyer purchases a property shown during the term.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _protectionMonthsCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
            decoration: const InputDecoration(
              labelText: 'Number of months',
              suffixText: 'months',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _disputeStep() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dispute resolution',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'The parties _______ seek mediation before pursuing other remedies.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _radioTile(
            label: 'Shall',
            subtitle: 'Mediation is required before other remedies',
            value: 'shall',
            groupValue: _disputeResolution,
            onChanged: (v) => setState(() => _disputeResolution = v ?? 'shall'),
            cs: cs,
          ),
          const SizedBox(height: 8),
          _radioTile(
            label: 'May at the option of the parties',
            subtitle: 'Mediation is optional',
            value: 'may',
            groupValue: _disputeResolution,
            onChanged: (v) => setState(() => _disputeResolution = v ?? 'may'),
            cs: cs,
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
              selected
                  ? cs.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
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
              child:
                  selected
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
    1 => 'Contact & address',
    2 => 'Properties location',
    3 => 'Brokerage fee',
    4 => 'Term & protection',
    5 => 'Dispute resolution',
    _ => 'New agreement',
  };
}

class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'BETA — This form is for testing purposes only. '
              'It is not legally binding or valid.',
              style: TextStyle(
                fontSize: 12,
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
