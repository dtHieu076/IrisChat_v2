import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/auth_provider.dart';
import 'package:irischat/providers/call_provider.dart';
import 'package:irischat/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ChatAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final ChatRoomModel room;
  final UserModel? privateFriend;
  final VoidCallback onSearchPressed;

  const ChatAppBarWidget({
    super.key,
    required this.room,
    this.privateFriend,
    required this.onSearchPressed,
  });

  @override
  Size get preferredSize {
    // Tăng nhẹ chiều cao để không gian hiển thị thoáng hơn
    return const Size.fromHeight(kToolbarHeight + 4);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.teal[600]!;

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, // Ngăn màu nền bị trộn khi scroll
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.08), // Bóng đổ siêu mềm
      scrolledUnderElevation: 4,
      titleSpacing: 0,

      // Tinh chỉnh nút Back gọn gàng hơn
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Colors.blueGrey[800],
        ),
        onPressed: () => Navigator.pop(context),
        splashRadius: 24,
      ),

      title: GestureDetector(
        // Cho phép bấm vào toàn bộ khu vực title để mở Info (Tuỳ chọn)
        onTap: () {
          Navigator.pushNamed(
            context,
            '/chat-room-info',
            arguments: {'room': room, 'privateFriend': privateFriend},
          );
        },
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(child: _buildChatTitleInfo()),
          ],
        ),
      ),

      actions: [
        IconButton(
          icon: Icon(
            Icons.search_rounded,
            color: Colors.blueGrey[600],
            size: 24,
          ),
          tooltip: 'Tìm kiếm',
          splashRadius: 24,
          onPressed: onSearchPressed,
        ),

        // Làm nổi bật nút Gọi điện bằng một lớp nền mờ
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.call_rounded, color: themeColor, size: 22),
            tooltip: 'Gọi điện',
            splashRadius: 24,
            onPressed: () async {
              final currentUid = context.read<AuthProvider>().user!.uid;
              final callProvider = context.read<CallProvider>();

              await callProvider.startCall(
                callerId: currentUid,
                receiverId: privateFriend!.uid,
              );
            },
          ),
        ),

        IconButton(
          icon: Icon(
            Icons.more_vert_rounded,
            color: Colors.blueGrey[600],
            size: 24,
          ),
          tooltip: 'Tùy chọn',
          splashRadius: 24,
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/chat-room-info',
              arguments: {'room': room, 'privateFriend': privateFriend},
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ==========================================
  // WIDGET HỖ TRỢ HIỂN THỊ
  // ==========================================

  Widget _buildAvatar() {
    String initial = 'U';

    if (room.isGroup) {
      initial = room.roomName.isNotEmpty ? room.roomName[0].toUpperCase() : 'G';
    } else if (privateFriend?.displayName.isNotEmpty == true) {
      initial = privateFriend!.displayName[0].toUpperCase();
    }

    final String avatarUrl = room.isGroup
        ? room.roomAvatar
        : (privateFriend?.avatarUrl ?? '');

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.teal.shade50,
          width: 2,
        ), // Thêm viền nhẹ
      ),
      child: CircleAvatar(
        radius: 21,
        backgroundColor: Colors.teal[50],
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(
                initial,
                style: TextStyle(
                  color: Colors.teal[700],
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildChatTitleInfo() {
    // 1. Giao diện Nhóm
    if (room.isGroup) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            room.roomName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey[900],
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Nhóm trò chuyện',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // 2. Giao diện Chat Cá Nhân (Sử dụng StreamBuilder với UserService)
    if (privateFriend == null) return const SizedBox();

    // Khởi tạo UserService
    final userService = UserService();

    return StreamBuilder<UserModel?>(
      // Đưa luồng listenUserProfile từ Service vào đây
      stream: userService.listenUserProfile(privateFriend!.uid),
      builder: (context, snapshot) {
        // Giá trị mặc định (từ cache/state ban đầu truyền qua constructor)
        bool isOnline = privateFriend!.isOnline;
        DateTime? lastSeen = privateFriend!.lastSeen;
        String displayName = privateFriend!.displayName.isNotEmpty
            ? privateFriend!.displayName
            : 'User';

        // Nếu Firebase bắn dữ liệu realtime về thông qua Stream, cập nhật lại biến
        if (snapshot.hasData && snapshot.data != null) {
          final updatedUser = snapshot.data!;
          isOnline = updatedUser.isOnline;
          lastSeen = updatedUser.lastSeen;
          displayName = updatedUser.displayName.isNotEmpty
              ? updatedUser.displayName
              : 'User';
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey[900],
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isOnline ? 'Đang hoạt động' : _formatLastSeen(lastSeen),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline
                          ? const Color(0xFF047857)
                          : Colors.blueGrey[400],
                      fontWeight: isOnline ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Ngoại tuyến';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Vừa mới truy cập';
    } else if (difference.inMinutes < 60) {
      return 'Hoạt động ${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return 'Hoạt động ${difference.inHours} giờ trước';
    } else {
      return 'Truy cập ${DateFormat('dd/MM HH:mm').format(lastSeen)}';
    }
  }
}
