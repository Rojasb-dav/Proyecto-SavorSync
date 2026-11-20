import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_model.dart';
import '../utils/token_storage.dart';

class AuthResult {
  final String token;
  final UserModel user;
  AuthResult({required this.token, required this.user});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TokenStorage _tokenStorage = TokenStorage();

  Future<AuthResult> login(String email, String password) async {
    final creds = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = creds.user!.uid;
    final idToken = await creds.user!.getIdToken() ?? uid;

    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final user = UserModel.fromJson({'id': uid, 'email': email, ...data});

    await _tokenStorage.saveToken(idToken);
    await _tokenStorage.saveUserId(uid);

    return AuthResult(token: idToken, user: user);
  }

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
    String role = 'foodie',
  }) async {
    final creds = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = creds.user!.uid;
    final idToken = await creds.user!.getIdToken() ?? uid;

    final userData = {
      'id': uid,
      'email': email.trim(),
      'username': username.trim(),
      'fullName': fullName?.trim(),
      'role': role,
      'avatarUrl': null,
      'bio': '',
      'followersCount': 0,
      'followingCount': 0,
      'postsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(uid).set(userData);

    final user = UserModel.fromJson(userData);
    await _tokenStorage.saveToken(idToken);
    await _tokenStorage.saveUserId(uid);

    return AuthResult(token: idToken, user: user);
  }

  Future<AuthResult> signInWithGoogle() async {
    UserCredential userCreds;

    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      userCreds = await _auth.signInWithPopup(googleProvider);
    } else {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Inicio de sesión cancelado.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      userCreds = await _auth.signInWithCredential(credential);
    }

    final userObj = userCreds.user;
    if (userObj == null) {
      throw Exception('No se pudo obtener la información de Google.');
    }

    final uid = userObj.uid;
    final email = userObj.email ?? 'foodie@savorsync.com';
    final displayName = userObj.displayName ?? 'Foodie';
    final photoUrl = userObj.photoURL;
    final idToken = await userObj.getIdToken() ?? uid;

    final userDocRef = _firestore.collection('users').doc(uid);
    final doc = await userDocRef.get();

    UserModel user;
    if (doc.exists) {
      final data = doc.data() ?? {};
      user = UserModel.fromJson({'id': uid, 'email': email, ...data});
    } else {
      final userData = {
        'id': uid,
        'email': email,
        'username': email.split('@').first,
        'fullName': displayName,
        'role': 'foodie',
        'avatarUrl': photoUrl,
        'bio': 'Foodie apasionado en Bogotá',
        'followersCount': 0,
        'followingCount': 0,
        'postsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await userDocRef.set(userData);
      user = UserModel.fromJson(userData);
    }

    await _tokenStorage.saveToken(idToken);
    await _tokenStorage.saveUserId(uid);

    return AuthResult(token: idToken, user: user);
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _tokenStorage.clear();
  }

  Future<UserModel> fetchUserById(String id) async {
    final doc = await _firestore.collection('users').doc(id).get();
    final data = doc.data() ?? {};
    return UserModel.fromJson({'id': id, ...data});
  }
}
