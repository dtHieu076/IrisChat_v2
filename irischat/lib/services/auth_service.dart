import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // =========================
  // REGISTER
  // =========================

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      final userModel = UserModel(
        uid: user.uid,

        email: email,

        displayName: email.split('@').first,

        avatarUrl: '',

        isOnline: true,

        lastSeen: DateTime.now(),
      );

      await _db.child('users/${user.uid}').set(userModel.toMap());

      print('[AuthService] created user profile: ${user.uid}');
    }

    return credential;
  }

  // =========================
  // LOGIN
  // =========================

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user?.uid;

    if (uid != null) {
      await _db.child('users/$uid').update({
        'isOnline': true,

        'lastSeen': DateTime.now().toIso8601String(),
      });

      print('[AuthService] online: $uid');
    }

    return credential;
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
  final uid = _auth.currentUser?.uid;

  if (uid != null) {
    _db.child('users/$uid').update({
      'isOnline': false,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  await _auth.signOut();
}
}
