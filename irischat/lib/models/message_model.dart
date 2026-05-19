class MessageModel {
  final String messageId;
  final String senderId;
  final int timestamp;
  final String status; // sent | delivered | read
  final String type; // text | image | file | sticker | system

  // NỘI DUNG TEXT
  final String text;

  // MEDIA
  final String? mediaUrl; // URL của ảnh, file, sticker... (nếu có)
  final String? fileName; // Tên file nếu là file
  final int? fileSize; // bytes

  // REPLY MESSAGE
  final String? replyToMessageId;
  final String? replyText;
  final String? replySenderId;

  // REACTION
  /*
    {
      "uid_1": "❤️",
      "uid_2": "😂"
    }
  */
  final Map<String, dynamic>? reactions;

  // DELETE / EDIT
  final bool isDeleted;
  final bool isEdited;

  const MessageModel({
    required this.messageId,
    required this.senderId,
    required this.timestamp,
    this.status = 'sent',
    this.type = 'text',
    this.text = '',
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.replyToMessageId,
    this.replyText,
    this.replySenderId,
    this.reactions,
    this.isDeleted = false,
    this.isEdited = false,
  });

  MessageModel copyWith({
    String? messageId,
    String? senderId,
    int? timestamp,
    String? status,
    String? type,
    String? text,
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    String? replyToMessageId,
    String? replyText,
    String? replySenderId,
    Map<String, dynamic>? reactions,
    bool? isDeleted,
    bool? isEdited,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyText: replyText ?? this.replyText,
      replySenderId: replySenderId ?? this.replySenderId,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'timestamp': timestamp,
      'status': status,
      'type': type,
      'text': text,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'replyToMessageId': replyToMessageId,
      'replyText': replyText,
      'replySenderId': replySenderId,
      'reactions': reactions,
      'isDeleted': isDeleted,
      'isEdited': isEdited,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      status: map['status'] ?? 'sent',
      type: map['type'] ?? 'text',
      text: map['text'] ?? '',
      mediaUrl: map['mediaUrl'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      replyToMessageId: map['replyToMessageId'],
      replyText: map['replyText'],
      replySenderId: map['replySenderId'],
      reactions: map['reactions'] != null
          ? Map<String, dynamic>.from(map['reactions'])
          : null,
      isDeleted: map['isDeleted'] ?? false,
      isEdited: map['isEdited'] ?? false,
    );
  }
}
