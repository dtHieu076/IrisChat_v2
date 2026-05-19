import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/chat_room_model.dart';
import '../../../models/user_model.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/friendship_provider.dart';

import '../../../routes/app_routes.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) return;

    final uid = user.uid;

    context.read<ChatProvider>().listenAllChatRooms(uid);
    context.read<FriendshipProvider>().listenFriends(uid);

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUid = currentUser.uid;

    final friendsList = context.watch<FriendshipProvider>().friendsList;

    return Scaffold(
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final rooms = chatProvider.chatRooms;

          // ========================= EMPTY STATE =========================
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có cuộc hội thoại nào',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy sang tab Bạn bè để bắt đầu trò chuyện!',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // ========================= CHAT LIST =========================
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              final ChatRoomModel room = rooms[index];
              final isGroup = room.isGroup;

              UserModel? friendInfo;

              if (!isGroup) {
                final friendUid = room.participants.firstWhere(
                  (id) => id != currentUid,
                  orElse: () => '',
                );

                friendInfo = friendsList
                    .where((f) => f.uid == friendUid)
                    .cast<UserModel?>()
                    .firstWhere((e) => e != null, orElse: () => null);

                if (friendInfo == null) {
                  return const SizedBox.shrink();
                }
              }

              final displayName = isGroup
                  ? room.roomName
                  : friendInfo!.displayName;

              final avatarUrl = isGroup
                  ? room.roomAvatar
                  : friendInfo!.avatarUrl;

              final unreadCount = room.unreadCount[currentUid] ?? 0;
              final hasUnread = unreadCount > 0;

              return ListTile(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.chat, arguments: room);
                },

                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),

                title: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                  ),
                ),

                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    room.lastSenderId == currentUid
                        ? 'Bạn: ${room.lastMessage}'
                        : room.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasUnread ? Colors.black87 : Colors.grey.shade600,
                      fontWeight: hasUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),

                trailing: SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTimestamp(room.lastTimestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? Colors.blue.shade700 : Colors.grey,
                          fontWeight: hasUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ========================= FORMAT TIME =========================
  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return '';

    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    if (diff.inDays < 7) return '${diff.inDays} ngày';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
