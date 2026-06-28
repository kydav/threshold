import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialSignInResult {
  const SocialSignInResult({
    required this.isNewUser,
    required this.displayName,
    required this.email,
  });
  final bool isNewUser;
  final String displayName;
  final String email;
}

class AuthService {
  AuthService(this._auth);
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user!.updateDisplayName(displayName);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<SocialSignInResult> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return SocialSignInResult(
      isNewUser: cred.additionalUserInfo?.isNewUser ?? false,
      displayName: googleUser.displayName ?? '',
      email: googleUser.email,
    );
  }

  Future<SocialSignInResult> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final cred = await _auth.signInWithCredential(oauthCredential);

    // Apple only sends name on first sign-in; store it on the Firebase user.
    final givenName = appleCredential.givenName ?? '';
    final familyName = appleCredential.familyName ?? '';
    final displayName = '$givenName $familyName'.trim();
    if (displayName.isNotEmpty && cred.user?.displayName == null) {
      await cred.user!.updateDisplayName(displayName);
    }

    final email =
        appleCredential.email ??
        cred.user?.email ??
        '';

    return SocialSignInResult(
      isNewUser: cred.additionalUserInfo?.isNewUser ?? false,
      displayName: cred.user?.displayName ?? displayName,
      email: email,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);
}

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(FirebaseAuth.instance));

final currentUserProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());
