import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// Supported states — add more as forms are sourced
const List<String> kSupportedStates = ['Colorado'];
