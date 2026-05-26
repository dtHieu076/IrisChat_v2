import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:irischat/services/user_service.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
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

  StreamSubscription<DatabaseEvent>? _currentUserSubscription;

  void _listenAuthState() {
    _authService.authStateChanges.listen((firebaseUser) async {
      _user = firebaseUser;
      // Hủy listener cũ
      await _currentUserSubscription?.cancel();

      if (firebaseUser == null) {
        _userModel = null;
        notifyListeners();
      } else {
        // Set online presence
        _userService.setUserPresence(firebaseUser.uid);

        // Lắng nghe realtime user hiện tại
        _currentUserSubscription = _db
            .child('users/${firebaseUser.uid}')
            .onValue
            .listen((event) {
              if (event.snapshot.exists) {
                final map = Map<String, dynamic>.from(
                  event.snapshot.value as Map,
                );
                _userModel = UserModel.fromMap(map);
                notifyListeners();
              }
            });
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
    required String displayName,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      // Chuyển tiếp toàn bộ data (bao gồm cả bytes ảnh) xuống AuthService xử lý xuôi dòng
      await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
        imageBytes: imageBytes,
        fileName: fileName,
      );

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
    try {
      // Nếu user đang đăng nhập, chuyển họ sang Offline trên DB trước khi ngắt session
      if (_user != null) {
        await _userService.setOfflineManually(_user!.uid);
      }
    } catch (e) {
      debugPrint('[AuthProvider] Lỗi set offline khi logout: $e');
    }

    // Tiến hành đăng xuất khỏi Firebase Auth
    await _authService.logout();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
