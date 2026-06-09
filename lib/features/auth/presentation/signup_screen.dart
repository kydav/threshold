import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:threshold/features/auth/data/agent_profile_store.dart';
import 'package:threshold/features/auth/data/auth_service.dart';

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
          .read(agentProfileStoreProvider)
          .save(
            AgentProfile(
              agentName: _nameCtrl.text.trim(),
              agentEmail: _emailCtrl.text.trim(),
              brokerageName: _brokerageNameCtrl.text.trim(),
              brokerageAddress: _brokerageAddressCtrl.text.trim(),
              brokerageCityStateZip: _brokerageCityStateZipCtrl.text.trim(),
              agentPhone: _agentPhoneCtrl.text.trim(),
              state: _state,
              isMultiPersonFirm: _isMultiPersonFirm,
            ),
          );
    } on Exception catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
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
        children: [_buildAccountStep(cs), _buildBrokerageStep(cs)],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
      ),
    );
  }

  Widget _buildAccountStep(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your info',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onEditingComplete: () => _next(),
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              helperText: 'Min 6 characters',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokerageStep(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Brokerage details',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Used to pre-fill forms at every showing.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _brokerageNameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Brokerage name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _brokerageAddressCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Brokerage street address (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _brokerageCityStateZipCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'City, State, Zip (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _agentPhoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Your phone number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _state,
            decoration: const InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
            ),
            items:
                kSupportedStates
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
            onChanged: (v) => setState(() => _state = v!),
          ),
          const SizedBox(height: 20),
          Text('Firm type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _ChoiceCard(
            label: 'Multiple-person firm',
            subtitle:
                'Section 2.1 — you are a designated broker within the firm',
            selected: _isMultiPersonFirm,
            onTap: () => setState(() => _isMultiPersonFirm = true),
          ),
          const SizedBox(height: 8),
          _ChoiceCard(
            label: 'One-person firm',
            subtitle: 'Section 2.2 — you are the sole licensed person',
            selected: !_isMultiPersonFirm,
            onTap: () => setState(() => _isMultiPersonFirm = false),
          ),
        ],
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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
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
}
