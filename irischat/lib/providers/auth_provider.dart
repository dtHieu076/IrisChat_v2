import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _listenAuthState();
  }

  void _listenAuthState() {
    _authService.authStateChanges.listen((firebaseUser) async {
      _user = firebaseUser;

      if (firebaseUser == null) {
        _userModel = null;
        notifyListeners();
      } else {
        // Mỗi khi trạng thái Auth thay đổi (Login/Register thành công)
        // Lập tức kéo dữ liệu Profile từ database về gán vào State
        await refreshCurrentUser(firebaseUser.uid);
      }
    });
  }

  Future<void> refreshCurrentUser(String uid) async {
    try {
      final snapshot = await _db.child('users/$uid').get();
      if (snapshot.exists) {
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        _userModel = UserModel.fromMap(map);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Lỗi đồng bộ dữ liệu người dùng: $e');
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      _setLoading(true);
      _error = null;
      await _authService.login(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _error = null;
      await _authService.register(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
