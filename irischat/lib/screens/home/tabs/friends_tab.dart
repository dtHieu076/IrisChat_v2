import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      friendshipProvider = context.read<FriendshipProvider>();

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

  // =========================================================
  // CREATE OR GET CHAT ROOM (1-1)
  // =========================================================
  ChatRoomModel _createRoom(UserModel friend) {
    final currentUid = widget.currentUser.uid;

    final roomId = (currentUid.hashCode <= friend.uid.hashCode)
        ? '${currentUid}_${friend.uid}'
        : '${friend.uid}_${currentUid}';

    return ChatRoomModel(
      roomId: roomId,
      roomName: friend.displayName,
      roomAvatar: friend.avatarUrl,
      isGroup: false,
      participants: [currentUid, friend.uid],
      lastMessage: '',
      lastSenderId: '',
      lastTimestamp: DateTime.now().millisecondsSinceEpoch,
      unreadCount: {},
      createdBy: currentUid,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Consumer<FriendshipProvider>(
      builder: (context, friendshipProvider, child) {
        return DefaultTabController(
          length: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // SEARCH
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm email bạn bè...',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () async {
                              final keyword = searchController.text.trim();
                              if (keyword.isEmpty) return;

                              await friendshipProvider.searchByEmail(
                                keyword: keyword,
                                currentUid: widget.currentUser.uid,
                              );
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      label: const Text("Tạo nhóm"),
                      icon: const Icon(Icons.group_add),
                      onPressed: () {
                        _showCreateGroupDialog();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // TAB BAR
                TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(
                      text:
                          'Đã nhận (${friendshipProvider.receivedRequests.length})',
                    ),
                    Tab(
                      text:
                          'Đã gửi (${friendshipProvider.sentRequests.length})',
                    ),
                    Tab(
                      text: 'Bạn bè (${friendshipProvider.friendsList.length})',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // TAB VIEW
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildReceivedTab(friendshipProvider),
                      _buildSentTab(friendshipProvider),
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

  // =========================================================
  // FRIENDS TAB (FIXED NAVIGATION)
  // =========================================================
  Widget _buildFriendsTab(FriendshipProvider provider) {
    if (provider.friendsList.isEmpty) {
      return const Center(child: Text("Chưa có bạn bè"));
    }

    return ListView.builder(
      itemCount: provider.friendsList.length,
      itemBuilder: (context, index) {
        final friend = provider.friendsList[index];

        return ListTile(
          leading: CircleAvatar(
            child: Text(friend.displayName[0].toUpperCase()),
          ),
          title: Text(friend.displayName),
          subtitle: Text(friend.email),

          trailing: IconButton(
            icon: const Icon(Icons.chat, color: Colors.blue),

            onPressed: () {
              final room = _createRoom(friend);

              Navigator.pushNamed(context, AppRoutes.chat, arguments: room);
            },
          ),
        );
      },
    );
  }

  // =========================================================
  Widget _buildReceivedTab(FriendshipProvider provider) {
    if (provider.receivedRequests.isEmpty) {
      return const Center(child: Text("Không có lời mời"));
    }

    return ListView.builder(
      itemCount: provider.receivedRequests.length,
      itemBuilder: (context, index) {
        final req = provider.receivedRequests[index];

        return ListTile(
          title: Text(req.senderEmail),
          subtitle: const Text("Lời mời kết bạn"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => provider.acceptRequest(req),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => provider.rejectRequest(req.requestId),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  Widget _buildSentTab(FriendshipProvider provider) {
    if (provider.sentRequests.isEmpty) {
      return const Center(child: Text("Chưa gửi lời mời"));
    }

    return ListView.builder(
      itemCount: provider.sentRequests.length,
      itemBuilder: (context, index) {
        final req = provider.sentRequests[index];

        return ListTile(
          title: Text(req.receiverId),
          subtitle: const Text("Đang chờ"),
          trailing: TextButton(
            onPressed: () => provider.cancelRequest(req.requestId),
            child: const Text("Hủy"),
          ),
        );
      },
    );
  }

  // Create group chat room (placeholder) =====================
  // =========================================================
  // FIX ĐOẠN ĐỐI THOẠI TẠO NHÓM Ở ĐÂY
  // =========================================================
  void _showCreateGroupDialog() {
    // 1. Khai báo các Controller và danh sách để lưu trữ dữ liệu đầu vào
    final TextEditingController groupNameController = TextEditingController();
    List<String> selectedFriendIds = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Tạo nhóm mới"),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: groupNameController, // Gán controller vào đây
                      decoration: const InputDecoration(
                        hintText: "Nhập tên nhóm...",
                        prefixIcon: Icon(Icons.group),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Chọn thành viên:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: friendshipProvider.friendsList.isEmpty
                          ? const Center(child: Text("Không có bạn bè để thêm"))
                          : ListView.builder(
                              itemCount: friendshipProvider.friendsList.length,
                              itemBuilder: (context, index) {
                                final friend =
                                    friendshipProvider.friendsList[index];

                                return CheckboxListTile(
                                  secondary: CircleAvatar(
                                    child: Text(
                                      friend.displayName.isNotEmpty
                                          ? friend.displayName[0].toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  title: Text(friend.displayName),
                                  value: selectedFriendIds.contains(friend.uid),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Hủy"),
                  onPressed: () {
                    groupNameController.dispose();
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton(
                  child: const Text("Tạo"),
                  onPressed: () async {
                    final name = groupNameController.text.trim();

                    // Validate dữ liệu đầu vào
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Vui lòng nhập tên nhóm")),
                      );
                      return;
                    }
                    if (selectedFriendIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vui lòng chọn ít nhất 1 người bạn"),
                        ),
                      );
                      return;
                    }

                    try {
                      // 2. Truyền chính xác các biến dữ liệu thực tế vào hàm của Provider
                      final room = await friendshipProvider.createGroupChatRoom(
                        currentUid: widget.currentUser.uid,
                        groupName: name,
                        friendIds: selectedFriendIds,
                      );

                      groupNameController.dispose();

                      if (context.mounted) {
                        Navigator.pop(context); // Đóng Dialog
                        // Chuyển hướng thẳng vào màn hình chat nhóm vừa tạo
                        Navigator.pushNamed(
                          context,
                          AppRoutes.chat,
                          arguments: room,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Lỗi tạo nhóm: $e")),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
