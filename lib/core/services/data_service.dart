import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threshold/features/auth/data/user_profile.dart';

class DataService {
  DataService(this._firestore);
  final FirebaseFirestore _firestore;

  Future<void> saveUserProfile(UserProfile profile) async {
    await _firestore.collection('users').doc(profile.uid).set(profile.toFirestore());
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _firestore.collection('users').doc(profile.uid).update(profile.toFirestore());
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }
}

final dataServiceProvider = Provider<DataService>((ref) => DataService(FirebaseFirestore.instance));
