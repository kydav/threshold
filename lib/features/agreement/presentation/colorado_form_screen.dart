import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:threshold/features/agreement/data/agreement_repository.dart';
import 'package:threshold/features/agreement/data/colorado_form_data.dart';
import 'package:threshold/features/auth/data/user_profile.dart';

class ColoradoFormScreen extends ConsumerStatefulWidget {
  const ColoradoFormScreen({super.key});

  @override
  ConsumerState<ColoradoFormScreen> createState() => _ColoradoFormScreenState();
}

class _ColoradoFormScreenState extends ConsumerState<ColoradoFormScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _saving = false;
  String? _stepError;

  static const int _totalSteps = 6;

  // Step 0 — Buyer name
  final _buyerNameCtrl = TextEditingController();
  bool _hasCoBuyer = false;
  final _buyer2NameCtrl = TextEditingController();

  // Step 1 — Buyer contact
  final _buyerEmailCtrl = TextEditingController();
  final _buyerPhoneCtrl = TextEditingController();
  bool _hasCoBuyerContact = false;
  final _buyer2EmailCtrl = TextEditingController();
  final _buyer2PhoneCtrl = TextEditingController();

  // Step 2 — Buyer address
  final _buyerAddressCtrl = TextEditingController();
  final _buyerCityStateZipCtrl = TextEditingController();
  bool _hasSeparateAddresses = false;
  final _buyer2AddressCtrl = TextEditingController();
  final _buyer2CityStateZipCtrl = TextEditingController();

  // Step 3 — Property
  final _propertyCtrl = TextEditingController();

  // Step 4 — Compensation
  String _compType = 'percentage'; // 'percentage' or 'dollar'
  final _compValueCtrl = TextEditingController();

  // Step 5 — Dates
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));
  final _holdoverCtrl = TextEditingController(text: '30');

  // Step 6 — Legal choices (isBuyerAgency comes from agent profile)
  bool _computationWillExtend = false;
  bool _isPartyToOther = false;
  bool _hasReceivedSubmittedList = false;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void dispose() {
    _pageController.dispose();
    _buyerNameCtrl.dispose();
    _buyer2NameCtrl.dispose();
    _buyerEmailCtrl.dispose();
    _buyerPhoneCtrl.dispose();
    _buyer2EmailCtrl.dispose();
    _buyer2PhoneCtrl.dispose();
    _buyerAddressCtrl.dispose();
    _buyerCityStateZipCtrl.dispose();
    _buyer2AddressCtrl.dispose();
    _buyer2CityStateZipCtrl.dispose();
    _propertyCtrl.dispose();
    _compValueCtrl.dispose();
    _holdoverCtrl.dispose();
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
        if (_buyerPhoneCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Phone number is required.');
          return false;
        }
        if (_hasCoBuyer && _hasCoBuyerContact) {
          final email2 = _buyer2EmailCtrl.text.trim();
          if (!email2.contains('@') || !email2.contains('.')) {
            setState(
              () => _stepError = "Enter a valid email for the co-buyer.",
            );
            return false;
          }
          if (_buyer2PhoneCtrl.text.trim().isEmpty) {
            setState(() => _stepError = "Co-buyer phone number is required.");
            return false;
          }
        }
      case 3:
        if (_propertyCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Property description is required.');
          return false;
        }
      case 4:
        if (_compValueCtrl.text.trim().isEmpty) {
          setState(() => _stepError = 'Compensation amount is required.');
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

      final buyer2Address =
          _hasCoBuyer && _hasSeparateAddresses
              ? _buyer2AddressCtrl.text.trim()
              : '';
      final buyer2CityStateZip =
          _hasCoBuyer && _hasSeparateAddresses
              ? _buyer2CityStateZipCtrl.text.trim()
              : '';

      final coData = ColoradoFormData(
        buyerPhone: _buyerPhoneCtrl.text.trim(),
        buyerStreetAddress: _buyerAddressCtrl.text.trim(),
        buyerCityStateZip: _buyerCityStateZipCtrl.text.trim(),
        isBuyerAgency: profile?.isBuyerAgency ?? true,
        compensationType: _compType,
        compensationValue: _compValueCtrl.text.trim(),
        holdoverDays:
            _holdoverCtrl.text.trim().isEmpty
                ? '30'
                : _holdoverCtrl.text.trim(),
        computationWillExtend: _computationWillExtend,
        buyerIsPartyToOtherAgreement: _isPartyToOther,
        buyerHasReceivedSubmittedList: _hasReceivedSubmittedList,
        buyer2Name: _hasCoBuyer ? _buyer2NameCtrl.text.trim() : '',
        buyer2Email:
            _hasCoBuyer && _hasCoBuyerContact
                ? _buyer2EmailCtrl.text.trim()
                : '',
        buyer2Phone:
            _hasCoBuyer && _hasCoBuyerContact
                ? _buyer2PhoneCtrl.text.trim()
                : '',
        buyer2StreetAddress: buyer2Address,
        buyer2CityStateZip: buyer2CityStateZip,
      );

      final compensation =
          _compType == 'percentage'
              ? '${_compValueCtrl.text.trim()}%'
              : '\$${_compValueCtrl.text.trim()}';

      final agreement = await ref
          .read(agreementRepositoryProvider)
          .create(
            agentId: user.uid,
            agentName:
                '${profile?.firstName ?? user.displayName ?? ''} ${profile?.lastName ?? ''}',
            agentEmail: profile?.email ?? user.email ?? '',
            brokerageName: profile?.brokerageName ?? '',
            buyerName: _buyerNameCtrl.text.trim(),
            buyerEmail: _buyerEmailCtrl.text.trim(),
            propertyScope: _propertyCtrl.text.trim(),
            compensation: compensation,
            startDate: _startDate,
            endDate: _endDate,
            formData: coData.toJson(),
          );

      if (mounted) context.go('/agreements/${agreement.id}/sign');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
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
          _addressStep(),
          _textStep(
            prompt: 'What property are you showing?',
            controller: _propertyCtrl,
            hint:
                'e.g. 123 Main St, Denver CO 80203\nor "Any residential property in Denver metro"',
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            capitalize: TextCapitalization.sentences,
          ),
          _compensationStep(),
          _datesStep(),
          _legalStep(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + keyboard),
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
    );
  }

  Widget _buyerNameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's the buyer's full legal name?",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 28),
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
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }

  Widget _textStep({
    required String prompt,
    required TextEditingController controller,
    required String hint,
    TextCapitalization capitalize = TextCapitalization.none,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            textCapitalization: capitalize,
            keyboardType: keyboardType,
            maxLines: maxLines,
            autofocus: true,
            textInputAction:
                maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
            onSubmitted: maxLines == 1 ? (_) => _next() : null,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _contactStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Buyer's contact info",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _buyerEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _buyerPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted:
                _hasCoBuyer && !_hasCoBuyerContact ? null : (_) => _next(),
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          if (_hasCoBuyer) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add co-buyer contact info'),
              subtitle: const Text(
                'Co-buyer will also receive the agreement by email',
              ),
              value: _hasCoBuyerContact,
              onChanged: (v) => setState(() => _hasCoBuyerContact = v ?? false),
            ),
            if (_hasCoBuyerContact) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _buyer2EmailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Co-buyer email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buyer2PhoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _next(),
                decoration: const InputDecoration(
                  labelText: 'Co-buyer phone',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _addressStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Buyer's address",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Required for the official form. Can be home address.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _buyerAddressCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Street address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _buyerCityStateZipCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted:
                _hasCoBuyer && !_hasSeparateAddresses ? null : (_) => _next(),
            decoration: const InputDecoration(
              labelText: 'City, State, Zip',
              border: OutlineInputBorder(),
            ),
          ),
          if (_hasCoBuyer) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use separate address for co-buyer'),
              value: _hasSeparateAddresses,
              onChanged:
                  (v) => setState(() => _hasSeparateAddresses = v ?? false),
            ),
            if (_hasSeparateAddresses) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _buyer2AddressCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: "Co-buyer street address",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buyer2CityStateZipCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _next(),
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

  Widget _compensationStep() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your compensation',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Success fee for this buyer agreement.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'percentage', label: Text('Percentage')),
              ButtonSegment(value: 'dollar', label: Text('Dollar amount')),
            ],
            selected: {_compType},
            onSelectionChanged: (v) => setState(() => _compType = v.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _compValueCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
            autofocus: true,
            decoration: InputDecoration(
              labelText: _compType == 'percentage' ? 'Percentage' : 'Amount',
              border: const OutlineInputBorder(),
              prefixText: _compType == 'dollar' ? '\$ ' : null,
              suffixText: _compType == 'percentage' ? '%' : null,
              hintText: _compType == 'percentage' ? '2.5' : '10000',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _datesStep() {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agreement period',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'NAR rules require a defined term.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _dateTile('Start date', _startDate, () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 730)),
            );
            if (d != null) setState(() => _startDate = d);
          }),
          const SizedBox(height: 12),
          _dateTile('End date', _endDate, () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _endDate,
              firstDate: _startDate.add(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 730)),
            );
            if (d != null) setState(() => _endDate = d);
          }),
          const SizedBox(height: 20),
          TextField(
            controller: _holdoverCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Holdover period (days)',
              border: OutlineInputBorder(),
              helperText: 'Section 3.5 — typically 30 days',
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A few quick questions',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Deadline computation (Section 3)'),
          const SizedBox(height: 8),
          _choiceCard(
            label: 'Will NOT extend for holidays',
            subtitle:
                'Most common — deadlines do not shift on weekends/holidays',
            selected: !_computationWillExtend,
            onTap: () => setState(() => _computationWillExtend = false),
          ),
          const SizedBox(height: 8),
          _choiceCard(
            label: 'WILL extend for holidays',
            subtitle: 'Deadlines shift to next business day',
            selected: _computationWillExtend,
            onTap: () => setState(() => _computationWillExtend = true),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Buyer obligations (Section 9)'),
          const SizedBox(height: 8),
          _yesNoRow(
            label: 'Is buyer currently a party to another buyer agreement?',
            value: _isPartyToOther,
            onChanged: (v) => setState(() => _isPartyToOther = v),
          ),
          const SizedBox(height: 12),
          _yesNoRow(
            label:
                'Has buyer received a "Submitted Property" list from another broker?',
            value: _hasReceivedSubmittedList,
            onChanged: (v) => setState(() => _hasReceivedSubmittedList = v),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                Text(
                  _dateFmt.format(date),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    ),
  );

  Widget _choiceCard({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? cs.primaryContainer.withValues(alpha: 0.25) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? cs.primary : cs.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yesNoRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        const SizedBox(width: 12),
        ToggleButtons(
          isSelected: [!value, value],
          onPressed: (i) => onChanged(i == 1),
          borderRadius: BorderRadius.circular(8),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
          children: const [Text('No'), Text('Yes')],
        ),
      ],
    );
  }

  String _stepTitle(int step) => switch (step) {
    0 => 'Buyer name',
    1 => 'Contact info',
    2 => 'Buyer address',
    3 => 'Property',
    4 => 'Compensation',
    5 => 'Dates',
    _ => 'Legal details',
  };
}
