import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final Map<String, UserModel> _cache = {};

  UserModel? getUserById(String uid) => _cache[uid];

  // --- HÀM MỚI SỬA ĐỔI: Lấy String trực tiếp đồng bộ từ Cache ---
  String getDisplayNameFromCache(String uid) {
    if (_cache.containsKey(uid)) {
      return _cache[uid]!.displayName;
    }

    // Nếu chưa có trong cache, kích hoạt hàm tải ngầm dữ liệu cho lần sau
    _preloadUser(uid);

    return 'Loading...'; // Trả về text tạm thời, không làm treo UI
  }

  // Hàm chạy ngầm tải dữ liệu từ server và nạp vào cache
  Future<void> _preloadUser(String uid) async {
    try {
      // Tránh việc gọi API trùng lặp nếu đang có request xử lý (tùy chọn)
      final user = await _userService.getUserById(uid);
      if (user != null) {
        _cache[uid] = user;
        notifyListeners(); // Báo hiệu để UI (Consumer/watch) tự động vẽ lại tên thật
      }
    } catch (e) {
      debugPrint('[UserProvider] _preloadUser error: $e');
    }
  }

  Future<UserModel?> fetchUserById(String uid) async {
    try {
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

  // Hàm cũ giữ nguyên để không lỗi các nơi khác đang await nó
  Future<String> getDisplayName(String uid) async {
    if (_cache.containsKey(uid)) {
      return _cache[uid]!.displayName;
    }

    try {
      final user = await fetchUserById(uid);
      return user?.displayName ?? 'Unknown';
    } catch (e) {
      debugPrint('[UserProvider] getDisplayName error: $e');
      return 'Unknown';
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
