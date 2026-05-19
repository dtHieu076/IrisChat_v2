import 'dart:async';
import 'dart:typed_data';

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

  //
  String _currentUid = '';
  void setCurrentUid(String uid) {
    _currentUid = uid;
  }

  bool get hasUnreadMessages {
    return chatRooms.any((room) => (room.unreadCount[_currentUid] ?? 0) > 0);
  }

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
  // HÀM GỬI TIN NHẮN CỐT LÕI (PRIVATE)
  // ===========================================================================
  Future<void> _sendCoreMessage({
    required String roomId,
    required String currentUid,
    required String type,
    String text = '',
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    String? replyToMessageId,
    String? replyText,
    String? replySenderId,
  }) async {
    try {
      _isSending = true;
      notifyListeners();

      final room = _chatRooms.firstWhere(
        (room) => room.roomId == roomId,
        orElse: () => throw Exception('Phòng chat không tồn tại'),
      );

      // LẤY MESSAGE ID TỪ SERVICE
      final messageId = _chatService.generateMessageId(roomId);

      // TẠO MESSAGE MODEL
      final newMessage = MessageModel(
        messageId: messageId,
        senderId: currentUid,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: 'sent',
        type: type,
        text: text.trim(),
        mediaUrl: mediaUrl,
        fileName: fileName,
        fileSize: fileSize,
        replyToMessageId: replyToMessageId,
        replyText: replyText,
        replySenderId: replySenderId,
      );

      // GỬI MESSAGE QUA SERVICE
      await _chatService.sendMessage(
        roomId: roomId,
        message: newMessage,
        participants: room.participants,
      );
    } catch (e) {
      debugPrint('Lỗi tạo messageId: $e');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // PUBLIC: GỬI TIN NHẮN TEXT BÌNH THƯỜNG
  // ===========================================================================
  Future<void> sendTextMessage({
    required String roomId,
    required String currentUid,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    await _sendCoreMessage(
      roomId: roomId,
      currentUid: currentUid,
      type: 'text',
      text: text,
    );
  }

  // ===========================================================================
  // PUBLIC: GỬI TIN NHẮN MEDIA (Ảnh, File, Sticker...)
  // ===========================================================================
  Future<void> sendMediaMessage({
    required String roomId,
    required String currentUid,
    required String type, // 'image' | 'file' | 'sticker'
    required String mediaUrl,
    String? fileName,
    int? fileSize,
    String text = '', // Caption đi kèm nếu có
  }) async {
    if (mediaUrl.isEmpty) return;

    await _sendCoreMessage(
      roomId: roomId,
      currentUid: currentUid,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  // ===========================================================================
  // PUBLIC: TRẢ LỜI TIN NHẮN (REPLY)
  // ===========================================================================
  Future<void> sendReplyMessage({
    required String roomId,
    required String currentUid,
    required String text,
    required String replyToMessageId,
    required String replyText,
    required String replySenderId,
  }) async {
    if (text.trim().isEmpty) return;

    await _sendCoreMessage(
      roomId: roomId,
      currentUid: currentUid,
      type: 'text',
      text: text,
      replyToMessageId: replyToMessageId,
      replyText: replyText,
      replySenderId: replySenderId,
    );
  }

  // ===========================================================================
  // PUBLIC: THẢ / HỦY CẢM XÚC TIN NHẮN (REACTION)
  // ===========================================================================
  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String currentUid,
    required String emoji, // VD: '❤️', '👍', '😂'
  }) async {
    try {
      // 1. Tìm tin nhắn hiện tại trong bộ nhớ local (State)
      final index = _messages.indexWhere((msg) => msg.messageId == messageId);
      if (index == -1) return;

      final targetMessage = _messages[index];

      // 2. Kiểm tra xem user hiện tại đã react emoji này chưa
      final currentReaction = targetMessage.reactions?[currentUid];

      String? newReaction;
      if (currentReaction == emoji) {
        // Nếu bấm lại vào emoji cũ -> Huỷ reaction (gán bằng null)
        newReaction = null;
      } else {
        // Nếu chưa react hoặc chọn emoji khác -> Cập nhật emoji mới
        newReaction = emoji;
      }

      // 3. Gọi service cập nhật lên Firebase (Realtime stream sẽ tự đồng bộ về UI)
      await _chatService.updateMessageReaction(
        roomId: roomId,
        messageId: messageId,
        userId: currentUid,
        reaction: newReaction,
      );
    } catch (e) {
      debugPrint('Lỗi toggle reaction: $e');
    }
  }

  // Sửa lại hàm uploadAndSendMedia để kết nối với Cloudinary
  Future<void> uploadAndSendMedia({
    required String roomId,
    required String currentUid,
    required String type, // 'image' | 'file'
    required Uint8List
    fileBytes, // Nhận bytes trực tiếp từ Picker (Web/Mobile đều chạy được)
    required String fileName,
    int? fileSize,
    String text = '',
  }) async {
    try {
      _isSending = true;
      notifyListeners();

      // 1. Upload lên Cloudinary qua ChatService đã sửa ở trên
      final String realMediaUrl = await _chatService.uploadChatFile(
        fileBytes: fileBytes,
        fileName: '${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      // 2. Đẩy Message Model lên Database với URL từ Cloudinary
      await sendMediaMessage(
        roomId: roomId,
        currentUid: currentUid,
        type: type,
        mediaUrl: realMediaUrl,
        fileName: fileName,
        fileSize: fileSize,
        text: text,
      );
    } catch (e) {
      debugPrint('Lỗi upload Cloudinary: $e');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // Recall message
  Future<void> recallMessage({
    required String roomId,
    required String messageId,
  }) async {
    try {
      await _chatService.recallMessage(roomId: roomId, messageId: messageId);
    } catch (e) {
      debugPrint('Recall message error: $e');
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
