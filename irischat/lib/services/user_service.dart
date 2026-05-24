import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:irischat/services/CloudinaryService.dart';
import '../models/user_model.dart';

class UserService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // ===========================================================================
  // HÀM ĐÃ SỬA ĐỔI: Vừa tải ảnh lên Cloudinary (nếu có) vừa lưu thông tin vào Firebase
  // ===========================================================================
  Future<String> updateProfile({
    required String uid,
    required String displayName,
    Uint8List? imageBytes, // Nhận bytes ảnh mới (có thể null)
    String? fileName, // Tên file ảnh mới (có thể null)
    required String currentAvatarUrl, // Dùng lại URL cũ nếu không chọn ảnh mới
  }) async {
    String finalAvatarUrl = currentAvatarUrl;

    // 1. Tự động xử lý upload ảnh nếu tầng UI/Provider truyền file lên
    if (imageBytes != null && fileName != null) {
      final uploadedUrl = await _cloudinaryService.uploadFile(
        imageBytes,
        fileName,
      );
      if (uploadedUrl != null) {
        finalAvatarUrl = uploadedUrl;
      }
    }

    // 2. Chuẩn bị Map dữ liệu để cập nhật Firebase
    final Map<String, dynamic> updates = {
      'displayName': displayName.trim(),
      'avatarUrl': finalAvatarUrl,
      'lastSeen': DateTime.now().toIso8601String(),
    };

    // 3. Thực hiện cập nhật vào Realtime Database
    await _db.child('users/$uid').update(updates);

    // 4. Trả về finalAvatarUrl để Provider cập nhật vào Cache Local ngay lập tức
    return finalAvatarUrl;
  }

  // Lắng nghe thông tin một User cụ thể (Realtime phục vụ đồng bộ State)
  Stream<UserModel?> listenUserProfile(String uid) {
    return _db.child('users/$uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return UserModel.fromMap(Map<String, dynamic>.from(data as dynamic));
    });
  }

  Future<UserModel?> getUserById(String uid) async {
    final snapshot = await _db.child('users/$uid').get();

    if (!snapshot.exists) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return UserModel.fromMap(data);
  }

  // ===========================================================================
  // HÀM MỚI: Tự động cập nhật Online / Offline Realtime (Bao gồm cả khi crash/tắt app)
  // ===========================================================================
  void setUserPresence(String uid) {
    final connectedRef = FirebaseDatabase.instance.ref(".info/connected");
    final userStatusRef = _db.child('users/$uid');

    connectedRef.onValue.listen((event) async {
      final isConnected = event.snapshot.value as bool? ?? false;

      if (isConnected) {
        // 1. Thiết lập cấu hình tự động chạy KHI MẤT KẾT NỐI (App bị tắt, mất mạng)
        await userStatusRef.onDisconnect().update({
          'isOnline': false,
          'lastSeen':
              ServerValue.timestamp, // Sử dụng thời gian hệ thống của Firebase
        });

        // 2. Đồng thời cập nhật trạng thái ONLINE ngay khi vừa kết nối thành công
        await userStatusRef.update({
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
        });
      }
    });
  }

  // Cập nhật thủ công khi người dùng chủ động bấm Đăng xuất
  Future<void> setOfflineManually(String uid) async {
    await _db.child('users/$uid').update({
      'isOnline': false,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }
}
