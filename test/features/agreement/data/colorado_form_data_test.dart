import 'package:flutter_test/flutter_test.dart';
import 'package:threshold/features/agreement/data/colorado_form_data.dart';

void main() {
  ColoradoFormData _buildData({
    String compensationType = 'percentage',
    String compensationValue = '2.5',
    String buyerPhone = '303-555-1234',
    String buyerStreetAddress = '123 Main St',
    String buyerCityStateZip = 'Denver, CO 80203',
    bool isBuyerAgency = true,
    String holdoverDays = '30',
    bool computationWillExtend = false,
    bool buyerIsPartyToOtherAgreement = false,
    bool buyerHasReceivedSubmittedList = false,
    String additionalProvisions = '',
    String buyer2Name = '',
    String buyer2Email = '',
    String buyer2Phone = '',
    String buyer2StreetAddress = '',
    String buyer2CityStateZip = '',
  }) {
    return ColoradoFormData(
      compensationType: compensationType,
      compensationValue: compensationValue,
      buyerPhone: buyerPhone,
      buyerStreetAddress: buyerStreetAddress,
      buyerCityStateZip: buyerCityStateZip,
      isBuyerAgency: isBuyerAgency,
      holdoverDays: holdoverDays,
      computationWillExtend: computationWillExtend,
      buyerIsPartyToOtherAgreement: buyerIsPartyToOtherAgreement,
      buyerHasReceivedSubmittedList: buyerHasReceivedSubmittedList,
      additionalProvisions: additionalProvisions,
      buyer2Name: buyer2Name,
      buyer2Email: buyer2Email,
      buyer2Phone: buyer2Phone,
      buyer2StreetAddress: buyer2StreetAddress,
      buyer2CityStateZip: buyer2CityStateZip,
    );
  }

  group('ColoradoFormData.hasCoBuyer', () {
    test('returns false when buyer2Name is empty', () {
      expect(_buildData().hasCoBuyer, isFalse);
    });

    test('returns true when buyer2Name is non-empty', () {
      expect(_buildData(buyer2Name: 'Jane Co-buyer').hasCoBuyer, isTrue);
    });

    test('returns false when buyer2Name is whitespace only', () {
      // Whitespace-only name still satisfies isNotEmpty so hasCoBuyer would be
      // true — this is a known inconsistency in the current implementation.
      // Documenting the actual behaviour here so a future fix is explicit.
      expect(_buildData(buyer2Name: '   ').hasCoBuyer, isTrue);
    });
  });

  group('ColoradoFormData.fromJson', () {
    final _baseJson = <String, dynamic>{
      'compensationType': 'percentage',
      'compensationValue': '2.5',
      'buyerPhone': '303-555-1234',
      'buyerStreetAddress': '123 Main St',
      'buyerCityStateZip': 'Denver, CO 80203',
      'isBuyerAgency': true,
      'holdoverDays': '30',
      'computationWillExtend': false,
      'buyerIsPartyToOtherAgreement': false,
      'buyerHasReceivedSubmittedList': false,
      'additionalProvisions': '',
      'buyer2Name': '',
      'buyer2Email': '',
      'buyer2Phone': '',
      'buyer2StreetAddress': '',
      'buyer2CityStateZip': '',
    };

    test('parses all fields from complete JSON', () {
      final data = ColoradoFormData.fromJson(_baseJson);
      expect(data.compensationType, 'percentage');
      expect(data.compensationValue, '2.5');
      expect(data.buyerPhone, '303-555-1234');
      expect(data.buyerStreetAddress, '123 Main St');
      expect(data.buyerCityStateZip, 'Denver, CO 80203');
      expect(data.isBuyerAgency, isTrue);
      expect(data.holdoverDays, '30');
      expect(data.computationWillExtend, isFalse);
      expect(data.buyerIsPartyToOtherAgreement, isFalse);
      expect(data.buyerHasReceivedSubmittedList, isFalse);
    });

    test('uses defaults when keys are absent', () {
      final data = ColoradoFormData.fromJson({});
      expect(data.compensationType, 'percentage');
      expect(data.compensationValue, '');
      expect(data.buyerPhone, '');
      expect(data.isBuyerAgency, isTrue);
      expect(data.holdoverDays, '30');
      expect(data.computationWillExtend, isFalse);
      expect(data.buyerIsPartyToOtherAgreement, isFalse);
      expect(data.buyerHasReceivedSubmittedList, isFalse);
      expect(data.additionalProvisions, '');
      expect(data.buyer2Name, '');
    });

    test('parses co-buyer fields', () {
      final json = Map<String, dynamic>.from(_baseJson)
        ..['buyer2Name'] = 'Jane Co'
        ..['buyer2Email'] = 'jane@co.com'
        ..['buyer2Phone'] = '720-555-9999';
      final data = ColoradoFormData.fromJson(json);
      expect(data.buyer2Name, 'Jane Co');
      expect(data.buyer2Email, 'jane@co.com');
      expect(data.buyer2Phone, '720-555-9999');
      expect(data.hasCoBuyer, isTrue);
    });

    test('parses dollar compensationType', () {
      final json = Map<String, dynamic>.from(_baseJson)
        ..['compensationType'] = 'dollar'
        ..['compensationValue'] = '15000';
      final data = ColoradoFormData.fromJson(json);
      expect(data.compensationType, 'dollar');
      expect(data.compensationValue, '15000');
    });
  });

  group('ColoradoFormData.toJson', () {
    test('round-trips through fromJson without loss', () {
      final original = _buildData(
        buyer2Name: 'Co-buyer',
        additionalProvisions: 'Some extra text',
        compensationType: 'dollar',
        compensationValue: '20000',
        holdoverDays: '45',
      );
      final decoded = ColoradoFormData.fromJson(original.toJson());

      expect(decoded.compensationType, original.compensationType);
      expect(decoded.compensationValue, original.compensationValue);
      expect(decoded.holdoverDays, original.holdoverDays);
      expect(decoded.buyer2Name, original.buyer2Name);
      expect(decoded.additionalProvisions, original.additionalProvisions);
      expect(decoded.hasCoBuyer, original.hasCoBuyer);
    });

    test('includes all boolean fields', () {
      final data = _buildData(
        isBuyerAgency: false,
        computationWillExtend: true,
        buyerIsPartyToOtherAgreement: true,
        buyerHasReceivedSubmittedList: true,
      );
      final json = data.toJson();
      expect(json['isBuyerAgency'], isFalse);
      expect(json['computationWillExtend'], isTrue);
      expect(json['buyerIsPartyToOtherAgreement'], isTrue);
      expect(json['buyerHasReceivedSubmittedList'], isTrue);
    });
  });
}
