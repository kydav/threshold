import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  AuthService(this._auth, this._firestore);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Future<void> signUp({
    required String email,
    required String password,
    required String agentName,
    required String brokerageName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user!.updateDisplayName(agentName);
    await _firestore.collection('agents').doc(cred.user!.uid).set({
      'agentName': agentName,
      'agentEmail': email,
      'brokerageName': brokerageName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final currentUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final agentProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  final doc = await FirebaseFirestore.instance
      .collection('agents')
      .doc(user.uid)
      .get();
  return doc.data();
});
