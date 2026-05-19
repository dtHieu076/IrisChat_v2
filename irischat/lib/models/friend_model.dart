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
    return FriendModel(
      friendshipId: map['friendshipId'] ?? '',
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      since: map['since'] != null
          ? DateTime.parse(map['since'])
          : DateTime.now(),
      blockedBy: map['blockedBy'] ?? '',
      isFavorite: List<String>.from(map['isFavorite'] ?? []),
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
}
