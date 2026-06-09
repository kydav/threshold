import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.storagePdfPath,
    this.deliveredAt,
    this.signingLatitude,
    this.signingLongitude,
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
  final String? storagePdfPath;
  final DateTime? deliveredAt;
  final double? signingLatitude;
  final double? signingLongitude;
  final String formState;

  bool get isDelivered => status == AgreementStatus.delivered;
  bool get isPendingDelivery => status == AgreementStatus.pendingDelivery;
  bool get hasLocalPdf => localPdfPath != null;

  factory AgreementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AgreementModel(
      id: doc.id,
      agentId: d['agentId'] as String,
      agentName: d['agentName'] as String? ?? '',
      agentEmail: d['agentEmail'] as String? ?? '',
      brokerageName: d['brokerageName'] as String? ?? '',
      buyerName: d['buyerName'] as String,
      buyerEmail: d['buyerEmail'] as String,
      propertyScope: d['propertyScope'] as String,
      compensation: d['compensation'] as String,
      startDate: (d['startDate'] as Timestamp).toDate(),
      endDate: (d['endDate'] as Timestamp).toDate(),
      status: _statusFromString(d['status'] as String? ?? 'draft'),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      signedAt: d['signedAt'] != null ? (d['signedAt'] as Timestamp).toDate() : null,
      localPdfPath: d['localPdfPath'] as String?,
      storagePdfPath: d['storagePdfPath'] as String?,
      deliveredAt: d['deliveredAt'] != null ? (d['deliveredAt'] as Timestamp).toDate() : null,
      signingLatitude: (d['signingLatitude'] as num?)?.toDouble(),
      signingLongitude: (d['signingLongitude'] as num?)?.toDouble(),
      formState: d['formState'] as String? ?? 'Colorado',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'agentId': agentId,
        'agentName': agentName,
        'agentEmail': agentEmail,
        'brokerageName': brokerageName,
        'buyerName': buyerName,
        'buyerEmail': buyerEmail,
        'propertyScope': propertyScope,
        'compensation': compensation,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': _statusToString(status),
        'createdAt': Timestamp.fromDate(createdAt),
        if (signedAt != null) 'signedAt': Timestamp.fromDate(signedAt!),
        if (localPdfPath != null) 'localPdfPath': localPdfPath,
        if (storagePdfPath != null) 'storagePdfPath': storagePdfPath,
        if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
        if (signingLatitude != null) 'signingLatitude': signingLatitude,
        if (signingLongitude != null) 'signingLongitude': signingLongitude,
        'formState': formState,
      };

  AgreementModel copyWith({
    AgreementStatus? status,
    String? localPdfPath,
    String? storagePdfPath,
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
        storagePdfPath: storagePdfPath ?? this.storagePdfPath,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        signingLatitude: signingLatitude,
        signingLongitude: signingLongitude,
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
