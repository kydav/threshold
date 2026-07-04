import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/core/services/analytics_service.dart';
import 'package:threshold/core/services/data_service.dart';
import 'package:threshold/features/auth/data/auth_service.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/auth/presentation/brokerage_step.dart';

/// Brokerage setup screen shown after a first-time social sign-in.
/// The Firebase Auth user already exists; this collects the profile info
/// that the email/password signup flow gathers in its second step.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({
    required this.displayName,
    required this.email,
    super.key,
  });

  final String displayName;
  final String email;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _brokerageNameCtrl = TextEditingController();
  final _brokerageAddressCtrl = TextEditingController();
  final _brokerageCityStateZipCtrl = TextEditingController();
  final _agentPhoneCtrl = TextEditingController();
  final _agentLicenseCtrl = TextEditingController();
  final _brokerageLicenseCtrl = TextEditingController();
  final _managingBrokerNameCtrl = TextEditingController();
  final _managingBrokerPhoneCtrl = TextEditingController();
  final _managingBrokerEmailCtrl = TextEditingController();

  String? _state;
  bool _isMultiPersonFirm = true;
  bool _isBuyerAgency = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _brokerageNameCtrl.dispose();
    _brokerageAddressCtrl.dispose();
    _brokerageCityStateZipCtrl.dispose();
    _agentPhoneCtrl.dispose();
    _agentLicenseCtrl.dispose();
    _brokerageLicenseCtrl.dispose();
    _managingBrokerNameCtrl.dispose();
    _managingBrokerPhoneCtrl.dispose();
    _managingBrokerEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_brokerageNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Brokerage name is required.');
      return;
    }
    if (_agentPhoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Phone is required.');
      return;
    }
    if (_state == null) {
      setState(() => _error = 'Please select your state.');
      return;
    }

    final authService = ref.read(authServiceProvider);
    final dataService = ref.read(dataServiceProvider);
    final profileNotifier = ref.read(userProfileProvider.notifier);

    final uid = authService.currentUser!.uid;
    final displayName = widget.displayName;
    final parts = displayName.split(' ');

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = UserProfile(
        uid: uid,
        email: widget.email,
        firstName: parts.first,
        lastName: parts.skip(1).join(' '),
        brokerageName: _brokerageNameCtrl.text.trim(),
        brokerageAddress: _brokerageAddressCtrl.text.trim(),
        brokerageCityStateZip: _brokerageCityStateZipCtrl.text.trim(),
        phone: _agentPhoneCtrl.text.trim(),
        state: _state!,
        isMultiPersonFirm: _isMultiPersonFirm,
        isBuyerAgency: _isBuyerAgency,
        agentLicenseNumber: _agentLicenseCtrl.text.trim(),
        brokerageLicenseNumber: _brokerageLicenseCtrl.text.trim(),
        managingBrokerName: _managingBrokerNameCtrl.text.trim(),
        managingBrokerPhone: _managingBrokerPhoneCtrl.text.trim(),
        managingBrokerEmail: _managingBrokerEmailCtrl.text.trim(),
      );
      await dataService.saveUserProfile(profile);
      profileNotifier.state = profile;
      AnalyticsService.signUp(state: _state!);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = 'Setup failed. Please try again. ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // Navigate once profile is saved
    ref.listen(userProfileProvider, (_, profile) {
      if (profile != null && mounted) context.go('/home');
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your brokerage'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: BrokerageStep(
          brokerageNameCtrl: _brokerageNameCtrl,
          brokerageAddressCtrl: _brokerageAddressCtrl,
          brokerageCityStateZipCtrl: _brokerageCityStateZipCtrl,
          agentPhoneCtrl: _agentPhoneCtrl,
          state: _state,
          isMultiPersonFirm: _isMultiPersonFirm,
          isBuyerAgency: _isBuyerAgency,
          stateCallback: (val) => setState(() => _state = val),
          multiPersonFirmCallback: (val) => setState(() => _isMultiPersonFirm = val),
          buyerAgencyCallback: (val) => setState(() => _isBuyerAgency = val),
          agentLicenseCtrl: _agentLicenseCtrl,
          brokerageLicenseCtrl: _brokerageLicenseCtrl,
          managingBrokerNameCtrl: _managingBrokerNameCtrl,
          managingBrokerPhoneCtrl: _managingBrokerPhoneCtrl,
          managingBrokerEmailCtrl: _managingBrokerEmailCtrl,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: cs.error),
                  textAlign: TextAlign.center,
                ),
              ),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Finish setup'),
            ),
          ],
        ),
      ),
    );
  }
}
