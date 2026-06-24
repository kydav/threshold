import 'package:flutter_test/flutter_test.dart';
import 'package:threshold/features/auth/data/user_profile.dart';

// Minimal stub that mimics DocumentSnapshot without pulling in firebase_core.
class _FakeDoc {
  _FakeDoc(this.id, this._data);
  final String id;
  final Map<String, dynamic>? _data;
  Object? data() => _data;
}

// Helper to build a UserProfile directly (bypasses Firestore).
UserProfile _build({
  String uid = 'uid-1',
  String email = 'agent@test.com',
  String firstName = 'Jane',
  String lastName = 'Smith',
  String brokerageName = 'Acme Realty',
  String brokerageAddress = '100 Main St',
  String brokerageCityStateZip = 'Denver, CO 80201',
  String phone = '303-555-0000',
  String state = 'Colorado',
  bool isMultiPersonFirm = false,
  bool isBuyerAgency = true,
  int agreementsSent = 0,
  String agentLicenseNumber = '',
  String brokerageLicenseNumber = '',
  String managingBrokerName = '',
  String managingBrokerPhone = '',
  String managingBrokerEmail = '',
}) {
  return UserProfile(
    uid: uid,
    email: email,
    firstName: firstName,
    lastName: lastName,
    brokerageName: brokerageName,
    brokerageAddress: brokerageAddress,
    brokerageCityStateZip: brokerageCityStateZip,
    phone: phone,
    state: state,
    isMultiPersonFirm: isMultiPersonFirm,
    isBuyerAgency: isBuyerAgency,
    agreementsSent: agreementsSent,
    agentLicenseNumber: agentLicenseNumber,
    brokerageLicenseNumber: brokerageLicenseNumber,
    managingBrokerName: managingBrokerName,
    managingBrokerPhone: managingBrokerPhone,
    managingBrokerEmail: managingBrokerEmail,
  );
}

void main() {
  group('UserProfile.fullName', () {
    test('concatenates firstName and lastName with a space', () {
      final profile = _build(firstName: 'Jane', lastName: 'Smith');
      expect(profile.fullName, 'Jane Smith');
    });

    test('trims result when lastName is empty', () {
      final profile = _build(firstName: 'Cher', lastName: '');
      expect(profile.fullName, 'Cher');
    });

    test('trims result when firstName is empty', () {
      final profile = _build(firstName: '', lastName: 'Smith');
      expect(profile.fullName, 'Smith');
    });

    test('returns empty string when both names are empty', () {
      final profile = _build(firstName: '', lastName: '');
      expect(profile.fullName, '');
    });
  });

  group('UserProfile.toFirestore', () {
    test('contains all expected keys', () {
      final profile = _build();
      final map = profile.toFirestore();

      expect(map.containsKey('email'), isTrue);
      expect(map.containsKey('firstName'), isTrue);
      expect(map.containsKey('lastName'), isTrue);
      expect(map.containsKey('brokerageName'), isTrue);
      expect(map.containsKey('brokerageAddress'), isTrue);
      expect(map.containsKey('brokerageCityStateZip'), isTrue);
      expect(map.containsKey('phone'), isTrue);
      expect(map.containsKey('state'), isTrue);
      expect(map.containsKey('isMultiPersonFirm'), isTrue);
      expect(map.containsKey('isBuyerAgency'), isTrue);
      expect(map.containsKey('agentLicenseNumber'), isTrue);
      expect(map.containsKey('brokerageLicenseNumber'), isTrue);
      expect(map.containsKey('managingBrokerName'), isTrue);
      expect(map.containsKey('managingBrokerPhone'), isTrue);
      expect(map.containsKey('managingBrokerEmail'), isTrue);
      expect(map.containsKey('createdAt'), isTrue);
    });

    test('does NOT include uid in the Firestore map', () {
      // uid is the document ID, not a stored field
      final map = _build().toFirestore();
      expect(map.containsKey('uid'), isFalse);
    });

    test('does NOT include agreementsSent in the Firestore write map', () {
      // agreementsSent is managed server-side via FieldValue.increment,
      // so writing it from toFirestore() would reset the counter — this
      // verifies the field is intentionally excluded.
      final map = _build(agreementsSent: 5).toFirestore();
      expect(map.containsKey('agreementsSent'), isFalse);
    });

    test('values match the profile fields', () {
      final profile = _build(
        email: 'agent@test.com',
        firstName: 'Jane',
        lastName: 'Smith',
        state: 'Oklahoma',
        isMultiPersonFirm: true,
      );
      final map = profile.toFirestore();
      expect(map['email'], 'agent@test.com');
      expect(map['firstName'], 'Jane');
      expect(map['lastName'], 'Smith');
      expect(map['state'], 'Oklahoma');
      expect(map['isMultiPersonFirm'], isTrue);
    });
  });

  group('kSupportedStates', () {
    test('contains Colorado', () {
      expect(kSupportedStates.contains('Colorado'), isTrue);
    });

    test('contains Louisiana', () {
      expect(kSupportedStates.contains('Louisiana'), isTrue);
    });

    test('contains Oklahoma', () {
      expect(kSupportedStates.contains('Oklahoma'), isTrue);
    });

    test('contains Wisconsin', () {
      expect(kSupportedStates.contains('Wisconsin'), isTrue);
    });

    test('does not contain Utah (form commented out in router)', () {
      expect(kSupportedStates.contains('Utah'), isFalse);
    });

    test('has exactly 4 supported states', () {
      expect(kSupportedStates.length, 4);
    });
  });
}
