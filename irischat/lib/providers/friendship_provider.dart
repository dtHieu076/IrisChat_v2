import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/friend_model.dart';

import '../models/friendship_model.dart';
import '../models/user_model.dart';

import '../services/friendship_service.dart';

class FriendshipProvider extends ChangeNotifier {
  final FriendshipService _service = FriendshipService();

  // =========================
  // FRIENDS LIST
  // =========================
  List<UserModel> _friendsList = [];
  List<UserModel> get friendsList => _friendsList;

  // =========================
  // SENT REQUESTS
  // =========================
  List<FriendshipModel> _sentRequests = [];
  List<FriendshipModel> get sentRequests => _sentRequests;

  // =========================
  // RECEIVED REQUESTS
  // =========================
  List<FriendshipModel> _receivedRequests = [];
  List<FriendshipModel> get receivedRequests => _receivedRequests;
  bool get hasNotification => _receivedRequests.isNotEmpty;

  // =========================
  // SEARCH
  // =========================
  UserModel? _searchedUser;
  UserModel? get searchedUser => _searchedUser;
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // SEARCH USER
  Future<void> searchByEmail({
    required String keyword,
    required String currentUid,
  }) async {
    _isSearching = true;
    _searchedUser = null; // Reset kết quả cũ
    notifyListeners();

    try {
      // Vì hàm _service.searchUsersByEmail của bạn trả về List, ta lấy phần tử đầu tiên
      final results = await _service.searchUsersByEmail(
        keyword: keyword,
        currentUid: currentUid,
      );

      if (results.isNotEmpty) {
        _searchedUser = results.first;
      }
    } catch (e) {
      print('[FriendshipProvider] search error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchedUser = null;
    notifyListeners();
  }

  Future<void> sendFriendRequest({
    required String senderId,
    required String senderEmail,
    required String receiverId, // Sửa từ receiverEmail thành receiverId
  }) async {
    try {
      // Không cần check _searchedUser nữa vì ta đã có thẳng receiverId từ UI truyền vào
      final request = await _service.sendFriendRequest(
        senderId: senderId,
        senderEmail: senderEmail,
        receiverId: receiverId,
      );

      _sentRequests.add(request);
      notifyListeners();

      print('[FriendshipProvider] request added local state');
    } catch (e) {
      print('[FriendshipProvider] send request error: $e');
      rethrow;
    }
  }

  // x ----------SEND REQUEST
  Future<void> sendRequest({
    required String senderId,

    required String senderEmail,

    required String receiverId,
  }) async {
    try {
      final request = await _service.sendFriendRequest(
        senderId: senderId,
        senderEmail: senderEmail,
        receiverId: receiverId,
      );

      _sentRequests.add(request);

      notifyListeners();

      print(
        '[FriendshipProvider] '
        'request added local state',
      );
    } catch (e) {
      print(
        '[FriendshipProvider] '
        'send request error: $e',
      );
    }
  }

  // LISTEN RECEIVED REQUESTS
  void listenReceivedRequests(String currentUid) {
    _service.listenReceivedRequests(currentUid).listen((requests) {
      _receivedRequests = requests;

      notifyListeners();

      print(
        '[FriendshipProvider] '
        'received requests: '
        '${requests.length}',
      );
    });
  }

  // LISTEN SENT REQUESTS
  void listenSentRequests(String currentUid) {
    _service.listenSentRequests(currentUid).listen((requests) {
      _sentRequests = requests; // Cập nhật danh sách lời mời đã gửi realtime
      notifyListeners(); // Báo cho UI vẽ lại trạng thái các nút bấm

      print('[FriendshipProvider] sent requests updated: ${requests.length}');
    });
  }

  // Thêm vào class FriendshipProvider
  Future<void> acceptRequest(FriendshipModel request) async {
    try {
      await _service.acceptFriendRequest(request: request);
      print('[FriendshipProvider] Chấp nhận kết bạn thành công');
    } catch (e) {
      print('[FriendshipProvider] Lỗi acceptRequest: $e');
    }
  }

  Future<void> rejectRequest(String requestId) async {
    try {
      await _service.rejectFriendRequest(requestId);
      print('[FriendshipProvider] Từ chối kết bạn thành công');
    } catch (e) {
      print('[FriendshipProvider] Lỗi rejectRequest: $e');
    }
  }

  // Hủy lời mời đã gửi
  Future<void> cancelRequest(String requestId) async {
    try {
      await _service.updateRequestStatus(
        requestId: requestId,
        status: 'cancelled',
      );
    } catch (e) {
      print('[FriendshipProvider] cancelRequest error: $e');
    }
  }

  // Lắng nghe danh sách bạn bè từ Service
  void listenFriends(String currentUid) {
    _service.listenFriendsList(currentUid).listen((friends) {
      _friendsList = friends;
      notifyListeners(); // Thông báo cho UI vẽ lại giao diện
    });
  }

  // Create group chat room
  Future<ChatRoomModel> createGroupChatRoom({
    required String currentUid,
    required String groupName,
    required List<String> friendIds,
  }) async {
    final participants = [currentUid, ...friendIds];

    final room = ChatRoomModel(
      roomId: DateTime.now().millisecondsSinceEpoch.toString(),
      roomName: groupName,
      roomAvatar: '',
      isGroup: true,
      participants: participants,
      createdBy: currentUid,
      lastTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await _service.createGroupChatRoom(room: room);
    return room;
  }

  // REMOVE FRIEND
  Future<void> removeFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      await _service.deleteFriend(currentUid: currentUid, friendUid: friendUid);
      print('[FriendshipProvider] Xóa bạn thành công');
      // Lưu ý: Không cần gọi notifyListeners() hay xóa thủ công khỏi _friendsList
      // vì hàm listenFriends() dùng Stream sẽ tự động nhận diện thay đổi từ Firebase và cập nhật lại list!
    } catch (e) {
      print('[FriendshipProvider] Lỗi removeFriend: $e');
    }
  }

  Future<void> toggleBlock({
    required String currentUid,
    required String friendUid,
    required bool shouldBlock,
  }) async {
    try {
      await _service.toggleBlockUser(
        currentUid: currentUid,
        friendUid: friendUid,
        shouldBlock: shouldBlock,
      );
      // Thông thường Firebase Realtime Stream sẽ tự cập nhật UI, không cần notifyListeners() thủ công ở đây
    } catch (e) {
      debugPrint("[FriendshipProvider] Error toggleBlock: $e");
    }
  }

  // 2. Phương thức lắng nghe trạng thái dữ liệu Block Realtime phục vụ ẩn/hiện Chat Input
  Stream<FriendModel?> listenFriendshipState(String uid1, String uid2) {
    return _service.listenFriendship(uid1, uid2);
  }
}
