enum AgreementStatus { draft, signed, pendingDelivery, delivered }

class AgreementModel {
  AgreementModel({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.agentEmail,
    required this.brokerageName,
    required this.buyerName,
    required this.buyerEmail,
    required this.propertyScope,
    required this.compensation,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    this.signedAt,
    this.localPdfPath,
    this.deliveredAt,
    this.formState = 'Colorado',
  });

  final String id;
  final String agentId;
  final String agentName;
  final String agentEmail;
  final String brokerageName;
  final String buyerName;
  final String buyerEmail;
  final String propertyScope;
  final String compensation;
  final DateTime startDate;
  final DateTime endDate;
  final AgreementStatus status;
  final DateTime createdAt;
  final DateTime? signedAt;
  final String? localPdfPath;
  final DateTime? deliveredAt;
  final String formState;

  bool get isPendingDelivery => status == AgreementStatus.pendingDelivery;
  bool get hasLocalPdf => localPdfPath != null;

  factory AgreementModel.fromJson(Map<String, dynamic> d) => AgreementModel(
        id: d['id'] as String,
        agentId: d['agentId'] as String,
        agentName: d['agentName'] as String? ?? '',
        agentEmail: d['agentEmail'] as String? ?? '',
        brokerageName: d['brokerageName'] as String? ?? '',
        buyerName: d['buyerName'] as String,
        buyerEmail: d['buyerEmail'] as String,
        propertyScope: d['propertyScope'] as String,
        compensation: d['compensation'] as String,
        startDate: DateTime.parse(d['startDate'] as String),
        endDate: DateTime.parse(d['endDate'] as String),
        status: _statusFromString(d['status'] as String? ?? 'draft'),
        createdAt: DateTime.parse(d['createdAt'] as String),
        signedAt: d['signedAt'] != null
            ? DateTime.parse(d['signedAt'] as String)
            : null,
        localPdfPath: d['localPdfPath'] as String?,
        deliveredAt: d['deliveredAt'] != null
            ? DateTime.parse(d['deliveredAt'] as String)
            : null,
        formState: d['formState'] as String? ?? 'Colorado',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'agentId': agentId,
        'agentName': agentName,
        'agentEmail': agentEmail,
        'brokerageName': brokerageName,
        'buyerName': buyerName,
        'buyerEmail': buyerEmail,
        'propertyScope': propertyScope,
        'compensation': compensation,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'status': _statusToString(status),
        'createdAt': createdAt.toIso8601String(),
        if (signedAt != null) 'signedAt': signedAt!.toIso8601String(),
        if (localPdfPath != null) 'localPdfPath': localPdfPath,
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
        'formState': formState,
      };

  AgreementModel copyWith({
    AgreementStatus? status,
    String? localPdfPath,
    DateTime? signedAt,
    DateTime? deliveredAt,
  }) =>
      AgreementModel(
        id: id,
        agentId: agentId,
        agentName: agentName,
        agentEmail: agentEmail,
        brokerageName: brokerageName,
        buyerName: buyerName,
        buyerEmail: buyerEmail,
        propertyScope: propertyScope,
        compensation: compensation,
        startDate: startDate,
        endDate: endDate,
        status: status ?? this.status,
        createdAt: createdAt,
        signedAt: signedAt ?? this.signedAt,
        localPdfPath: localPdfPath ?? this.localPdfPath,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        formState: formState,
      );

  static AgreementStatus _statusFromString(String s) => switch (s) {
        'signed' => AgreementStatus.signed,
        'pending_delivery' => AgreementStatus.pendingDelivery,
        'delivered' => AgreementStatus.delivered,
        _ => AgreementStatus.draft,
      };

  static String _statusToString(AgreementStatus s) => switch (s) {
        AgreementStatus.signed => 'signed',
        AgreementStatus.pendingDelivery => 'pending_delivery',
        AgreementStatus.delivered => 'delivered',
        AgreementStatus.draft => 'draft',
      };
}
