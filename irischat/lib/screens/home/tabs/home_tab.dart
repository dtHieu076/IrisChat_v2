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

    // Kích hoạt lắng nghe dữ liệu realtime (GIỮ NGUYÊN LOGIC)
    context.read<ChatProvider>().listenAllChatRooms(uid);
    context.read<FriendshipProvider>().listenFriends(uid);

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final primaryColor = Colors.teal[600]!;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

    final currentUid = currentUser.uid;
    final friendsList = context.watch<FriendshipProvider>().friendsList;

    return Scaffold(
      backgroundColor: Colors.grey[50], // Tạo nền sáng mát, sạch sẽ
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final rooms = chatProvider.chatRooms;

          // 1. GIAO DIỆN TRỐNG (EMPTY STATE)
          if (rooms.isEmpty) {
            return _buildEmptyState(primaryColor);
          }

          // 2. DANH SÁCH PHÒNG CHAT (CHAT LIST)
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => Divider(
              height: 1, 
              indent: 80, 
              color: Colors.grey[200], // Đường phân cách mảnh nhẹ tinh tế
            ),
            itemBuilder: (context, index) {
              return _buildChatRoomLoader(
                context: context,
                room: rooms[index],
                currentUid: currentUid,
                friendsList: friendsList,
                primaryColor: primaryColor,
              );
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // HÀM 1: GIAO DIỆN KHI CHƯA CÓ CUỘC HỘI THOẠI NÀO (Đã làm mới mát mắt hơn)
  // ===========================================================================
  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 52,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có cuộc hội thoại nào',
              style: TextStyle(
                color: Colors.blueGrey[800], 
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy sang tab Bạn bè để bắt đầu trò chuyện cùng mọi người nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey[400], 
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HÀM 2: BỘ PHÂN LOẠI & TẢI DỮ LIỆU PHÒNG CHAT (Giữ nguyên Logic xử lý gốc)
  // ===========================================================================
  Widget _buildChatRoomLoader({
    required BuildContext context,
    required ChatRoomModel room,
    required String currentUid,
    required List<UserModel> friendsList,
    required Color primaryColor,
  }) {
    // TH1: Nếu là nhóm chat
    if (room.isGroup) {
      return _buildChatTile(
        context: context,
        room: room,
        displayName: room.roomName,
        avatarUrl: room.roomAvatar,
        currentUid: currentUid,
        primaryColor: primaryColor,
      );
    }

    // TH2: Chat 1-1 -> Tìm UID đối phương
    final friendUid = room.participants.firstWhere(
      (id) => id != currentUid,
      orElse: () => '',
    );

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
        primaryColor: primaryColor,
      );
    }

    // TH3: Chat với người lạ -> Gọi UserProvider qua FutureBuilder
    return FutureBuilder<UserModel?>(
      future: context.read<UserProvider>().fetchUserById(friendUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 76,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor.withOpacity(0.5)),
                ),
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
            primaryColor: primaryColor,
          );
        }

        return _buildChatTile(
          context: context,
          room: room,
          displayName: 'Người dùng IrisChat',
          avatarUrl: '',
          currentUid: currentUid,
          primaryColor: primaryColor,
        );
      },
    );
  }

  // ===========================================================================
  // HÀM 3: RENDER Ô CHAT CHI TIẾT (Nâng cấp giao diện Hiện đại & Mát mẻ)
  // ===========================================================================
  Widget _buildChatTile({
    required BuildContext context,
    required ChatRoomModel room,
    required String displayName,
    required String avatarUrl,
    required String currentUid,
    required Color primaryColor,
  }) {
    final unreadCount = room.unreadCount[currentUid] ?? 0;
    final hasUnread = unreadCount > 0;
    final isRecalled = room.lastMessage == 'Tin nhắn đã bị thu hồi';

    // Giữ nguyên logic xử lý text hiển thị tin nhắn cuối
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.chat, arguments: room);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar thiết kế chỉn chu sắc nét
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: primaryColor.withOpacity(0.12),
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              
              // Cụm hiển thị Tên và Tin nhắn cuối cùng
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey[900],
                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      finalSubtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isRecalled
                            ? Colors.grey[400]
                            : (hasUnread ? Colors.black87 : Colors.blueGrey[400]),
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        fontStyle: isRecalled ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Cụm hiển thị Thời gian và Trạng thái chưa đọc (Màu mát)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(room.lastTimestamp),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: hasUnread ? primaryColor : Colors.grey[400],
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor, // Custom lại Badge màu Teal dịu mắt thay vì xanh Blue rực
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 18), // Giữ khoảng cách cân bằng khi không có badge
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HÀM 4: ĐỊNH DẠNG THỜI GIAN HIỂN THỊ (GIỮ NGUYÊN HOÀN TOÀN LOGIC)
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
