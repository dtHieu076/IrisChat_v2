import 'dart:typed_data';

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

  String? getAvatarUrlFromCache(String uid) {
    if (_cache.containsKey(uid)) {
      return _cache[uid]!
          .avatarUrl; // Trả về URL ảnh (có thể là String rỗng hoặc null tùy Model)
    }

    // Nếu chưa có dữ liệu trong cache, gọi tải ngầm tương tự như lấy tên
    _preloadUser(uid);

    return null; // Trả về null để UI biết đường hiển thị chữ cái đại diện hoặc ảnh mặc định ban đầu
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

  Future<bool> uploadAndUpdateProfile({
    required String uid,
    required String displayName,
    Uint8List? imageBytes,
    String? fileName,
    required String currentAvatarUrl,
    VoidCallback? onSuccess,
  }) async {
    if (displayName.trim().isEmpty) return false;

    try {
      _isLoading = true;
      notifyListeners(); // Bật xoay vòng loading trên UI

      // 1. Giao phó toàn bộ nghiệp vụ xử lý ảnh & DB cho UserService lo liệu
      final finalAvatarUrl = await _userService.updateProfile(
        uid: uid,
        displayName: displayName,
        imageBytes: imageBytes,
        fileName: fileName,
        currentAvatarUrl: currentAvatarUrl,
      );

      // 2. Đồng bộ bộ nhớ Cache Local ngay lập tức với URL trả về từ Service
      if (_cache.containsKey(uid)) {
        _cache[uid] = _cache[uid]!.copyWith(
          displayName: displayName.trim(),
          avatarUrl: finalAvatarUrl,
        );
      }

      // 3. Chạy callback thành công (ví dụ: lệnh refresh từ AuthProvider ngoài UI)
      if (onSuccess != null) onSuccess();

      return true;
    } catch (e) {
      debugPrint('[UserProvider] Lỗi uploadAndUpdateProfile: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners(); // Tắt loading trên UI
    }
  }
}
