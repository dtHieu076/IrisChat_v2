import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/models/friend_model.dart';
import 'package:irischat/providers/friendship_provider.dart';
import 'package:irischat/providers/auth_provider.dart';

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
    final isOnline =
        !widget.room.isGroup && (widget.privateFriend?.isOnline ?? false);

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Nền xám nhạt tạo chiều sâu
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Conversation Info',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // ==========================================
                // 1. AVATAR & NAME SECTION
                // ==========================================
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ), // Border trắng làm nổi bật avatar
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                0.08,
                              ), // Bóng đổ mềm và sâu hơn
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.blue.shade50,
                          child: Text(
                            avatarLetter,
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ),
                      // Chấm xanh Online hiển thị trên góc Avatar
                      if (isOnline)
                        Positioned(
                          bottom: 2,
                          right: 6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isOnline
                        ? Colors.green.shade600
                        : Colors
                              .grey
                              .shade500, // Đổi màu text dựa theo trạng thái
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),

                // ==========================================
                // 2. ACTION BUTTONS ROW
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.room.isGroup) ...[
                        _buildActionButton(
                          icon: Icons.person_add_rounded,
                          label: 'Add\nMembers',
                          onTap: () {},
                        ),
                      ] else ...[
                        _buildActionButton(
                          icon: Icons.person_rounded,
                          label: 'Profile',
                          onTap: () {},
                        ),
                      ],
                      _buildActionButton(
                        icon: Icons.search_rounded,
                        label: 'Search',
                        onTap: () {},
                      ),
                      _buildActionButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Media',
                        onTap: () {},
                      ),
                      _buildActionButton(
                        icon: Icons.notifications_rounded,
                        label: 'Mute',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // ==========================================
                // 3. SETTINGS SECTIONS
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Nhóm Cài đặt chung
                      _buildSettingsGroup([
                        _buildSectionTile(
                          icon: Icons.edit_rounded,
                          title: 'Change Conversation Name',
                          onTap: () {},
                        ),
                        const Divider(
                          height: 1,
                          indent: 56,
                          color: Color(0xFFF0F0F0),
                        ),
                        _buildSectionTile(
                          icon: Icons.wallpaper_rounded,
                          title: 'Change Background',
                          onTap: () {},
                        ),
                      ]),

                      // Nhóm Thành viên (Group) / Thêm vào Group (1-1)
                      _buildSettingsGroup([
                        if (widget.room.isGroup)
                          _buildSectionTile(
                            icon: Icons.group_rounded,
                            title: 'View Members',
                            onTap: () {},
                          )
                        else
                          _buildSectionTile(
                            icon: Icons.group_add_rounded,
                            title: 'Add to Group',
                            onTap: () {},
                          ),
                      ]),

                      // Nhóm Hành động nguy hiểm (Block, Unfriend, Leave)
                      _buildSettingsGroup([
                        if (!widget.room.isGroup)
                          _buildSectionTile(
                            icon: isBlocked
                                ? Icons.check_circle_outline
                                : Icons.block_rounded,
                            title: isBlocked
                                ? (amITheBlocker
                                      ? 'Unblock User'
                                      : 'You are Blocked')
                                : 'Block User',
                            textColor: isBlocked
                                ? (amITheBlocker
                                      ? Colors.green.shade600
                                      : Colors.grey)
                                : Colors.red.shade600,
                            onTap: () {
                              if (isBlocked && !amITheBlocker) return;
                              _showBlockDialog(context, amITheBlocker);
                            },
                          ),
                        if (!widget.room.isGroup)
                          const Divider(
                            height: 1,
                            indent: 56,
                            color: Color(0xFFF0F0F0),
                          ),
                        if (widget.room.isGroup)
                          _buildSectionTile(
                            icon: Icons.logout_rounded,
                            title: 'Leave Group',
                            textColor: Colors.red.shade600,
                            onTap: () {},
                          )
                        else
                          _buildSectionTile(
                            icon: Icons.person_remove_rounded,
                            title: 'Unfriend',
                            textColor: Colors.red.shade600,
                            onTap: () => _showUnfriendDialog(context),
                          ),
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =======================================================
  // WIDGET HELPERS
  // =======================================================

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap, // Thêm hiệu ứng gợn sóng (Ripple Effect)
        splashColor: Colors.blue.withOpacity(0.1),
        highlightColor: Colors.blue.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: SizedBox(
            width: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.blue.shade700, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Góc bo tròn mượt mà hơn
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03), // Bóng đổ tệp với nền
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          20,
        ), // Giữ hiệu ứng ripple không bị tràn góc
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSectionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final color = textColor ?? Colors.blueGrey.shade800;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Bo góc vuông mềm mại
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =======================================================
  // DIALOG LOGICS (Không thay đổi)
  // =======================================================

  void _showBlockDialog(BuildContext screenContext, bool isUnblockAction) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isUnblockAction ? 'Unblock User' : 'Block User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isUnblockAction
              ? 'Do you want to unblock this user to resume conversation?'
              : 'Are you sure you want to block this user? Both of you won\'t be able to send messages.',
          style: TextStyle(color: Colors.grey.shade800),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(
              isUnblockAction ? 'Unblock' : 'Block',
              style: TextStyle(
                color: isUnblockAction
                    ? Colors.green.shade600
                    : Colors.red.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              if (widget.privateFriend == null || _currentUid.isEmpty) return;
              await screenContext.read<FriendshipProvider>().toggleBlock(
                currentUid: _currentUid,
                friendUid: widget.privateFriend!.uid,
                shouldBlock: !isUnblockAction,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Unfriend',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to unfriend this person?',
          style: TextStyle(color: Colors.grey.shade800),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(
              'Unfriend',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
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
