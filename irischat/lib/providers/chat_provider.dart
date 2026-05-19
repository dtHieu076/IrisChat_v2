import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  // ===========================================================================
  // STATE - DANH SÁCH PHÒNG CHAT
  // ===========================================================================
  List<ChatRoomModel> _chatRooms = [];

  List<ChatRoomModel> get chatRooms => _chatRooms;

  // ===========================================================================
  // STATE - TIN NHẮN TRONG PHÒNG
  // ===========================================================================
  List<MessageModel> _messages = [];

  List<MessageModel> get messages => _messages;

  // ===========================================================================
  // STATE UI
  // ===========================================================================
  bool _isSending = false;

  bool get isSending => _isSending;

  // ===========================================================================
  // ROOM ĐANG MỞ
  // ===========================================================================
  String? _currentRoomId;

  String? get currentRoomId => _currentRoomId;

  // ===========================================================================
  // STREAM SUBSCRIPTIONS
  // ===========================================================================
  StreamSubscription<List<ChatRoomModel>>? _roomsSubscription;

  StreamSubscription<List<MessageModel>>? _messagesSubscription;

  // ===========================================================================
  // LẮNG NGHE DANH SÁCH PHÒNG CHAT
  // ===========================================================================
  void listenAllChatRooms(String currentUid) {
    _roomsSubscription?.cancel();

    _roomsSubscription = _chatService.listenChatRooms(currentUid).listen((
      rooms,
    ) {
      _chatRooms = rooms;

      notifyListeners();
    });
  }

  // ===========================================================================
  // VÀO PHÒNG CHAT
  // ===========================================================================
  void enterChatRoom({required String roomId, required String currentUid}) {
    _currentRoomId = roomId;

    // Reset unread count
    _chatService.clearUnreadCount(roomId, currentUid);

    // Hủy stream cũ
    _messagesSubscription?.cancel();

    // Lắng nghe tin nhắn realtime
    _messagesSubscription = _chatService.listenMessages(roomId).listen((
      msgList,
    ) async {
      _messages = msgList;

      notifyListeners();

      // Reset unread liên tục khi đang mở phòng
      _chatService.clearUnreadCount(roomId, currentUid);

      // =========================================================
      // ĐÁNH DẤU ĐÃ XEM
      // =========================================================

      for (final msg in msgList) {
        final isOtherMessage = msg.senderId != currentUid;

        final isUnread = msg.status != 'read';

        if (isOtherMessage && isUnread) {
          await _chatService.updateMessageStatus(
            roomId: roomId,
            messageId: msg.messageId,
            status: 'read',
          );
        }
      }
    });
  }

  // ===========================================================================
  // GỬI TIN NHẮN
  // ===========================================================================
  Future<void> sendTextMessage({
    required String roomId,
    required String currentUid,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    try {
      _isSending = true;

      notifyListeners();
      // LẤY THÔNG TIN ROOM
      final room = _chatRooms.firstWhere((room) => room.roomId == roomId);

      // TẠO MESSAGE ID
      final messageId =
          FirebaseDatabase.instance
              .ref()
              .child('messages')
              .child(roomId)
              .push()
              .key ??
          '';

      // TẠO MESSAGE MODEL
      final newMessage = MessageModel(
        messageId: messageId,
        senderId: currentUid,
        text: text.trim(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: 'sent',
      );

      // GỬI MESSAGE
      await _chatService.sendMessage(
        roomId: roomId,
        message: newMessage,
        participants: room.participants,
      );
    } catch (e) {
      debugPrint('Lỗi gửi tin nhắn: $e');
    } finally {
      _isSending = false;

      notifyListeners();
    }
  }

  // ===========================================================================
  // THOÁT PHÒNG CHAT
  // ===========================================================================
  void leaveChatRoom() {
    _messagesSubscription?.cancel();

    _messagesSubscription = null;

    _currentRoomId = null;

    _messages = [];

    // KHÔNG notifyListeners() trong dispose flow
  }

  // ===========================================================================
  // CLEANUP
  // ===========================================================================
  @override
  void dispose() {
    _roomsSubscription?.cancel();

    _messagesSubscription?.cancel();

    super.dispose();
  }
}
