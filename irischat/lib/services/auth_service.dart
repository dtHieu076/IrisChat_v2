import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import 'CloudinaryService.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

// ===========================================================================
  // REGISTER (Đã tích hợp Cloudinary)
  // ===========================================================================
  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
    Uint8List? imageBytes, // Nhận bytes ảnh từ tầng trên truyền xuống
    String? fileName,      // Nhận tên file ảnh
  }) async {

    // 1. Tạo tài khoản trên Firebase Authentication trước
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      String avatarUrl = '';

      // 2. Nếu người dùng có chọn ảnh, tiến hành up lên Cloudinary để lấy URL
      if (imageBytes != null && fileName != null) {
        try {
          final uploadedUrl = await _cloudinaryService.uploadFile(imageBytes, fileName);
          if (uploadedUrl != null) {
            avatarUrl = uploadedUrl; // Gán URL bảo mật từ Cloudinary trả về
          }
        } catch (e) {
          // Bạn có thể chọn throw e nếu muốn dừng đăng ký khi lỗi ảnh,
          // hoặc để avatarUrl = '' để user bổ sung ảnh sau ở ProfileTab.
        }
      }

      // 3. Tạo UserModel lưu đường dẫn avatarUrl mới từ Cloudinary
      final userModel = UserModel(
        uid: user.uid,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      // 4. Lưu dữ liệu hoàn chỉnh xuống Realtime Database
      await _db.child('users/${user.uid}').set(userModel.toMap());

      print('[AuthService] Đã tạo profile với avatar Cloudinary thành công: ${user.uid}');
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
