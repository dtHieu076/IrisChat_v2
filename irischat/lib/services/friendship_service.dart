import 'package:firebase_database/firebase_database.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/friend_model.dart';
import 'package:irischat/models/friendship_model.dart';
import 'dart:async'; // Nhớ thêm import này ở đầu file nếu chưa có

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
      blockedBy: "",
      isFavorite: [],
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

  Future<void> createGroupChatRoom({required ChatRoomModel room}) async {
    try {
      await _db.child('chat_rooms').child(room.roomId).set(room.toMap());
      print(
        '[FriendshipService] Tạo phòng chat nhóm thành công: ${room.roomId}',
      );
    } catch (e) {
      print('[FriendshipService] Lỗi createGroupChatRoom: $e');
      rethrow;
    }
  }

  // =========================
  // DELETE FRIEND (HỦY KẾT BẠN)
  // =========================
  Future<void> deleteFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      // 1. Lấy toàn bộ danh sách friends để tìm ID của mối quan hệ
      final snapshot = await _db.child('friends').get();

      if (!snapshot.exists) return;

      final data = Map<dynamic, dynamic>.from(snapshot.value as dynamic);
      String? targetFriendshipId;

      // 2. Duyệt qua để tìm bản ghi chứa cả 2 ID (dù ai là user1 hay user2)
      data.forEach((key, value) {
        final map = Map<String, dynamic>.from(value);
        final user1Id = map['user1Id'];
        final user2Id = map['user2Id'];

        final isMatch1 = user1Id == currentUid && user2Id == friendUid;
        final isMatch2 = user1Id == friendUid && user2Id == currentUid;

        if (isMatch1 || isMatch2) {
          targetFriendshipId = key; // Lấy key của bản ghi cần xóa
        }
      });

      // 3. Nếu tìm thấy thì tiến hành xóa khỏi database
      if (targetFriendshipId != null) {
        await _db.child('friends').child(targetFriendshipId!).remove();
        print(
          '[FriendshipService] Đã xóa bản ghi tình bạn: $targetFriendshipId',
        );
      } else {
        print('[FriendshipService] Không tìm thấy dữ liệu bạn bè để xóa');
      }
    } catch (e) {
      print('[FriendshipService] Lỗi deleteFriend: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // BLOCK / UNBLOCK USER
  // ===========================================================================

  // Hàm phụ trợ: Tìm kiếm key (FriendshipId) trong node 'friends' dựa vào 2 UID
  Future<String?> _getFriendshipId(String uid1, String uid2) async {
    final snapshot = await _db.child('friends').get();
    if (!snapshot.exists) return null;

    final data = Map<dynamic, dynamic>.from(snapshot.value as dynamic);
    String? foundId;

    data.forEach((key, value) {
      final map = Map<String, dynamic>.from(value);
      final u1 = map['user1Id'];
      final u2 = map['user2Id'];

      if ((u1 == uid1 && u2 == uid2) || (u1 == uid2 && u2 == uid1)) {
        foundId = key.toString();
      }
    });

    return foundId;
  }

  // Hàm cập nhật trạng thái block lên Firebase (bảng 'friends')
  Future<void> toggleBlockUser({
    required String currentUid,
    required String friendUid,
    required bool shouldBlock,
  }) async {
    try {
      final friendshipId = await _getFriendshipId(currentUid, friendUid);
      if (friendshipId == null) {
        print('[FriendshipService] Không tìm thấy bản ghi bạn bè để block');
        return;
      }

      // Nếu block -> lưu UID người thực hiện block. Nếu unblock -> trả về chuỗi rỗng ""
      final String blockedValue = shouldBlock ? currentUid : "";

      await _db.child('friends').child(friendshipId).update({
        'blockedBy': blockedValue,
      });
      print(
        '[FriendshipService] Toggle block thành công. Trạng thái: $blockedValue',
      );
    } catch (e) {
      print('[FriendshipService] Lỗi toggleBlockUser: $e');
      rethrow;
    }
  }

  // Lắng nghe realtime ĐÚNG duy nhất một bản ghi cụ thể bằng cách tối ưu Stream
  Stream<FriendModel?> listenFriendship(String uid1, String uid2) {
    // Tạo một StreamController tự chế để kiểm soát luồng dữ liệu chính xác hơn

    final StreamController<FriendModel?> controller =
        StreamController<FriendModel?>.broadcast();
    StreamSubscription? subscription;

    // Bước 1: Lấy toàn bộ danh sách một lần duy nhất để tìm ra ID chính xác
    _db
        .child('friends')
        .get()
        .then((snapshot) {
          if (!snapshot.exists || snapshot.value == null) {
            controller.add(null);
            return;
          }

          final data = Map<dynamic, dynamic>.from(snapshot.value as dynamic);
          String? targetId;

          data.forEach((key, value) {
            final map = Map<String, dynamic>.from(value);
            final u1 = map['user1Id'];
            final u2 = map['user2Id'];
            if ((u1 == uid1 && u2 == uid2) || (u1 == uid2 && u2 == uid1)) {
              targetId = key.toString();
            }
          });

          if (targetId == null) {
            controller.add(null);
            return;
          }

          // Bước 2: Chỉ lắng nghe thay đổi duy nhất tại Node con đó (Realtime tuyệt đối)
          subscription = _db.child('friends').child(targetId!).onValue.listen((
            event,
          ) {
            final childData = event.snapshot.value;
            if (childData == null) {
              controller.add(null);
            } else {
              final map = Map<String, dynamic>.from(childData as dynamic);
              controller.add(FriendModel.fromMap(map));
            }
          });
        })
        .catchError((error) {
          print('[FriendshipService] Lỗi listenFriendship Stream: $error');
          controller.addError(error);
        });

    // Đóng cổng lắng nghe khi Widget bị hủy (Tránh rò rỉ bộ nhớ - Memory Leak)
    controller.onCancel = () {
      subscription?.cancel();
    };

    return controller.stream;
  }

  // ===========================================================================
  // CREATE 1-1 CHAT ROOM
  // ===========================================================================
  Future<void> create1to1ChatRoom({required ChatRoomModel room}) async {
    try {
      // Lưu phòng chat vào node 'chat_rooms' với key là roomId
      await _db.child('chat_rooms').child(room.roomId).set(room.toMap());

      print(
        '[FriendshipService] Tạo phòng chat 1-1 thành công: ${room.roomId}',
      );
    } catch (e) {
      print('[FriendshipService] Lỗi create1to1ChatRoom: $e');
      rethrow;
    }
  }
}
