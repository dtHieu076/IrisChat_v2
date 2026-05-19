import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final Map<String, UserModel> _cache = {};

  UserModel? getUserById(String uid) => _cache[uid];

  Future<UserModel?> fetchUserById(String uid) async {
    try {
      // nếu đã có cache thì dùng luôn
      if (_cache.containsKey(uid)) {
        return _cache[uid];
      }

      final user = await _userService.getUserById(uid);

      if (user != null) {
        _cache[uid] = user;
        notifyListeners();
      }

      return user;
    } catch (e) {
      debugPrint('[UserProvider] fetchUserById error: $e');
      return null;
    }
  }

  Future<bool> updateProfile({
    required String uid,
    required String displayName,
    required String avatarUrl,
    VoidCallback? onSuccess,
  }) async {
    if (displayName.trim().isEmpty) return false;

    try {
      _isLoading = true;
      notifyListeners();

      await _userService.updateProfile(
        uid: uid,
        displayName: displayName.trim(),
        avatarUrl: avatarUrl.trim(),
      );

      if (onSuccess != null) {
        onSuccess();
      }

      return true;
    } catch (e) {
      debugPrint('[UserProvider] Lỗi cập nhật profile: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
