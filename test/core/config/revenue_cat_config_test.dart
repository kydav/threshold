import 'package:flutter_test/flutter_test.dart';
import 'package:threshold/core/config/revenue_cat_config.dart';

void main() {
  group('RevenueCat config constants', () {
    test('iOS key starts with "appl_"', () {
      expect(kRevenueCatIosKey.startsWith('appl_'), isTrue,
          reason: 'iOS RevenueCat keys use the "appl_" prefix');
    });

    test('Android key starts with "goog_"', () {
      expect(kRevenueCatAndroidKey.startsWith('goog_'), isTrue,
          reason: 'Android RevenueCat keys use the "goog_" prefix');
    });

    test('entitlement ID is non-empty', () {
      expect(kEntitlementId, isNotEmpty);
    });

    test('entitlement ID is "Threshold Pro"', () {
      expect(kEntitlementId, 'Threshold Pro');
    });

    test('free agreement limit is a positive integer', () {
      expect(kFreeAgreementLimit, greaterThan(0));
    });

    test('free agreement limit is 2', () {
      expect(kFreeAgreementLimit, 2);
    });

    test('kPaywallEnabled defaults to true in test environment', () {
      // In tests, dart-define is not set, so the default applies.
      expect(kPaywallEnabled, isTrue);
    });
  });
}
