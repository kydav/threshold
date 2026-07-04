import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:threshold/core/config/revenue_cat_config.dart';
import 'package:threshold/core/services/data_service.dart';
import 'package:threshold/core/services/subscription_service.dart';
import 'package:threshold/features/auth/data/auth_service.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/auth/presentation/brokerage_step.dart';
import 'package:threshold/features/paywall/presentation/paywall_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _brokerageNameCtrl;
  late final TextEditingController _brokerageAddressCtrl;
  late final TextEditingController _brokerageCityStateZipCtrl;
  late final TextEditingController _agentLicenseCtrl;
  late final TextEditingController _brokerageLicenseCtrl;
  late final TextEditingController _managingBrokerNameCtrl;
  late final TextEditingController _managingBrokerPhoneCtrl;
  late final TextEditingController _managingBrokerEmailCtrl;
  String? _state;
  bool _isMultiPersonFirm = true;
  bool _isBuyerAgency = true;

  bool _saving = false;
  bool _deleting = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(userProfileProvider);
    _firstNameCtrl = TextEditingController(text: p?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: p?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _brokerageNameCtrl = TextEditingController(text: p?.brokerageName ?? '');
    _brokerageAddressCtrl = TextEditingController(
      text: p?.brokerageAddress ?? '',
    );
    _brokerageCityStateZipCtrl = TextEditingController(
      text: p?.brokerageCityStateZip ?? '',
    );
    _agentLicenseCtrl = TextEditingController(
      text: p?.agentLicenseNumber ?? '',
    );
    _brokerageLicenseCtrl = TextEditingController(
      text: p?.brokerageLicenseNumber ?? '',
    );
    _managingBrokerNameCtrl = TextEditingController(
      text: p?.managingBrokerName ?? '',
    );
    _managingBrokerPhoneCtrl = TextEditingController(
      text: p?.managingBrokerPhone ?? '',
    );
    _managingBrokerEmailCtrl = TextEditingController(
      text: p?.managingBrokerEmail ?? '',
    );
    final s = p?.state ?? '';
    _state = s.isEmpty ? null : s;
    _isMultiPersonFirm = p?.isMultiPersonFirm ?? true;
    _isBuyerAgency = p?.isBuyerAgency ?? true;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _brokerageNameCtrl.dispose();
    _brokerageAddressCtrl.dispose();
    _brokerageCityStateZipCtrl.dispose();
    _agentLicenseCtrl.dispose();
    _brokerageLicenseCtrl.dispose();
    _managingBrokerNameCtrl.dispose();
    _managingBrokerPhoneCtrl.dispose();
    _managingBrokerEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;
    if (_brokerageNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Brokerage name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      final updated = UserProfile(
        uid: profile.uid,
        email: profile.email,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        brokerageName: _brokerageNameCtrl.text.trim(),
        brokerageAddress: _brokerageAddressCtrl.text.trim(),
        brokerageCityStateZip: _brokerageCityStateZipCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        state: _state ?? '',
        isMultiPersonFirm: _isMultiPersonFirm,
        isBuyerAgency: _isBuyerAgency,
        agentLicenseNumber: _agentLicenseCtrl.text.trim(),
        brokerageLicenseNumber: _brokerageLicenseCtrl.text.trim(),
        managingBrokerName: _managingBrokerNameCtrl.text.trim(),
        managingBrokerPhone: _managingBrokerPhoneCtrl.text.trim(),
        managingBrokerEmail: _managingBrokerEmailCtrl.text.trim(),
      );
      await ref.read(dataServiceProvider).updateUserProfile(updated);
      ref.read(userProfileProvider.notifier).state = updated;
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'This will sign you out of your Threshold account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.primary,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sign out'),
              ),
            ],
          ),
    );
    if ((confirmed ?? false) && mounted) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete account?'),
            content: const Text(
              'This permanently deletes your Threshold account and all agreements '
              'stored on this device. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete account'),
              ),
            ],
          ),
    );
    if ((confirmed ?? false) && mounted) await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;

      // Delete Firestore profile
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // Clear local agreements
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/agreements',
      );
      if (dir.existsSync()) dir.deleteSync(recursive: true);

      // Delete Firebase Auth account (must be last — loses credentials)
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && mounted) {
        setState(
          () =>
              _error =
                  'Please sign out and sign back in before deleting your account.',
        );
        setState(() => _deleting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Delete failed: $e';
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(foregroundColor: cs.onSurface),
            child:
                _saving
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text('Save', style: TextStyle(color: cs.onSurface)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account info (read-only)
                _sectionLabel('Account'),
                const SizedBox(height: 8),
                _readOnlyTile(Icons.email_outlined, profile?.email ?? ''),
                const SizedBox(height: 16),

                // Sign out
                OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),

                // Name
                _sectionLabel('Your name'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Brokerage
                _sectionLabel('Brokerage'),
                const SizedBox(height: 8),
                TextField(
                  controller: _brokerageNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Brokerage name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _brokerageAddressCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Street address (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _brokerageCityStateZipCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'City, State, Zip (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _state,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select your state'),
                  items:
                      kAllUsStates
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _state = v),
                ),

                if (_state == 'Oklahoma') ...[
                  const SizedBox(height: 24),
                  _sectionLabel('Oklahoma license info'),
                  const SizedBox(height: 4),
                  Text(
                    'Pre-filled on every OREC form — no need to enter each time.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _agentLicenseCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Associate broker license number',
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
                  const SizedBox(height: 16),
                  _sectionLabel('Managing broker'),
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

                if (_state == 'Colorado') ...[
                  const SizedBox(height: 24),
                  _sectionLabel('Firm type'),
                  const SizedBox(height: 8),
                  _choiceCard(
                    label: 'Multiple-person firm',
                    subtitle: 'Section 2.1 — designated broker within the firm',
                    selected: _isMultiPersonFirm,
                    onTap: () => setState(() => _isMultiPersonFirm = true),
                    cs: cs,
                  ),
                  const SizedBox(height: 8),
                  _choiceCard(
                    label: 'One-person firm',
                    subtitle: 'Section 2.2 — sole licensed person',
                    selected: !_isMultiPersonFirm,
                    onTap: () => setState(() => _isMultiPersonFirm = false),
                    cs: cs,
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('Brokerage relationship'),
                  const SizedBox(height: 8),
                  _choiceCard(
                    label: 'Buyer Agency',
                    subtitle: 'You represent the buyer',
                    selected: _isBuyerAgency,
                    onTap: () => setState(() => _isBuyerAgency = true),
                    cs: cs,
                  ),
                  const SizedBox(height: 8),
                  _choiceCard(
                    label: 'Transaction-Brokerage',
                    subtitle: 'You assist without representing either party',
                    selected: !_isBuyerAgency,
                    onTap: () => setState(() => _isBuyerAgency = false),
                    cs: cs,
                  ),
                ],

                if (_saved) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: cs.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('Saved', style: TextStyle(color: cs.primary)),
                    ],
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 24),

                // Subscription
                _sectionLabel('Subscription'),
                const SizedBox(height: 12),
                _SubscriptionTile(),
                const SizedBox(height: 24),
                const Divider(),

                const SizedBox(height: 16),

                // Delete account
                FilledButton.icon(
                  onPressed: _deleting ? null : _confirmDeleteAccount,
                  icon:
                      _deleting
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete account'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed:
                          () => launchUrl(
                            Uri.parse('https://auaha.app/threshold/terms'),
                            mode: LaunchMode.externalApplication,
                          ),
                      child: Text(
                        'Terms of Use',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      '·',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed:
                          () => launchUrl(
                            Uri.parse('https://auaha.app/threshold/privacy'),
                            mode: LaunchMode.externalApplication,
                          ),
                      child: Text(
                        'Privacy Policy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

  Widget _readOnlyTile(IconData icon, String text) => Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );

  Widget _choiceCard({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
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

class _SubscriptionTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final sub = ref.watch(subscriptionProvider);
    final isPro =
        !kPaywallEnabled ||
        (sub.valueOrNull?.entitlements.active.containsKey(kEntitlementId) ??
            false);

    if (isPro) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: cs.primaryContainer.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Threshold Pro',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Active subscription',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: cs.primary),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Free plan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$kFreeAgreementLimit agreements included',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => showPaywall(context),
          icon: const Icon(Icons.star_outline),
          label: const Text('Upgrade to Threshold Pro'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}
