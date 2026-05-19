import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';

class UserService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Cập nhật thông tin Profile (Chỉ cập nhật displayName và avatarUrl)
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String avatarUrl,
  }) async {
    final Map<String, dynamic> updates = {
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'lastSeen': DateTime.now().toIso8601String(),
    };

    // Chỉ cập nhật các trường cụ thể trong node của User đó
    await _db.child('users/$uid').update(updates);
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
}
