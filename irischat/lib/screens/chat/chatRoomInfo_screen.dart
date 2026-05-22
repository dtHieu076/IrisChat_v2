import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/models/friend_model.dart';
import 'package:irischat/providers/friendship_provider.dart';
import 'package:irischat/providers/auth_provider.dart'; // Đảm bảo import đúng file AuthProvider của bạn để lấy UID

class ChatRoomInfoScreen extends StatefulWidget {
  final ChatRoomModel room;
  final UserModel? privateFriend;

  const ChatRoomInfoScreen({super.key, required this.room, this.privateFriend});

  @override
  State<ChatRoomInfoScreen> createState() => _ChatRoomInfoScreenState();
}

class _ChatRoomInfoScreenState extends State<ChatRoomInfoScreen> {
  String _currentUid = '';

  @override
  void initState() {
    super.initState();
    // Lấy UID của chính mình khi khởi tạo màn hình
    final authUser = context.read<AuthProvider>().user;
    if (authUser != null) {
      _currentUid = authUser.uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.room.isGroup
        ? widget.room.roomName
        : widget.privateFriend?.displayName ?? 'My Friend';

    final subtitle = widget.room.isGroup
        ? '${widget.room.participants.length} Members'
        : (widget.privateFriend?.isOnline ?? false)
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
      // Sử dụng StreamBuilder để đồng bộ trạng thái nút Block theo thời gian thực
      body: StreamBuilder<FriendModel?>(
        stream: widget.room.isGroup
            ? const Stream.empty()
            : context.read<FriendshipProvider>().listenFriendshipState(
                _currentUid,
                widget.privateFriend?.uid ?? '',
              ),
        builder: (context, snapshot) {
          final friendData = snapshot.data;
          final bool isBlocked =
              friendData != null && friendData.blockedBy.isNotEmpty;
          final bool amITheBlocker =
              isBlocked && friendData.blockedBy == _currentUid;

          return SingleChildScrollView(
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                // SUBTITLE
                if (!widget.room.isGroup) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: (widget.privateFriend?.isOnline ?? false)
                              ? Colors.green
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
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
                      if (widget.room.isGroup) ...[
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

                if (widget.room.isGroup) ...[
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

                // GỌI HÀM CHẶN / BỎ CHẶN (Chỉ hiển thị nếu là chat 1-1)
                if (!widget.room.isGroup)
                  _buildSectionTile(
                    icon: isBlocked ? Icons.check_circle_outline : Icons.block,
                    title: isBlocked
                        ? (amITheBlocker ? 'Unblock User' : 'You are Blocked')
                        : 'Block User',
                    textColor: isBlocked
                        ? (amITheBlocker ? Colors.green : Colors.grey)
                        : Colors.red,
                    onTap: () {
                      // Nếu đối phương chặn mình, mình không có quyền thao tác mở chặn
                      if (isBlocked && !amITheBlocker) return;
                      _showBlockDialog(context, amITheBlocker);
                    },
                  ),

                if (widget.room.isGroup) ...[
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
          );
        },
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

  // DIALOG XÁC NHẬN CHẶN / BỎ CHẶN
  void _showBlockDialog(BuildContext screenContext, bool isUnblockAction) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(isUnblockAction ? 'Unblock User' : 'Block User'),
        content: Text(
          isUnblockAction
              ? 'Do you want to unblock this user to resume conversation?'
              : 'Are you sure you want to block this user? Both of you won\'t be able to send messages.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(
              isUnblockAction ? 'Unblock' : 'Block',
              style: TextStyle(
                color: isUnblockAction ? Colors.green : Colors.red,
              ),
            ),
            onPressed: () async {
              if (widget.privateFriend == null || _currentUid.isEmpty) return;

              // Thực hiện đảo ngược trạng thái block qua Provider
              await screenContext.read<FriendshipProvider>().toggleBlock(
                currentUid: _currentUid,
                friendUid: widget.privateFriend!.uid,
                shouldBlock:
                    !isUnblockAction, // Nếu là UnblockAction thì truyền false (bỏ chặn)
              );

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
          ),
        ],
      ),
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
              if (widget.privateFriend == null) return;

              final currentUid = widget.room.participants.firstWhere(
                (uid) => uid != widget.privateFriend!.uid,
                orElse: () => '',
              );

              if (currentUid.isEmpty) return;

              await screenContext.read<FriendshipProvider>().removeFriend(
                currentUid: currentUid,
                friendUid: widget.privateFriend!.uid,
              );

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              if (!screenContext.mounted) return;
              Navigator.pop(screenContext);
            },
          ),
        ],
      ),
    );
  }
}
