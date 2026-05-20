import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/friendship_provider.dart';

class ChatRoomInfoScreen extends StatelessWidget {
  final ChatRoomModel room;
  final UserModel? privateFriend;

  const ChatRoomInfoScreen({super.key, required this.room, this.privateFriend});

  @override
  Widget build(BuildContext context) {
    final displayName = room.isGroup
        ? room.roomName
        : privateFriend?.displayName ?? 'My Friend';

    final subtitle = room.isGroup
        ? '${room.participants.length} Members'
        : (privateFriend?.isOnline ?? false)
        ? 'Online'
        : 'Offline';

    final avatarLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Conversation Info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // AVATAR
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // NAME
            Text(
              displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            // SUBTITLE
            if (!room.isGroup) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: (privateFriend?.isOnline ?? false)
                          ? Colors.green
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),

                  const SizedBox(width: 6),

                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ] else ...[
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],

            const SizedBox(height: 28),

            // ACTIONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (room.isGroup) ...[
                    _buildActionButton(
                      icon: Icons.person_add_alt_1,
                      label: 'Add\nMembers',
                      onTap: () {},
                    ),
                  ] else ...[
                    _buildActionButton(
                      icon: Icons.call,
                      label: 'Profile',
                      onTap: () {},
                    ),
                  ],
                  _buildActionButton(
                    icon: Icons.search,
                    label: 'Search\nMessages',
                    onTap: () {},
                  ),

                  _buildActionButton(
                    icon: Icons.photo,
                    label: 'Images &\nVideos',
                    onTap: () {},
                  ),

                  _buildActionButton(
                    icon: Icons.notifications,
                    label: 'Notifications',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // SETTINGS
            _buildSectionTile(
              icon: Icons.edit,
              title: 'Change Conversation Name',
              onTap: () {},
            ),

            _buildSectionTile(
              icon: Icons.wallpaper,
              title: 'Change Background',
              onTap: () {},
            ),

            if (room.isGroup) ...[
              _buildSectionTile(
                icon: Icons.group,
                title: 'View Members',
                onTap: () {},
              ),
            ] else ...[
              _buildSectionTile(
                icon: Icons.group_add,
                title: 'Add to Group',
                onTap: () {},
              ),
            ],

            _buildSectionTile(
              icon: Icons.block,
              title: 'Block Messages',
              textColor: Colors.red,
              onTap: () {},
            ),

            if (room.isGroup) ...[
              _buildSectionTile(
                icon: Icons.logout,
                title: 'Leave Group',
                textColor: Colors.red,
                onTap: () {},
              ),
            ] else ...[
              _buildSectionTile(
                icon: Icons.delete,
                title: 'Unfriend',
                textColor: Colors.red,
                onTap: () {
                  _showUnfriendDialog(context);
                },
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade50,
              child: Icon(icon, color: Colors.blue),
            ),

            const SizedBox(height: 8),

            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showUnfriendDialog(BuildContext screenContext) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unfriend'),
        content: const Text('Are you sure you want to unfriend this person?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: const Text('Unfriend', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              if (privateFriend == null) return;

              final currentUid = room.participants.firstWhere(
                (uid) => uid != privateFriend!.uid,
                orElse: () => '',
              );

              if (currentUid.isEmpty) return;

              await screenContext.read<FriendshipProvider>().removeFriend(
                currentUid: currentUid,
                friendUid: privateFriend!.uid,
              );

              // 3. Kiểm tra xem màn hình còn tồn tại không trước khi chuyển hướng
              if (!dialogContext.mounted) return;

              Navigator.pop(dialogContext);

              // 5. Nếu muốn đóng luôn màn hình Info để quay về phòng chat, dùng tiếp dòng dưới:
              if (!screenContext.mounted) return;
              Navigator.pop(screenContext);
            },
          ),
        ],
      ),
    );
  }
}
