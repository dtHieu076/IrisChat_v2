class FriendshipModel {
  final String requestId;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String status;
  final DateTime createdAt;

  const FriendshipModel({
    required this.requestId,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  factory FriendshipModel.fromMap(Map<dynamic, dynamic> map) {
    return FriendshipModel(
      requestId: map['requestId'] ?? '',

      senderId: map['senderId'] ?? '',

      senderEmail: map['senderEmail'] ?? '',

      receiverId: map['receiverId'] ?? '',

      status: map['status'] ?? '',

      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,

      'senderId': senderId,

      'senderEmail': senderEmail,

      'receiverId': receiverId,

      'status': status,

      'createdAt': createdAt.toIso8601String(),
    };
  }

  FriendshipModel copyWith({
    String? requestId,

    String? senderId,

    String? senderEmail,

    String? receiverId,

    String? status,

    DateTime? createdAt,
  }) {
    return FriendshipModel(
      requestId: requestId ?? this.requestId,

      senderId: senderId ?? this.senderId,

      senderEmail: senderEmail ?? this.senderEmail,

      receiverId: receiverId ?? this.receiverId,

      status: status ?? this.status,

      createdAt: createdAt ?? this.createdAt,
    );
  }
}
