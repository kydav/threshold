import 'package:flutter_test/flutter_test.dart';
import 'package:threshold/features/agreement/data/agreement_model.dart';
import 'package:threshold/features/agreement/presentation/agreement_actions.dart';

AgreementModel _a(AgreementStatus s) => AgreementModel(
  id: s.name,
  agentId: 'a',
  agentName: '',
  agentEmail: '',
  brokerageName: '',
  buyerName: 'B',
  buyerEmail: '',
  propertyScope: '',
  compensation: '',
  startDate: DateTime(2026),
  endDate: DateTime(2027),
  status: s,
  createdAt: DateTime(2026),
);

void main() {
  test('Home filters group statuses the way the counts show them', () {
    final all = [for (final s in AgreementStatus.values) _a(s)];
    List<String> ids(AgreementFilter f) => [
      for (final a in all)
        if (f.matches(a)) a.id,
    ];
    expect(ids(AgreementFilter.drafts), ['draft']);
    expect(ids(AgreementFilter.signed), ['signed', 'pendingDelivery']);
    expect(ids(AgreementFilter.delivered), ['delivered']);
  });

  test('parses the route query, ignoring unknown values', () {
    expect(AgreementFilter.parse('signed'), AgreementFilter.signed);
    expect(AgreementFilter.parse('nope'), isNull);
    expect(AgreementFilter.parse(null), isNull);
  });
}
