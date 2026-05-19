class FriendModel {
  final String friendshipId; // ID duy nhất của mối quan hệ này
  final String user1Id; // ID của người thứ nhất
  final String user2Id; // ID của người thứ hai
  final DateTime since; // Thời gian kết bạn
  final bool isBlocked;
  final bool isFavorite;

  const FriendModel({
    required this.friendshipId,
    required this.user1Id,
    required this.user2Id,
    required this.since,
    required this.isBlocked,
    required this.isFavorite,
  });

  factory FriendModel.fromMap(Map<dynamic, dynamic> map) {
    return FriendModel(
      friendshipId: map['friendshipId'] ?? '',
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      since: map['since'] != null
          ? DateTime.parse(map['since'])
          : DateTime.now(),
      isBlocked: map['isBlocked'] ?? false,
      isFavorite: map['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'friendshipId': friendshipId,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'since': since.toIso8601String(),
      'isBlocked': isBlocked,
      'isFavorite': isFavorite,
    };
  }
}
