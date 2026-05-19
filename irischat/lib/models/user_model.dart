class UserModel {
  final String uid;

  final String email;

  final String displayName;

  final String avatarUrl;

  final bool isOnline;

  final DateTime? lastSeen;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.isOnline,
    required this.lastSeen,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',

      email: map['email'] ?? '',

      displayName: map['displayName'] ?? '',

      avatarUrl: map['avatarUrl'] ?? '',

      isOnline: map['isOnline'] ?? false,

      lastSeen: map['lastSeen'] != null
          ? DateTime.tryParse(map['lastSeen'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,

      'email': email,

      'displayName': displayName,

      'avatarUrl': avatarUrl,

      'isOnline': isOnline,

      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid ?? this.uid,

      email: email ?? this.email,

      displayName: displayName ?? this.displayName,

      avatarUrl: avatarUrl ?? this.avatarUrl,

      isOnline: isOnline ?? this.isOnline,

      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
