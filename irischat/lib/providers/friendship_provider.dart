import 'package:flutter/material.dart';

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
  List<UserModel> _searchUsers = [];
  List<UserModel> get searchUsers => _searchUsers;
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // =========================
  // SEARCH USER
  // =========================

  Future<void> searchByEmail({
    required String keyword,

    required String currentUid,
  }) async {
    _isSearching = true;

    notifyListeners();

    try {
      _searchUsers = await _service.searchUsersByEmail(
        keyword: keyword,
        currentUid: currentUid,
      );
    } catch (e) {
      print(
        '[FriendshipProvider] '
        'search error: $e',
      );
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // =========================
  // SEND REQUEST
  // =========================

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

  // =========================
  // LISTEN RECEIVED REQUESTS
  // =========================

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

  // =========================
  // LISTEN SENT REQUESTS
  // =========================
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
}
