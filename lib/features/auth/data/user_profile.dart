// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class UserProfile {
//   UserProfile({
//     required this.uid,
//     required this.email,
//     required this.firstName,
//     required this.lastName,
//     required this.brokerageName,
//     this.phone,
//   });

//   final String uid;
//   final String email;
//   final String firstName;
//   final String lastName;
//   final String brokerageName;
//   final String? phone;

//   String get fullName => '$firstName $lastName'.trim();

//   factory UserProfile.fromFirestore(DocumentSnapshot doc) {
//     final d = doc.data() as Map<String, dynamic>;
//     return UserProfile(
//       uid: doc.id,
//       email: d['email'] as String? ?? '',
//       firstName: d['firstName'] as String? ?? '',
//       lastName: d['lastName'] as String? ?? '',
//       brokerageName: d['brokerageName'] as String? ?? '',
//       phone: d['phone'] as String?,
//     );
//   }

//   Map<String, dynamic> toFirestore() => {
//         'email': email,
//         'firstName': firstName,
//         'lastName': lastName,
//         'brokerageName': brokerageName,
//         if (phone != null) 'phone': phone,
//         'createdAt': FieldValue.serverTimestamp(),
//       };
// }

// final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
//   final user = FirebaseAuth.instance.currentUser;
//   if (user == null) return null;
//   final doc = await FirebaseFirestore.instance
//       .collection('users')
//       .doc(user.uid)
//       .get();
//   if (!doc.exists) return null;
//   return UserProfile.fromFirestore(doc);
// });
