import 'package:firebase_database/firebase_database.dart';
import 'package:irischat/models/friend_model.dart';
import 'package:irischat/models/friendship_model.dart';

import '../models/user_model.dart';

class FriendshipService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // =========================
  // SEARCH USER
  // =========================

  Future<List<UserModel>> searchUsersByEmail({
    required String keyword,
    required String currentUid,
  }) async {
    print('[FriendshipService] searchUsersByEmail: $keyword');

    final snapshot = await _db.child('users').get();

    print('[FriendshipService] users exists: ${snapshot.exists}');

    if (!snapshot.exists) {
      return [];
    }

    final data = Map<dynamic, dynamic>.from(snapshot.value as dynamic);

    final List<UserModel> users = [];

    data.forEach((key, value) {
      final map = Map<String, dynamic>.from(value);

      final user = UserModel.fromMap(map);

      print('[FriendshipService] checking: ${user.email}');

      final isMatch = user.email.toLowerCase().contains(keyword.toLowerCase());

      final isNotCurrentUser = user.uid != currentUid;

      if (isMatch && isNotCurrentUser) {
        users.add(user);

        print('[FriendshipService] matched: ${user.email}');
      }
    });

    print('[FriendshipService] result count: ${users.length}');

    return users;
  }
  // =========================
  // SEND REQUEST
  // =========================

  Future<FriendshipModel> sendFriendRequest({
    required String senderId,

    required String senderEmail,

    required String receiverId,
  }) async {
    final requestRef = _db.child('friend_requests').push();

    final request = FriendshipModel(
      requestId: requestRef.key ?? '',

      senderId: senderId,

      senderEmail: senderEmail,

      receiverId: receiverId,

      status: 'pending',

      createdAt: DateTime.now(),
    );

    await requestRef.set(request.toMap());

    return request;
  }

  // =========================
  // LISTEN REQUESTS REALTIME
  // =========================
  Stream<List<FriendshipModel>> listenReceivedRequests(String currentUid) {
    return _db.child('friend_requests').onValue.map((event) {
      final data = event.snapshot.value;

      if (data == null) {
        return [];
      }

      final map = Map<dynamic, dynamic>.from(data as dynamic);

      final List<FriendshipModel> requests = [];

      map.forEach((key, value) {
        final request = FriendshipModel.fromMap(
          Map<dynamic, dynamic>.from(value),
        );

        final isReceiver = request.receiverId == currentUid;

        final isPending = request.status == 'pending';

        if (isReceiver && isPending) {
          requests.add(request);
        }
      });

      return requests;
    });
  }

  // Thêm hàm này vào trong class FriendshipService của bạn
  Stream<List<FriendshipModel>> listenSentRequests(String currentUid) {
    return _db.child('friend_requests').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final map = Map<dynamic, dynamic>.from(data as dynamic);
      final List<FriendshipModel> requests = [];

      map.forEach((key, value) {
        final request = FriendshipModel.fromMap(
          Map<dynamic, dynamic>.from(value),
        );

        // Lọc các request do chính mình gửi đi và đang ở trạng thái pending
        final isSender = request.senderId == currentUid;
        final isPending = request.status == 'pending';

        if (isSender && isPending) {
          requests.add(request);
        }
      });

      return requests;
    });
  }

  // =========================
  // ACCEPT/REJECT REQUEST
  // =========================
  Future<void> acceptFriendRequest({required FriendshipModel request}) async {
    // 1. Cập nhật trạng thái của lời mời thành 'accepted'
    await _db.child('friend_requests').child(request.requestId).update({
      'status': 'accepted',
    });

    // 2. Tạo một ID ngẫu nhiên cho mối quan hệ bạn bè mới
    final friendRef = _db.child('friends').push();

    final newFriendship = FriendModel(
      friendshipId: friendRef.key ?? '',
      user1Id: request.senderId, // ID người gửi lời mời
      user2Id: request.receiverId, // ID người nhận (chính là người bấm đồng ý)
      since: DateTime.now(),
      isBlocked: false,
      isFavorite: false,
    );

    // 3. Ghi vào database bảng 'friends'
    await friendRef.set(newFriendship.toMap());
  }

  //=========================
  // REJECT FRIEND REQUEST
  //=========================
  Future<void> rejectFriendRequest(String requestId) async {
    await _db.child('friend_requests').child(requestId).update({
      'status': 'rejected',
    });
  }

  // Cập nhật trạng thái lời mời chung (Từ chối hoặc Hủy yêu cầu)
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    await _db.child('friend_requests').child(requestId).update({
      'status': status,
    });
  }

  // Lắng nghe danh sách bạn bè thời gian thực
  Stream<List<UserModel>> listenFriendsList(String currentUid) {
    return _db.child('friends').onValue.asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return [];

      final map = Map<dynamic, dynamic>.from(data as dynamic);
      final List<String> friendIds = [];

      // Bước 1: Lọc ra tất cả Uid của bạn bè từ bảng 'friends'
      map.forEach((key, value) {
        final friendData = Map<String, dynamic>.from(value);

        final user1Id = friendData['user1Id'];
        final user2Id = friendData['user2Id'];

        if (user1Id == currentUid) {
          friendIds.add(user2Id); // Nếu mình là user1, thì bạn mình là user2
        } else if (user2Id == currentUid) {
          friendIds.add(user1Id); // Nếu mình là user2, thì bạn mình là user1
        }
      });

      if (friendIds.isEmpty) return [];

      // Bước 2: Lấy thông tin chi tiết của từng Uid từ bảng 'users'
      final List<UserModel> friendsDetails = [];
      for (String uid in friendIds) {
        final userSnapshot = await _db.child('users').child(uid).get();
        if (userSnapshot.exists) {
          final userMap = Map<String, dynamic>.from(
            userSnapshot.value as dynamic,
          );
          friendsDetails.add(UserModel.fromMap(userMap));
        }
      }

      return friendsDetails;
    });
  }
}
