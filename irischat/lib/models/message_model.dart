class MessageModel {
  final String messageId;
  final String senderId;
  final String text;
  final int timestamp; // Định dạng millisecondsSinceEpoch để sort realtime
  final String status; // Trạng thái tin nhắn: 'sending', 'sent', 'read'

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.status = 'sent',
  });

  // Sao chép đối tượng phục vụ việc thay đổi trạng thái tin nhắn (Ví dụ: từ 'sending' sang 'sent')
  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? text,
    int? timestamp,
    String? status,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'status': status,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      status: map['status'] ?? 'sent',
    );
  }
}
