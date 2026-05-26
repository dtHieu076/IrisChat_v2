import 'dart:async'; // 1. THÊM IMPORT NÀY ĐỂ QUẢN LÝ STREAM
import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import '../models/friend_model.dart';
import '../models/friendship_model.dart';
import '../models/user_model.dart';
import '../services/friendship_service.dart';

class FriendshipProvider extends ChangeNotifier {
  final FriendshipService _service = FriendshipService();

  // Khai báo các Subscription để hủy khi không dùng, tránh trùng lặp Listener
  StreamSubscription? _receivedSub;
  StreamSubscription? _sentSub;
  StreamSubscription? _friendsSub;

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
    _searchedUser = null;
    notifyListeners();

    try {
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

  // SỬA HÀM NÀY: Xóa bỏ việc add thủ công, xóa luôn hàm sendRequest bị trùng lặp phía dưới
  Future<void> sendFriendRequest({
    required String senderId,
    required String senderEmail,
    required String receiverId,
  }) async {
    try {
      await _service.sendFriendRequest(
        senderId: senderId,
        senderEmail: senderEmail,
        receiverId: receiverId,
      );

      // Khung tìm kiếm nên ẩn đi sau khi gửi thành công cho đẹp giao diện
      clearSearch();
      print('[FriendshipProvider] Gửi lời mời thành công, chờ Stream tự cập nhật');
    } catch (e) {
      print('[FriendshipProvider] send request error: $e');
      rethrow;
    }
  }

  // LISTEN RECEIVED REQUESTS
  void listenReceivedRequests(String currentUid) {
    _receivedSub?.cancel(); // Hủy cái cũ nếu có trước khi lắng nghe cái mới
    _receivedSub = _service.listenReceivedRequests(currentUid).listen((requests) {
      _receivedRequests = requests;
      notifyListeners();
      print('[FriendshipProvider] received requests: ${requests.length}');
    });
  }

  // LISTEN SENT REQUESTS
  void listenSentRequests(String currentUid) {
    _sentSub?.cancel(); // Hủy cái cũ nếu có trước khi lắng nghe cái mới
    _sentSub = _service.listenSentRequests(currentUid).listen((requests) {
      _sentRequests = requests; // Stream tự nạp từ Firebase về đầy đủ
      notifyListeners();        // Vẽ lại UI chuẩn chỉnh không lo trùng lặp
      print('[FriendshipProvider] sent requests updated: ${requests.length}');
    });
  }

  // ACCEPT REQUEST
  Future<void> acceptRequest({
    required FriendshipModel request,
    required String currentUid,
    required String friendName,
    required String friendAvatar,
  }) async {
    try {
      await _service.acceptFriendRequest(request: request);
      print('[FriendshipProvider] Chấp nhận kết bạn thành công');

      final friendUid = (request.senderId == currentUid)
          ? request.receiverId
          : request.senderId;

      final room = ChatRoomModel.create1to1(
        currentUid: currentUid,
        friendUid: friendUid,
        friendName: friendName,
        friendAvatar: friendAvatar,
      );

      await _service.create1to1ChatRoom(room: room);
      print('[FriendshipProvider] Khởi tạo phòng chat 1-1 thành công');
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

  // LISTEN FRIENDS
  void listenFriends(String currentUid) {
    _friendsSub?.cancel(); // Hủy cái cũ trước khi lắng nghe cái mới
    _friendsSub = _service.listenFriendsList(currentUid).listen((friends) {
      _friendsList = friends;
      notifyListeners();
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
    } catch (e) {
      debugPrint("[FriendshipProvider] Error toggleBlock: $e");
    }
  }

  Stream<FriendModel?> listenFriendshipState(String uid1, String uid2) {
    return _service.listenFriendship(uid1, uid2);
  }

  // ĐỪNG QUÊN GIẢI PHÓNG BỘ NHỚ KHI PROVIDER BỊ HUỶ
  @override
  void dispose() {
    _receivedSub?.cancel();
    _sentSub?.cancel();
    _friendsSub?.cancel();
    super.dispose();
  }
}