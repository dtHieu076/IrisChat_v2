class ChatRoomModel {
  final String roomId;
  final String roomName;
  final String roomAvatar;
  final bool isGroup; // If false, it's a 1-1 chat. If true, it's a group chat.
  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final int lastTimestamp;
  final Map<String, int> unreadCount; // Number of unread messages for that user
  final String createdBy;

  ChatRoomModel({
    required this.roomId,
    this.roomName = '',
    this.roomAvatar = '',
    this.isGroup = false,
    required this.participants,
    this.lastMessage = '',
    this.lastSenderId = '',
    this.lastTimestamp = 0,
    this.unreadCount = const {},
    this.createdBy = '',
  });

  ChatRoomModel copyWith({
    String? roomId,
    String? roomName,
    String? roomAvatar,
    bool? isGroup,
    List<String>? participants,
    String? lastMessage,
    String? lastSenderId,
    int? lastTimestamp,
    Map<String, int>? unreadCount,
    String? createdBy,
  }) {
    return ChatRoomModel(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      roomAvatar: roomAvatar ?? this.roomAvatar,
      isGroup: isGroup ?? this.isGroup,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  static String generate1to1RoomId(String uid1, String uid2) {
    return (uid1.hashCode <= uid2.hashCode) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  factory ChatRoomModel.create1to1({
    required String currentUid,
    required String friendUid,
    required String friendName,
    required String friendAvatar,
  }) {
    return ChatRoomModel(
      roomId: generate1to1RoomId(currentUid, friendUid),
      roomName: friendName,
      roomAvatar: friendAvatar,
      isGroup: false,
      participants: [currentUid, friendUid],
      lastMessage: '',
      lastSenderId: '',
      lastTimestamp: DateTime.now().millisecondsSinceEpoch,
      unreadCount: const {},
      createdBy: currentUid,
    );
  }

  // ===========================================================================
  // FIREBASE -> MAP
  // ===========================================================================
  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'roomAvatar': roomAvatar,
      'isGroup': isGroup,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'lastTimestamp': lastTimestamp,
      'unreadCount': unreadCount,
      'createdBy': createdBy,
    };
  }

  // ===========================================================================
  // MAP -> MODEL
  // ===========================================================================
  factory ChatRoomModel.fromMap(Map<String, dynamic> map) {
    // Firebase Realtime Database thường trả dynamic
    // nên cần ép kiểu an toàn
    final rawUnreadCount = map['unreadCount'] ?? {};
    final Map<String, int> formattedUnreadCount = {};
    rawUnreadCount.forEach((key, value) {
      formattedUnreadCount[key.toString()] = (value as num).toInt();
    });

    return ChatRoomModel(
      roomId: map['roomId'] ?? '',
      roomName: map['roomName'] ?? '',
      roomAvatar: map['roomAvatar'] ?? '',
      isGroup: map['isGroup'] ?? false,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastSenderId: map['lastSenderId'] ?? '',
      lastTimestamp: (map['lastTimestamp'] ?? 0) as int,
      unreadCount: formattedUnreadCount,
      createdBy: map['createdBy'] ?? '',
    );
  }

  // ===========================================================================
  // DEBUG LOG
  // ===========================================================================
  @override
  String toString() {
    return '''
ChatRoomModel(
  roomId: $roomId,
  roomName: $roomName,
  roomAvatar: $roomAvatar,
  isGroup: $isGroup,
  participants: $participants,
  lastMessage: $lastMessage,
  lastSenderId: $lastSenderId,
  lastTimestamp: $lastTimestamp,
  unreadCount: $unreadCount,
  createdBy: $createdBy
)
''';
  }

  // ===========================================================================
  // EQUALS
  // ===========================================================================
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatRoomModel && other.roomId == roomId;
  }

  @override
  int get hashCode => roomId.hashCode;
}
