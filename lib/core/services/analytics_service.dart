import 'package:firebase_analytics/firebase_analytics.dart';

final _fa = FirebaseAnalytics.instance;

class AnalyticsService {
  AnalyticsService._();

  static void signUp({required String state}) =>
      _fa.logSignUp(signUpMethod: 'email').ignore();

  static void login() => _fa.logLogin(loginMethod: 'email').ignore();

  static void formSubmitted({required String formState}) =>
      _fa.logEvent(name: 'form_submitted', parameters: {'form_state': formState}).ignore();

  static void pdfGenerated({required String formState}) =>
      _fa.logEvent(name: 'pdf_generated', parameters: {'form_state': formState}).ignore();

  static void agreementDelivered() =>
      _fa.logEvent(name: 'agreement_delivered').ignore();

  static void paywallShown() =>
      _fa.logEvent(name: 'paywall_shown').ignore();

  static void subscriptionPurchased() =>
      _fa.logPurchase(currency: 'USD', value: 4.99).ignore();

  static void subscriptionRestored() =>
      _fa.logEvent(name: 'subscription_restored').ignore();
}
