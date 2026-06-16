import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/core/services/data_service.dart';
import 'package:threshold/features/auth/data/auth_service.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/auth/presentation/brokerage_step.dart';
import 'package:threshold/features/auth/presentation/info_step.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _loading = false;
  String? _error;

  // Step 1 — account
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // Step 2 — brokerage
  final _brokerageNameCtrl = TextEditingController();
  final _brokerageAddressCtrl = TextEditingController();
  final _brokerageCityStateZipCtrl = TextEditingController();
  final _agentPhoneCtrl = TextEditingController();
  String _state = kSupportedStates.first;
  bool _isMultiPersonFirm = true;
  bool _isBuyerAgency = true;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _brokerageNameCtrl.dispose();
    _brokerageAddressCtrl.dispose();
    _brokerageCityStateZipCtrl.dispose();
    _agentPhoneCtrl.dispose();
    super.dispose();
  }

  String? _validateStep() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) return 'Full name is required.';
      if (!_emailCtrl.text.contains('@')) return 'Enter a valid email.';
      if (_passwordCtrl.text.length < 6) return 'Password must be 6+ chars.';
    } else {
      if (_brokerageNameCtrl.text.trim().isEmpty) {
        return 'Brokerage name is required.';
      }
      if (_agentPhoneCtrl.text.trim().isEmpty) return 'Phone is required.';
    }
    return null;
  }

  void _next() {
    final err = _validateStep();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _error = null);
    if (_step == 0) {
      setState(() => _step = 1);
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signUp(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text.trim(),
          );
      await ref
          .read(dataServiceProvider)
          .saveUserProfile(
            UserProfile(
              uid: ref.read(authServiceProvider).currentUser!.uid,
              email: _emailCtrl.text.trim(),
              firstName: _nameCtrl.text.trim().split(' ').first,
              lastName: _nameCtrl.text.trim().split(' ').skip(1).join(' '),
              brokerageName: _brokerageNameCtrl.text.trim(),
              brokerageAddress: _brokerageAddressCtrl.text.trim(),
              brokerageCityStateZip: _brokerageCityStateZipCtrl.text.trim(),
              phone: _agentPhoneCtrl.text.trim(),
              state: _state,
              isMultiPersonFirm: _isMultiPersonFirm,
              isBuyerAgency: _isBuyerAgency,
            ),
          );
      final profile = await ref
          .read(dataServiceProvider)
          .getUserProfile(ref.read(authServiceProvider).currentUser!.uid);
      ref.read(userProfileProvider.notifier).state = profile;
    } on Exception catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading:
            _step == 1
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _step = 0;
                      _error = null;
                    });
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                )
                : null,
        title: Text(_step == 0 ? 'Create account' : 'Your brokerage'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 2,
            backgroundColor: cs.surfaceContainerHighest,
            color: cs.primary,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          InfoStep(
            nameCtrl: _nameCtrl,
            emailCtrl: _emailCtrl,
            passwordCtrl: _passwordCtrl,
            obscure: _obscure,
            next: _next,
            obscureCallback: () => setState(() => _obscure = !_obscure),
          ),
          BrokerageStep(
            brokerageNameCtrl: _brokerageNameCtrl,
            brokerageAddressCtrl: _brokerageAddressCtrl,
            brokerageCityStateZipCtrl: _brokerageCityStateZipCtrl,
            agentPhoneCtrl: _agentPhoneCtrl,
            state: _state,
            isMultiPersonFirm: _isMultiPersonFirm,
            isBuyerAgency: _isBuyerAgency,
            stateCallback: (val) => setState(() => _state = val),
            multiPersonFirmCallback:
                (val) => setState(() => _isMultiPersonFirm = val),
            buyerAgencyCallback: (val) => setState(() => _isBuyerAgency = val),
          ),
        ],
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
              onPressed: _loading ? null : _next,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child:
                  _loading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(_step == 0 ? 'Next' : 'Create account'),
            ),
            if (_step == 0) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'An account with that email already exists.';
    }
    if (raw.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    return 'Sign-up failed. Please try again.';
  }
}
