import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
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
    return Consumer<FriendshipProvider>(
      builder: (context, friendshipProvider, child) {
        return DefaultTabController(
          length: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search friends by email...',
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
                      label: const Text("Create Group"),
                      icon: const Icon(Icons.group_add),
                      onPressed: () {
                        _showCreateGroupDialog();
                      },
                    ),
                  ],
                ),

                // Post-search result card
                if (friendshipProvider.searchedUser != null) ...[
                  const SizedBox(height: 16),
                  _buildSearchResultCard(friendshipProvider),
                ],

                const SizedBox(height: 16),

                TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(
                      text:
                          'Received (${friendshipProvider.receivedRequests.length})',
                    ),
                    Tab(
                      text:
                          'Sent (${friendshipProvider.sentRequests.length})',
                    ),
                    Tab(
                      text: 'Friends (${friendshipProvider.friendsList.length})',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

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

  Widget _buildSearchResultCard(FriendshipProvider provider) {
    final searchedUser = provider.searchedUser!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: searchedUser.avatarUrl.isNotEmpty
                  ? NetworkImage(searchedUser.avatarUrl)
                  : null,
              child: searchedUser.avatarUrl.isEmpty
                  ? Text(searchedUser.displayName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    searchedUser.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    searchedUser.email,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            FriendshipActionButton(
              targetUser: searchedUser,
              currentUser: widget.currentUser,
            ),

            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () {
                provider.clearSearch();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(FriendshipProvider provider) {
    if (provider.friendsList.isEmpty) {
      return const Center(child: Text("No friends yet"));
    }

    return ListView.builder(
      itemCount: provider.friendsList.length,
      itemBuilder: (context, index) {
        final friend = provider.friendsList[index];

        return ListTile(
          leading: CircleAvatar(
            child: Text(
              friend.displayName.isNotEmpty
                  ? friend.displayName[0].toUpperCase()
                  : '?',
            ),
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

  Widget _buildReceivedTab(FriendshipProvider provider) {
    if (provider.receivedRequests.isEmpty) {
      return const Center(child: Text("No pending requests"));
    }

    return ListView.builder(
      itemCount: provider.receivedRequests.length,
      itemBuilder: (context, index) {
        final req = provider.receivedRequests[index];

        return ListTile(
          title: Text(req.senderEmail),
          subtitle: const Text("Friend request"),
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

  Widget _buildSentTab(FriendshipProvider provider) {
    if (provider.sentRequests.isEmpty) {
      return const Center(child: Text("No sent requests"));
    }

    return ListView.builder(
      itemCount: provider.sentRequests.length,
      itemBuilder: (context, index) {
        final req = provider.sentRequests[index];

        return ListTile(
          title: Text(req.receiverId),
          subtitle: const Text("Pending"),
          trailing: TextButton(
            onPressed: () => provider.cancelRequest(req.requestId),
            child: const Text("Cancel"),
          ),
        );
      },
    );
  }

  void _showCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    List<String> selectedFriendIds = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Create New Group"),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: groupNameController,
                      decoration: const InputDecoration(
                        hintText: "Enter group name...",
                        prefixIcon: Icon(Icons.group),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Select members:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: friendshipProvider.friendsList.isEmpty
                          ? const Center(child: Text("No friends to add"))
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
                  child: const Text("Cancel"),
                  onPressed: () {
                    groupNameController.dispose();
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton(
                  child: const Text("Create"),
                  onPressed: () async {
                    final name = groupNameController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a group name")),
                      );
                      return;
                    }
                    if (selectedFriendIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select at least 1 friend"),
                        ),
                      );
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error creating group: $e")),
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
