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
    this.buyer2Name = '',
    this.buyer2Email = '',
    this.buyer2Phone = '',
    this.buyer2StreetAddress = '',
    this.buyer2CityStateZip = '',
  });

  // 'percentage' or 'dollar'
  final String compensationType;
  final String compensationValue;

  final String buyerPhone;
  final String buyerStreetAddress;
  final String buyerCityStateZip;

  // Co-buyer (optional — empty string means no co-buyer)
  final String buyer2Name;
  final String buyer2Email;
  final String buyer2Phone;
  final String buyer2StreetAddress;
  final String buyer2CityStateZip;

  bool get hasCoBuyer => buyer2Name.trim().isNotEmpty;

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

  factory ColoradoFormData.fromJson(Map<String, dynamic> d) => ColoradoFormData(
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
    buyer2Name: d['buyer2Name'] as String? ?? '',
    buyer2Email: d['buyer2Email'] as String? ?? '',
    buyer2Phone: d['buyer2Phone'] as String? ?? '',
    buyer2StreetAddress: d['buyer2StreetAddress'] as String? ?? '',
    buyer2CityStateZip: d['buyer2CityStateZip'] as String? ?? '',
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
    'buyer2Name': buyer2Name,
    'buyer2Email': buyer2Email,
    'buyer2Phone': buyer2Phone,
    'buyer2StreetAddress': buyer2StreetAddress,
    'buyer2CityStateZip': buyer2CityStateZip,
  };
}
