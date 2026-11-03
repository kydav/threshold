import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threshold/core/config/revenue_cat_config.dart';
import 'package:threshold/core/services/data_service.dart';
import 'package:threshold/core/services/remote_config_service.dart';
import 'package:threshold/core/services/subscription_service.dart';
import 'package:threshold/features/auth/data/user_profile.dart';
import 'package:threshold/features/paywall/presentation/paywall_screen.dart';

/// The free-tier limit, shared by the state forms and the agent's own forms.
///
/// Returns true when the agent may send another agreement: they're Pro, the
/// paywall is off, they're under [kFreeAgreementLimit], or they subscribe
/// from the paywall shown here.
Future<bool> canSendAgreement(BuildContext context, WidgetRef ref) async {
  final remotePaywallEnabled = ref.read(remoteConfigProvider).paywallEnabled;
  if (!kPaywallEnabled || !remotePaywallEnabled) return true;
  final customerInfo = await ref.read(subscriptionProvider.future);
  if (customerInfo?.entitlements.active.containsKey(kEntitlementId) ?? false) {
    return true;
  }
  final sent = ref.read(userProfileProvider)?.agreementsSent ?? 0;
  if (sent < kFreeAgreementLimit) return true;
  if (!context.mounted) return false;
  return showPaywall(context);
}

/// Counts a sent agreement in Firestore (survives reinstalls) and in the
/// loaded profile.
Future<void> recordAgreementSent(WidgetRef ref, String uid) async {
  await ref.read(dataServiceProvider).incrementAgreementsSent(uid);
  final notifier = ref.read(userProfileProvider.notifier);
  final profile = notifier.state;
  if (profile != null) {
    notifier.state = profile.withAgreementsSent(profile.agreementsSent + 1);
  }
}
