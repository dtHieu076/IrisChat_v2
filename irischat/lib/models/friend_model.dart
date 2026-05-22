class FriendModel {
  final String friendshipId;
  final String user1Id;
  final String user2Id;
  final DateTime since;
  final String blockedBy;
  final List<String> isFavorite;

  const FriendModel({
    required this.friendshipId,
    required this.user1Id,
    required this.user2Id,
    required this.since,
    required this.blockedBy,
    required this.isFavorite,
  });

  factory FriendModel.fromMap(Map<dynamic, dynamic> map) {
    // Kiểm tra và ép kiểu an toàn cho trường isFavorite
    List<String> favoriteList = [];
    if (map['isFavorite'] is Iterable) {
      favoriteList = List<String>.from(map['isFavorite']);
    }

    return FriendModel(
      friendshipId: map['friendshipId'] ?? '',
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      since: map['since'] != null
          ? DateTime.parse(map['since'])
          : DateTime.now(),
      blockedBy: map['blockedBy'] ?? '',
      isFavorite: favoriteList, // Đã an toàn tuyệt đối
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'friendshipId': friendshipId,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'since': since.toIso8601String(),
      'blockedBy': blockedBy,
      'isFavorite': isFavorite,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendModel &&
          runtimeType == other.runtimeType &&
          friendshipId == other.friendshipId &&
          user1Id == other.user1Id &&
          user2Id == other.user2Id &&
          blockedBy == other.blockedBy;

  @override
  int get hashCode =>
      friendshipId.hashCode ^
      user1Id.hashCode ^
      user2Id.hashCode ^
      blockedBy.hashCode;
}
