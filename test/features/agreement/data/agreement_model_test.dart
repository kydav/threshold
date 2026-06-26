import 'package:flutter_test/flutter_test.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';

void main() {
  final baseJson = <String, dynamic>{
    'id': 'abc-123',
    'agentId': 'agent-1',
    'agentName': 'Jane Agent',
    'agentEmail': 'jane@brokerage.com',
    'brokerageName': 'Acme Realty',
    'buyerName': 'John Buyer',
    'buyerEmail': 'john@example.com',
    'propertyScope': 'Any home in Denver metro',
    'compensation': '2.5%',
    'startDate': '2025-01-01T00:00:00.000',
    'endDate': '2025-04-01T00:00:00.000',
    'status': 'draft',
    'createdAt': '2025-01-01T00:00:00.000',
  };

  AgreementModel buildModel({
    AgreementStatus status = AgreementStatus.draft,
    String? localPdfPath,
    DateTime? signedAt,
    DateTime? deliveredAt,
    Map<String, dynamic> formData = const {},
  }) {
    return AgreementModel(
      id: 'abc-123',
      agentId: 'agent-1',
      agentName: 'Jane Agent',
      agentEmail: 'jane@brokerage.com',
      brokerageName: 'Acme Realty',
      buyerName: 'John Buyer',
      buyerEmail: 'john@example.com',
      propertyScope: 'Any home in Denver metro',
      compensation: '2.5%',
      startDate: DateTime(2025),
      endDate: DateTime(2025, 4),
      status: status,
      createdAt: DateTime(2025),
      signedAt: signedAt,
      localPdfPath: localPdfPath,
      deliveredAt: deliveredAt,
      formData: formData,
    );
  }

  group('AgreementModel.fromJson', () {
    test('parses all required fields correctly', () {
      final model = AgreementModel.fromJson(baseJson);

      expect(model.id, 'abc-123');
      expect(model.agentId, 'agent-1');
      expect(model.agentName, 'Jane Agent');
      expect(model.agentEmail, 'jane@brokerage.com');
      expect(model.brokerageName, 'Acme Realty');
      expect(model.buyerName, 'John Buyer');
      expect(model.buyerEmail, 'john@example.com');
      expect(model.propertyScope, 'Any home in Denver metro');
      expect(model.compensation, '2.5%');
      expect(model.startDate, DateTime(2025));
      expect(model.endDate, DateTime(2025, 4));
      expect(model.status, AgreementStatus.draft);
      expect(model.createdAt, DateTime(2025));
      expect(model.signedAt, isNull);
      expect(model.localPdfPath, isNull);
      expect(model.deliveredAt, isNull);
    });

    test(
      'defaults agentName, agentEmail, brokerageName to empty string when missing',
      () {
        final json =
            Map<String, dynamic>.from(baseJson)
              ..remove('agentName')
              ..remove('agentEmail')
              ..remove('brokerageName');
        final model = AgreementModel.fromJson(json);
        expect(model.agentName, '');
        expect(model.agentEmail, '');
        expect(model.brokerageName, '');
      },
    );

    test('defaults status to draft when missing', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('status');
      final model = AgreementModel.fromJson(json);
      expect(model.status, AgreementStatus.draft);
    });

    test('defaults formState to Colorado when missing', () {
      final model = AgreementModel.fromJson(baseJson);
      expect(model.formState, 'Colorado');
    });

    test('defaults formData to empty map when missing', () {
      final model = AgreementModel.fromJson(baseJson);
      expect(model.formData, isEmpty);
    });

    test('parses signedAt when present', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['signedAt'] = '2025-01-15T10:30:00.000';
      final model = AgreementModel.fromJson(json);
      expect(model.signedAt, DateTime(2025, 1, 15, 10, 30));
    });

    test('parses deliveredAt when present', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['deliveredAt'] = '2025-01-16T12:00:00.000';
      final model = AgreementModel.fromJson(json);
      expect(model.deliveredAt, DateTime(2025, 1, 16, 12));
    });

    test('parses formData map when present', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['formData'] = {'buyerPhone': '303-555-1234'};
      final model = AgreementModel.fromJson(json);
      expect(model.formData['buyerPhone'], '303-555-1234');
    });
  });

  group('AgreementModel status parsing', () {
    for (final entry
        in {
          'draft': AgreementStatus.draft,
          'signed': AgreementStatus.signed,
          'pending_delivery': AgreementStatus.pendingDelivery,
          'delivered': AgreementStatus.delivered,
          'unknown_value': AgreementStatus.draft,
          '': AgreementStatus.draft,
        }.entries) {
      test('status "${entry.key}" → ${entry.value}', () {
        final json = Map<String, dynamic>.from(baseJson)
          ..['status'] = entry.key;
        expect(AgreementModel.fromJson(json).status, entry.value);
      });
    }
  });

  group('AgreementModel.toJson', () {
    test('round-trips through fromJson without loss', () {
      final original = buildModel();
      final decoded = AgreementModel.fromJson(original.toJson());

      expect(decoded.id, original.id);
      expect(decoded.agentId, original.agentId);
      expect(decoded.buyerName, original.buyerName);
      expect(decoded.status, original.status);
      expect(decoded.startDate, original.startDate);
      expect(decoded.endDate, original.endDate);
    });

    test('omits signedAt key when null', () {
      final json = buildModel().toJson();
      expect(json.containsKey('signedAt'), isFalse);
    });

    test('includes signedAt when set', () {
      final signed = buildModel(signedAt: DateTime(2025, 2));
      expect(signed.toJson()['signedAt'], isNotNull);
    });

    test('omits localPdfPath when null', () {
      final json = buildModel().toJson();
      expect(json.containsKey('localPdfPath'), isFalse);
    });

    test('includes localPdfPath when set', () {
      final m = buildModel(localPdfPath: '/docs/agreement.pdf');
      expect(m.toJson()['localPdfPath'], '/docs/agreement.pdf');
    });

    test('omits deliveredAt when null', () {
      final json = buildModel().toJson();
      expect(json.containsKey('deliveredAt'), isFalse);
    });

    test('omits formData key when empty', () {
      final json = buildModel().toJson();
      expect(json.containsKey('formData'), isFalse);
    });

    test('includes formData when non-empty', () {
      final m = buildModel(formData: {'key': 'value'});
      expect(m.toJson()['formData'], {'key': 'value'});
    });

    test('serialises status to correct strings', () {
      expect(
        buildModel(status: AgreementStatus.pendingDelivery).toJson()['status'],
        'pending_delivery',
      );
      expect(
        buildModel(status: AgreementStatus.delivered).toJson()['status'],
        'delivered',
      );
      expect(
        buildModel(status: AgreementStatus.signed).toJson()['status'],
        'signed',
      );
      expect(buildModel().toJson()['status'], 'draft');
    });
  });

  group('AgreementModel computed properties', () {
    test('isPendingDelivery is true only for pendingDelivery status', () {
      expect(
        buildModel(status: AgreementStatus.pendingDelivery).isPendingDelivery,
        isTrue,
      );
      expect(buildModel().isPendingDelivery, isFalse);
      expect(
        buildModel(status: AgreementStatus.signed).isPendingDelivery,
        isFalse,
      );
      expect(
        buildModel(status: AgreementStatus.delivered).isPendingDelivery,
        isFalse,
      );
    });

    test('hasLocalPdf is true when localPdfPath is set', () {
      expect(buildModel(localPdfPath: '/some/path.pdf').hasLocalPdf, isTrue);
    });

    test('hasLocalPdf is false when localPdfPath is null', () {
      expect(buildModel().hasLocalPdf, isFalse);
    });
  });

  group('AgreementModel.copyWith', () {
    test('returns new instance with updated status', () {
      final original = buildModel();
      final updated = original.copyWith(status: AgreementStatus.signed);
      expect(updated.status, AgreementStatus.signed);
      expect(original.status, AgreementStatus.draft); // original unchanged
    });

    test('preserves unchanged fields', () {
      final original = buildModel();
      final updated = original.copyWith(status: AgreementStatus.delivered);
      expect(updated.buyerName, original.buyerName);
      expect(updated.agentId, original.agentId);
      expect(updated.compensation, original.compensation);
    });

    test('can update localPdfPath', () {
      final updated = buildModel().copyWith(localPdfPath: '/new/path.pdf');
      expect(updated.localPdfPath, '/new/path.pdf');
    });

    test('can update signedAt', () {
      final ts = DateTime(2025, 3, 15);
      final updated = buildModel().copyWith(signedAt: ts);
      expect(updated.signedAt, ts);
    });

    test('can update deliveredAt', () {
      final ts = DateTime(2025, 3, 16);
      final updated = buildModel().copyWith(deliveredAt: ts);
      expect(updated.deliveredAt, ts);
    });
  });
}
