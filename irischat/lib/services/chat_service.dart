import 'package:firebase_database/firebase_database.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';

class ChatService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Hàm tạo Room ID duy nhất từ 2 UID (Sắp xếp theo thứ tự bảng chữ cái để luôn nhất quán)
  String getRoomId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  // 1. LẤY DANH SÁCH PHÒNG CHAT (Xưa giờ) - Realtime
  Stream<List<ChatRoomModel>> listenChatRooms(String currentUid) {
    return _db.child('chat_rooms').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final map = Map<dynamic, dynamic>.from(data as dynamic);
      final List<ChatRoomModel> rooms = [];

      map.forEach((key, value) {
        final roomMap = Map<String, dynamic>.from(value);
        final room = ChatRoomModel.fromMap(roomMap);

        // Chỉ lấy phòng chat mà user hiện tại tham gia
        if (room.participants.contains(currentUid)) {
          rooms.add(room);
        }
      });

      // Sắp xếp phòng có tin nhắn mới nhất lên đầu
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

      // Sắp xếp tin nhắn cũ trước, tin nhắn mới sau để render từ trên xuống (hoặc reverse dưới lên)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  // 3. GỬI TIN NHẮN & CẬP NHẬT STATE ĐỒNG THỜI (Multi-location Update)
  Future<void> sendMessage({
    required String roomId,
    required MessageModel message,
    required List<String> participants,
  }) async {
    final Map<String, dynamic> updates = {};

    // Vị trí 1: Thêm tin nhắn vào lịch sử cuộc trò chuyện (node chats)
    updates['/chats/$roomId/${message.messageId}'] = message.toMap();

    // Vị trí 2: Cập nhật thông tin phòng chat bên ngoài (node chat_rooms) để hiển thị Preview
    updates['/chat_rooms/$roomId/roomId'] = roomId;
    updates['/chat_rooms/$roomId/participants'] = participants;
    updates['/chat_rooms/$roomId/lastMessage'] = message.text;
    updates['/chat_rooms/$roomId/lastSenderId'] = message.senderId;
    updates['/chat_rooms/$roomId/lastTimestamp'] = message.timestamp;

    // Logic xử lý TĂNG SỐ TIN CHƯA ĐỌC (unreadCount) của đối phương
    final friendUid = participants.firstWhere((id) => id != message.senderId);

    // Sử dụng transaction ngầm thông qua đường dẫn cụ thể để tránh xung đột dữ liệu
    final unreadRef = _db
        .child('chat_rooms')
        .child(roomId)
        .child('unreadCount')
        .child(friendUid);
    final snapshot = await unreadRef.get();
    int currentUnread = 0;
    if (snapshot.exists) {
      currentUnread = (snapshot.value as num).toInt();
    }
    updates['/chat_rooms/$roomId/unreadCount/$friendUid'] = currentUnread + 1;

    // Thực hiện lệnh cập nhật đồng bộ - Thành công cả 2 hoặc Thất bại cả 2
    await _db.update(updates);
  }

  // 4. XÓA SỐ TIN CHƯA ĐỌC KHI MỞ PHÒNG CHAT (Đánh dấu đã đọc)
  Future<void> clearUnreadCount(String roomId, String currentUid) async {
    await _db
        .child('chat_rooms')
        .child(roomId)
        .child('unreadCount')
        .child(currentUid)
        .set(0);
  }

  Future<void> updateMessageStatus({
    required String roomId,
    required String messageId,
    required String status,
  }) async {
    await FirebaseDatabase.instance
        .ref()
        .child('chats')
        .child(roomId)
        .child(messageId)
        .update({'status': status});
  }
}
