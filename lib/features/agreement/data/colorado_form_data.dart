/// Colorado BC60 specific fields beyond the base AgreementModel.
class ColoradoFormData {
  const ColoradoFormData({
    required this.buyerPhone,
    required this.buyerStreetAddress,
    required this.buyerCityStateZip,
    required this.isBuyerAgency,
    required this.compensationType,
    required this.compensationValue,
    required this.holdoverDays,
    required this.computationWillExtend,
    required this.buyerIsPartyToOtherAgreement,
    required this.buyerHasReceivedSubmittedList,
    this.additionalProvisions = '',
  });

  // 'percentage' or 'dollar'
  final String compensationType;
  final String compensationValue;

  final String buyerPhone;
  final String buyerStreetAddress;
  final String buyerCityStateZip;

  // Section 4: brokerage relationship
  final bool isBuyerAgency;

  // Section 3: holdover period
  final String holdoverDays;

  // Computation of date deadlines (Section 3)
  final bool computationWillExtend;

  // Section 9 — buyer obligations
  final bool buyerIsPartyToOtherAgreement;
  final bool buyerHasReceivedSubmittedList;

  final String additionalProvisions;

  factory ColoradoFormData.fromJson(Map<String, dynamic> d) =>
      ColoradoFormData(
        compensationType: d['compensationType'] as String? ?? 'percentage',
        compensationValue: d['compensationValue'] as String? ?? '',
        buyerPhone: d['buyerPhone'] as String? ?? '',
        buyerStreetAddress: d['buyerStreetAddress'] as String? ?? '',
        buyerCityStateZip: d['buyerCityStateZip'] as String? ?? '',
        isBuyerAgency: d['isBuyerAgency'] as bool? ?? true,
        holdoverDays: d['holdoverDays'] as String? ?? '30',
        computationWillExtend: d['computationWillExtend'] as bool? ?? false,
        buyerIsPartyToOtherAgreement:
            d['buyerIsPartyToOtherAgreement'] as bool? ?? false,
        buyerHasReceivedSubmittedList:
            d['buyerHasReceivedSubmittedList'] as bool? ?? false,
        additionalProvisions: d['additionalProvisions'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'compensationType': compensationType,
        'compensationValue': compensationValue,
        'buyerPhone': buyerPhone,
        'buyerStreetAddress': buyerStreetAddress,
        'buyerCityStateZip': buyerCityStateZip,
        'isBuyerAgency': isBuyerAgency,
        'holdoverDays': holdoverDays,
        'computationWillExtend': computationWillExtend,
        'buyerIsPartyToOtherAgreement': buyerIsPartyToOtherAgreement,
        'buyerHasReceivedSubmittedList': buyerHasReceivedSubmittedList,
        'additionalProvisions': additionalProvisions,
      };
}
