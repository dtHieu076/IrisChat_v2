import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/chat_provider.dart';
import 'package:irischat/providers/user_provider.dart';
import 'package:irischat/screens/home/widget/friendship_action_button.dart';
import 'package:provider/provider.dart';

import '../../../providers/friendship_provider.dart';
import '../../../routes/app_routes.dart';

class FriendsTab extends StatefulWidget {
  final UserModel currentUser;
  const FriendsTab({super.key, required this.currentUser});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final TextEditingController searchController = TextEditingController();
  late FriendshipProvider friendshipProvider;
  late UserProvider userProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      friendshipProvider = context.read<FriendshipProvider>();
      userProvider = context.read<UserProvider>();

      friendshipProvider.listenReceivedRequests(widget.currentUser.uid);
      friendshipProvider.listenSentRequests(widget.currentUser.uid);
      friendshipProvider.listenFriends(widget.currentUser.uid);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // CREATE OR GET CHAT ROOM (1-1)
  ChatRoomModel _createRoom(UserModel friend) {
    return ChatRoomModel.create1to1(
      currentUid: widget.currentUser.uid,
      friendUid: friend.uid,
      friendName: friend.displayName,
      friendAvatar: friend.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchedUserProvider = context.watch<UserProvider>();
    return Consumer<FriendshipProvider>(
      builder: (context, friendshipProvider, child) {
        return DefaultTabController(
          length: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Thanh công cụ: Tìm kiếm & Tạo nhóm
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo email...',
                          hintStyle: TextStyle(color: Colors.blueGrey.shade300),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: IconButton(
                              icon: const Icon(Icons.search_rounded),
                              color: Colors.teal.shade500,
                              onPressed: () async {
                                final keyword = searchController.text.trim();
                                if (keyword.isEmpty) return;

                                await friendshipProvider.searchByEmail(
                                  keyword: keyword,
                                  currentUid: widget.currentUser.uid,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        _showCreateGroupDialog();
                      },
                      child: const Icon(Icons.group_add_rounded, size: 22),
                    ),
                  ],
                ),

                // Thẻ hiển thị kết quả tìm kiếm
                if (friendshipProvider.searchedUser != null) ...[
                  const SizedBox(height: 16),
                  _buildSearchResultCard(friendshipProvider),
                ],

                const SizedBox(height: 20),

                // TabBar bo góc hiện đại
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Colors.teal.shade700,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    unselectedLabelColor: Colors.blueGrey.shade400,
                    tabs: [
                      Tab(
                        text:
                            'Nhận (${friendshipProvider.receivedRequests.length})',
                      ),
                      Tab(
                        text: 'Gửi (${friendshipProvider.sentRequests.length})',
                      ),
                      Tab(
                        text:
                            'Bạn bè (${friendshipProvider.friendsList.length})',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Nội dung các Tabs
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildReceivedTab(
                        friendshipProvider,
                        watchedUserProvider,
                      ),
                      _buildSentTab(friendshipProvider, watchedUserProvider),
                      _buildFriendsTab(friendshipProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // WIDGET KẾT QUẢ TÌM KIẾM
  // ===========================================================================
  Widget _buildSearchResultCard(FriendshipProvider provider) {
    final searchedUser = provider.searchedUser!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.teal.shade50,
            backgroundImage: searchedUser.avatarUrl.isNotEmpty
                ? NetworkImage(searchedUser.avatarUrl)
                : null,
            child: searchedUser.avatarUrl.isEmpty
                ? Text(
                    searchedUser.displayName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  searchedUser.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  searchedUser.email,
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FriendshipActionButton(
            targetUser: searchedUser,
            currentUser: widget.currentUser,
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: Colors.blueGrey.shade300,
            ),
            onPressed: () => provider.clearSearch(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB DANH SÁCH BẠN BÈ
  // ===========================================================================
  Widget _buildFriendsTab(FriendshipProvider provider) {
    if (provider.friendsList.isEmpty) {
      return _buildEmptyState(Icons.people_alt_outlined, "Chưa có bạn bè nào");
    }

    return ListView.builder(
      itemCount: provider.friendsList.length,
      itemBuilder: (context, index) {
        final friend = provider.friendsList[index];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.teal.shade50,
            child: Text(
              friend.displayName.isNotEmpty
                  ? friend.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Colors.teal.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            friend.displayName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade900,
            ),
          ),
          subtitle: Text(
            friend.email,
            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
          ),
          trailing: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.chat_rounded,
                color: Colors.blue,
                size: 20,
              ),
              onPressed: () async {
                final chatProvider = context.read<ChatProvider>();
                final room = await chatProvider.create1to1Room(
                  currentUser: widget.currentUser,
                  friend: friend,
                );
                if (!context.mounted) return;
                Navigator.pushNamed(context, AppRoutes.chat, arguments: room);
              },
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB LỜI MỜI KẾT BẠN (NHẬN)
  // ===========================================================================
  Widget _buildReceivedTab(
    FriendshipProvider provider,
    UserProvider uProvider,
  ) {
    if (provider.receivedRequests.isEmpty) {
      return _buildEmptyState(
        Icons.inbox_rounded,
        "Không có lời mời kết bạn nào",
      );
    }

    return ListView.builder(
      itemCount: provider.receivedRequests.length,
      itemBuilder: (context, index) {
        final req = provider.receivedRequests[index];
        final senderName = uProvider.getDisplayNameFromCache(req.senderId);
        final senderAvatar = uProvider.getAvatarUrlFromCache(req.senderId);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.teal.shade50,
            backgroundImage: senderAvatar != null && senderAvatar.isNotEmpty
                ? NetworkImage(senderAvatar)
                : null,
            child: senderAvatar == null || senderAvatar.isEmpty
                ? Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  )
                : null,
          ),
          title: Text(
            senderName.isNotEmpty ? senderName : req.senderEmail,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Đã gửi lời mời kết bạn",
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTonalButton(
                icon: Icons.check_rounded,
                color: Colors.green,
                onTap: () {
                  provider.acceptRequest(
                    request: req,
                    currentUid: widget.currentUser.uid,
                    friendName: senderName,
                    friendAvatar: senderAvatar ?? '',
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildTonalButton(
                icon: Icons.close_rounded,
                color: Colors.red,
                onTap: () => provider.rejectRequest(req.requestId),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB LỜI MỜI ĐÃ GỬI
  // ===========================================================================
  Widget _buildSentTab(FriendshipProvider provider, UserProvider uProvider) {
    if (provider.sentRequests.isEmpty) {
      return _buildEmptyState(Icons.send_rounded, "Bạn chưa gửi lời mời nào");
    }

    return ListView.builder(
      itemCount: provider.sentRequests.length,
      itemBuilder: (context, index) {
        final req = provider.sentRequests[index];
        final displayName = uProvider.getDisplayNameFromCache(req.receiverId);
        final avatarUrl = uProvider.getAvatarUrlFromCache(req.receiverId);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.teal.shade50,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  )
                : null,
          ),
          title: Text(
            displayName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Đang chờ xác nhận...",
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
            ),
          ),
          trailing: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              foregroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => provider.cancelRequest(req.requestId),
            child: const Text(
              "Hủy",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DIALOG TẠO NHÓM
  // ===========================================================================
  void _showCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    List<String> selectedFriendIds = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "Tạo Nhóm Mới",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: groupNameController,
                      decoration: InputDecoration(
                        hintText: "Nhập tên nhóm...",
                        hintStyle: TextStyle(color: Colors.blueGrey.shade300),
                        prefixIcon: Icon(
                          Icons.group_rounded,
                          color: Colors.teal.shade500,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Chọn thành viên:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: friendshipProvider.friendsList.isEmpty
                          ? Center(
                              child: Text(
                                "Chưa có bạn bè để thêm",
                                style: TextStyle(
                                  color: Colors.blueGrey.shade300,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.separated(
                                itemCount:
                                    friendshipProvider.friendsList.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade100,
                                ),
                                itemBuilder: (context, index) {
                                  final friend =
                                      friendshipProvider.friendsList[index];
                                  final isSelected = selectedFriendIds.contains(
                                    friend.uid,
                                  );

                                  return CheckboxListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    activeColor: Colors.teal.shade600,
                                    checkboxShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    secondary: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isSelected
                                          ? Colors.teal.shade100
                                          : Colors.grey.shade100,
                                      child: Text(
                                        friend.displayName.isNotEmpty
                                            ? friend.displayName[0]
                                                  .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.teal.shade800
                                              : Colors.blueGrey.shade500,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      friend.displayName,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: Colors.blueGrey.shade900,
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selectedFriendIds.add(friend.uid);
                                        } else {
                                          selectedFriendIds.remove(friend.uid);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () {
                    groupNameController.dispose();
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Hủy",
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final name = groupNameController.text.trim();
                    if (name.isEmpty) {
                      _showSnackBar("Vui lòng nhập tên nhóm");
                      return;
                    }
                    if (selectedFriendIds.isEmpty) {
                      _showSnackBar("Vui lòng chọn ít nhất 1 thành viên");
                      return;
                    }

                    try {
                      final room = await friendshipProvider.createGroupChatRoom(
                        currentUid: widget.currentUser.uid,
                        groupName: name,
                        friendIds: selectedFriendIds,
                      );
                      groupNameController.dispose();

                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.chat,
                          arguments: room,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) _showSnackBar("Lỗi tạo nhóm: $e");
                    }
                  },
                  child: const Text(
                    "Tạo Nhóm",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================

  // Nút trạng thái mờ (Tonal Button)
  Widget _buildTonalButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  // Trạng thái trống (Empty State)
  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.blueGrey.shade100),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.blueGrey.shade400,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
