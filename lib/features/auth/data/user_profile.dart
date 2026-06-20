import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threshold/core/services/data_service.dart';
import 'package:threshold/features/auth/data/auth_service.dart';

class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.brokerageName,
    required this.brokerageAddress,
    required this.brokerageCityStateZip,
    required this.phone,
    required this.state,
    required this.isMultiPersonFirm,
    this.isBuyerAgency = true,
    this.agreementsSent = 0,
  });

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String brokerageName;
  final String brokerageAddress;
  final String brokerageCityStateZip;
  final String phone;
  final String state; // e.g. 'Colorado'
  final bool isMultiPersonFirm;
  final bool isBuyerAgency;
  final int agreementsSent;

  String get fullName => '$firstName $lastName'.trim();

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>?;
    if (d == null) {
      throw StateError('Missing data for user profile: ${doc.id}');
    }
    return UserProfile(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      firstName: d['firstName'] as String? ?? '',
      lastName: d['lastName'] as String? ?? '',
      brokerageName: d['brokerageName'] as String? ?? '',
      brokerageAddress: d['brokerageAddress'] as String? ?? '',
      brokerageCityStateZip: d['brokerageCityStateZip'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      state: d['state'] as String? ?? '',
      isMultiPersonFirm: d['isMultiPersonFirm'] as bool? ?? false,
      isBuyerAgency: d['isBuyerAgency'] as bool? ?? true,
      agreementsSent: d['agreementsSent'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'brokerageName': brokerageName,
    'brokerageAddress': brokerageAddress,
    'brokerageCityStateZip': brokerageCityStateZip,
    'phone': phone,
    'state': state,
    'isMultiPersonFirm': isMultiPersonFirm,
    'isBuyerAgency': isBuyerAgency,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

final userProfileProvider = StateProvider<UserProfile?>((_) => null);

/// Watches auth state and auto-loads the Firestore profile into
/// [userProfileProvider] — handles app restarts where Firebase silently
/// restores an existing session without going through the login screen.
final profileLoaderProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<dynamic>>(currentUserProvider, (_, next) {
    final uid = next.valueOrNull?.uid as String?;
    if (uid != null) {
      ref
          .read(dataServiceProvider)
          .getUserProfile(uid)
          .then((profile) {
            ref.read(userProfileProvider.notifier).state = profile;
          })
          .catchError((e) {
            debugPrint('profileLoaderProvider: failed to load profile — $e');
          });
    } else if (next.hasValue) {
      // Definitive null = logged out; clear the cached profile.
      ref.read(userProfileProvider.notifier).state = null;
    }
  }, fireImmediately: true);
});

// Supported states — add more as forms are sourced
const List<String> kSupportedStates = ['Colorado', 'Oklahoma', 'Wisconsin'];
