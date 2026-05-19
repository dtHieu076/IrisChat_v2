import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:irischat/services/CloudinaryService.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';

class ChatService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // ===========================================================================
  // TẠO MESSAGE ID (Dùng chính _db của Service)
  // ===========================================================================
  String generateMessageId(String roomId) {
    return _db.child('chats').child(roomId).push().key ?? '';
  }

  // Hàm tạo Room ID duy nhất từ 2 UID
  String getRoomId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  // 1. LẤY DANH SÁCH PHÒNG CHAT - Realtime
  Stream<List<ChatRoomModel>> listenChatRooms(String currentUid) {
    return _db.child('chat_rooms').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final map = Map<dynamic, dynamic>.from(data as dynamic);
      final List<ChatRoomModel> rooms = [];

      map.forEach((key, value) {
        final roomMap = Map<String, dynamic>.from(value);
        final room = ChatRoomModel.fromMap(roomMap);

        if (room.participants.contains(currentUid)) {
          rooms.add(room);
        }
      });

      rooms.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
      return rooms;
    });
  }

  // 2. LẤY CHI TIẾT TIN NHẮN THEO PHÒNG - Realtime
  Stream<List<MessageModel>> listenMessages(String roomId) {
    return _db.child('chats').child(roomId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final map = Map<dynamic, dynamic>.from(data as dynamic);
      final List<MessageModel> messages = [];

      map.forEach((key, value) {
        final msgMap = Map<String, dynamic>.from(value);
        messages.add(MessageModel.fromMap(msgMap));
      });

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  // 3. GỬI TIN NHẮN & CẬP NHẬT STATE ĐỒNG THỜI
  Future<void> sendMessage({
    required String roomId,
    required MessageModel message,
    required List<String> participants,
  }) async {
    final Map<String, dynamic> updates = {};

    // Vị trí 1: Thêm tin nhắn vào node chats
    updates['/chats/$roomId/${message.messageId}'] = message.toMap();

    // Xử lý hiển thị tin nhắn cuối cùng (Ẩn link URL dài dòng, thay bằng [Hình ảnh], [Tệp tin]...)
    String lastMessagePreview = message.text;
    if (lastMessagePreview.isEmpty) {
      switch (message.type) {
        case 'image':
          lastMessagePreview = '[Hình ảnh]';
          break;
        case 'file':
          lastMessagePreview = '[Tệp tin]';
          break;
        case 'sticker':
          lastMessagePreview = '[Sticker]';
          break;
        default:
          lastMessagePreview = '[Tin nhắn]';
      }
    }

    // Vị trí 2: Cập nhật thông tin phòng chat bên ngoài
    updates['/chat_rooms/$roomId/roomId'] = roomId;
    updates['/chat_rooms/$roomId/participants'] = participants;
    updates['/chat_rooms/$roomId/lastMessage'] = lastMessagePreview;
    updates['/chat_rooms/$roomId/lastSenderId'] = message.senderId;
    updates['/chat_rooms/$roomId/lastTimestamp'] = message.timestamp;

    for (final uid in participants) {
      if (uid == message.senderId) continue;

      final unreadRef = _db
          .child('chat_rooms')
          .child(roomId)
          .child('unreadCount')
          .child(uid);

      final snapshot = await unreadRef.get();
      int currentUnread = 0;

      if (snapshot.exists) {
        currentUnread = (snapshot.value as num).toInt();
      }

      updates['/chat_rooms/$roomId/unreadCount/$uid'] = currentUnread + 1;
    }

    await _db.update(updates);
  }

  // 4. XÓA SỐ TIN CHƯA ĐỌC KHI MỞ PHÒNG CHAT
  Future<void> clearUnreadCount(String roomId, String currentUid) async {
    await _db
        .child('chat_rooms')
        .child(roomId)
        .child('unreadCount')
        .child(currentUid)
        .set(0);
  }

  // Cập nhật trạng thái đã xem (Refactor lại dùng luôn _db cho đồng bộ)
  Future<void> updateMessageStatus({
    required String roomId,
    required String messageId,
    required String status,
  }) async {
    await _db.child('chats').child(roomId).child(messageId).update({
      'status': status,
    });
  }

  // CẬP NHẬT REACTION (Thả / Đổi / Xóa cảm xúc)
  Future<void> updateMessageReaction({
    required String roomId,
    required String messageId,
    required String userId,
    required String? reaction, // Nếu truyền null nghĩa là xóa reaction
  }) async {
    final reactionRef = _db
        .child('chats')
        .child(roomId)
        .child(messageId)
        .child('reactions')
        .child(userId);

    if (reaction == null) {
      await reactionRef.remove(); // Xóa khỏi Firebase nếu user hủy reaction
    } else {
      await reactionRef.set(reaction); // Set emoji (VD: "❤️", "😂")
    }
  }

  Future<String> uploadChatFile({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final secureUrl = await _cloudinaryService.uploadFile(fileBytes, fileName);

    if (secureUrl == null) {
      throw Exception('Không lấy được URL sau khi upload lên Cloudinary');
    }

    return secureUrl; // Trả về link https để lưu vào Realtime Database
  }
}
