import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/chat_room_model.dart';
import '../../../models/user_model.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/friendship_provider.dart';
import '../../../providers/user_provider.dart';

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

    // Kích hoạt lắng nghe dữ liệu realtime
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

          // 1. GIAO DIỆN TRỐNG (EMPTY STATE)
          if (rooms.isEmpty) {
            return _buildEmptyState();
          }

          // 2. DANH SÁCH PHÒNG CHAT (CHAT LIST)
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, index) {
              return _buildChatRoomLoader(
                context: context,
                room: rooms[index],
                currentUid: currentUid,
                friendsList: friendsList,
              );
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // HÀM 1: GIAO DIỆN KHI CHƯA CÓ CUỘC HỘI THOẠI NÀO
  // ===========================================================================
  Widget _buildEmptyState() {
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

  // ===========================================================================
  // HÀM 2: BỘ PHÂN LOẠI & TẢI DỮ LIỆU PHÒNG CHAT (Group / Bạn bè / Người lạ)
  // ===========================================================================
  Widget _buildChatRoomLoader({
    required BuildContext context,
    required ChatRoomModel room,
    required String currentUid,
    required List<UserModel> friendsList,
  }) {
    // TH1: Nếu là nhóm chat -> Render luôn không cần check Friend list
    if (room.isGroup) {
      return _buildChatTile(
        context: context,
        room: room,
        displayName: room.roomName,
        avatarUrl: room.roomAvatar,
        currentUid: currentUid,
      );
    }

    // TH2: Chat 1-1 -> Tìm UID đối phương
    final friendUid = room.participants.firstWhere(
      (id) => id != currentUid,
      orElse: () => '',
    );

    // Khớp thông tin từ danh sách bạn bè đã cache ở local máy (Realtime)
    final friendInList = friendsList.any((f) => f.uid == friendUid)
        ? friendsList.firstWhere((f) => f.uid == friendUid)
        : null;

    if (friendInList != null) {
      return _buildChatTile(
        context: context,
        room: room,
        displayName: friendInList.displayName,
        avatarUrl: friendInList.avatarUrl,
        currentUid: currentUid,
      );
    }

    // TH3: Chat với người lạ -> Dùng FutureBuilder gọi qua UserProvider để lấy data từ Firebase
    return FutureBuilder<UserModel?>(
      future: context.read<UserProvider>().fetchUserById(friendUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 72,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final strangerUser = snapshot.data!;
          return _buildChatTile(
            context: context,
            room: room,
            displayName: strangerUser.displayName,
            avatarUrl: strangerUser.avatarUrl,
            currentUid: currentUid,
          );
        }

        // Dự phòng nếu tài khoản đối phương bị lỗi hoặc bị xóa
        return _buildChatTile(
          context: context,
          room: room,
          displayName: 'Người dùng IrisChat',
          avatarUrl: '',
          currentUid: currentUid,
        );
      },
    );
  }

  // ===========================================================================
  // HÀM 3: RENDER Ô CHAT CHI TIẾT (LIST TILE)
  // ===========================================================================
  Widget _buildChatTile({
    required BuildContext context,
    required ChatRoomModel room,
    required String displayName,
    required String avatarUrl,
    required String currentUid,
  }) {
    final unreadCount = room.unreadCount[currentUid] ?? 0;
    final hasUnread = unreadCount > 0;
    final isRecalled = room.lastMessage == 'Tin nhắn đã bị thu hồi';

    // Logic gán chữ hiển thị tin nhắn cuối cùng dựa trên trạng thái thu hồi
    String finalSubtitleText = '';
    if (isRecalled) {
      finalSubtitleText = room.lastSenderId == currentUid
          ? 'Bạn đã thu hồi một tin nhắn'
          : 'Tin nhắn đã bị thu hồi';
    } else {
      finalSubtitleText = room.lastSenderId == currentUid
          ? 'Bạn: ${room.lastMessage}'
          : room.lastMessage;
    }

    return ListTile(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.chat, arguments: room);
      },
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
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
          finalSubtitleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: isRecalled
                ? Colors.grey.shade400
                : (hasUnread ? Colors.black87 : Colors.grey.shade600),
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            fontStyle: isRecalled ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
      trailing: SizedBox(
        width: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(room.lastTimestamp),
              style: TextStyle(
                fontSize: 12,
                color: hasUnread ? Colors.blue.shade700 : Colors.grey,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
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
  }

  // ===========================================================================
  // HÀM 4: ĐỊNH DẠNG THỜI GIAN HIỂN THỊ
  // ===========================================================================
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
