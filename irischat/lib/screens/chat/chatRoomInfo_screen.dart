import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';

class ChatRoomInfoScreen extends StatelessWidget {
  final ChatRoomModel room;
  final UserModel? privateFriend;

  const ChatRoomInfoScreen({super.key, required this.room, this.privateFriend});

  @override
  Widget build(BuildContext context) {
    final displayName = room.isGroup
        ? room.roomName
        : privateFriend?.displayName ?? 'Người dùng';

    final subtitle = room.isGroup
        ? '${room.participants.length} thành viên'
        : (privateFriend?.isOnline ?? false)
        ? 'Đang hoạt động'
        : 'Ngoại tuyến';

    final avatarLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'U';
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Thông tin cuộc trò chuyện',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // =====================================================
            // AVATAR
            // =====================================================
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

            // =====================================================
            // NAME
            // =====================================================
            Text(
              displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

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
                    (privateFriend?.isOnline ?? false)
                        ? 'Đang hoạt động'
                        : 'Ngoại tuyến',
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

            // =====================================================
            // ACTIONS
            // =====================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (room.isGroup) ...[
                    _buildActionButton(
                      icon: Icons.person_add_alt_1,
                      label: 'Thêm\nthành viên',
                      onTap: () {},
                    ),
                  ] else ...[
                    _buildActionButton(
                      icon: Icons.call,
                      label: 'Trang\n cá nhân',
                      onTap: () {},
                    ),
                  ],
                  _buildActionButton(
                    icon: Icons.search,
                    label: 'Tìm\n tin nhắn',
                    onTap: () {},
                  ),

                  _buildActionButton(
                    icon: Icons.photo,
                    label: 'Ảnh &\nvideo',
                    onTap: () {},
                  ),

                  _buildActionButton(
                    icon: Icons.notifications,
                    label: 'Thông báo',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // =====================================================
            // SETTINGS
            // =====================================================
            _buildSectionTile(
              icon: Icons.edit,
              title: 'Đổi tên cuộc trò chuyện',
              onTap: () {},
            ),

            _buildSectionTile(
              icon: Icons.wallpaper,
              title: 'Đổi hình nền',
              onTap: () {},
            ),

            if (room.isGroup) ...[
              _buildSectionTile(
                icon: Icons.group,
                title: 'Xem thành viên',
                onTap: () {},
              ),
            ] else ...[
              _buildSectionTile(
                icon: Icons.group_add,
                title: 'Thêm vào nhóm',
                onTap: () {},
              ),
            ],

            _buildSectionTile(
              icon: Icons.block,
              title: 'Chặn tin nhắn',
              textColor: Colors.red,
              onTap: () {},
            ),

            if (room.isGroup) ...[
              _buildSectionTile(
                icon: Icons.logout,
                title: 'Rời nhóm',
                textColor: Colors.red,
                onTap: () {},
              ),
            ] else ...[
              _buildSectionTile(
                icon: Icons.delete,
                title: 'Hủy kết bạn',
                textColor: Colors.red,
                onTap: () {},
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
}
