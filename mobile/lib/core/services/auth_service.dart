import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final user = UserModel.fromJson({'id': uid, ...data});

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
