import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'agreement_model.dart';

class AgreementRepository {
  AgreementRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('agreements');

  Stream<List<AgreementModel>> watchForAgent(String agentId) {
    return _col
        .where('agentId', isEqualTo: agentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AgreementModel.fromFirestore).toList());
  }

  Future<AgreementModel> create({
    required String agentId,
    required String agentName,
    required String agentEmail,
    required String brokerageName,
    required String buyerName,
    required String buyerEmail,
    required String propertyScope,
    required String compensation,
    required DateTime startDate,
    required DateTime endDate,
    String formState = 'Colorado',
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final model = AgreementModel(
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
      status: AgreementStatus.draft,
      createdAt: now,
      formState: formState,
    );
    await _col.doc(id).set(model.toFirestore());
    return model;
  }

  Future<AgreementModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AgreementModel.fromFirestore(doc);
  }

  Future<void> update(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);
}

final agreementRepositoryProvider = Provider<AgreementRepository>(
  (ref) => AgreementRepository(FirebaseFirestore.instance),
);

final agentAgreementsProvider = StreamProvider<List<AgreementModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(agreementRepositoryProvider).watchForAgent(uid);
});
