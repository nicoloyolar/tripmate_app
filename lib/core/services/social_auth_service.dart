import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum SocialProvider { google, facebook, apple }

class SocialAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await _upsertUserProfile(userCredential, 'google');
    return userCredential;
  }

  static Future<UserCredential?> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
    );

    if (result.status != LoginStatus.success || result.accessToken == null) {
      return null;
    }

    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await _upsertUserProfile(userCredential, 'facebook');
    return userCredential;
  }

  static Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

    final userCredential = await _auth.signInWithCredential(oauthCredential);

    final displayName = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

    if (displayName.isNotEmpty) {
      await userCredential.user?.updateDisplayName(displayName);
    }

    await _upsertUserProfile(
      userCredential,
      'apple',
      fallbackName: displayName,
    );
    return userCredential;
  }

  static Future<void> _upsertUserProfile(
    UserCredential userCredential,
    String provider, {
    String? fallbackName,
  }) async {
    final user = userCredential.user;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final now = FieldValue.serverTimestamp();

    if (snapshot.exists) {
      await userRef.set({
        'email': user.email,
        'authProvider': provider,
        'lastLoginAt': now,
      }, SetOptions(merge: true));
    } else {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'nombre': user.displayName ?? fallbackName ?? 'Usuario TripMate',
        'photoUrl': user.photoURL,
        'authProvider': provider,
        'isVerified': false,
        'isLicenseVerified': false,
        'rol': 'user',
        'lastLoginAt': now,
        'telefono': user.phoneNumber ?? '',
        'bio': '',
        'vehiculos': [],
        'perfilCompleto': false,
        'createdAt': now,
      });
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
