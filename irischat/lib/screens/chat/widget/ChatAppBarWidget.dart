import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/auth_provider.dart';
import 'package:irischat/providers/call_provider.dart';
import 'package:provider/provider.dart';

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
    return const Size.fromHeight(kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      titleSpacing: 12,

      title: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(child: _buildChatTitleInfo()),
        ],
      ),

      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: onSearchPressed),
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: () async {
            final currentUid = context.read<AuthProvider>().user!.uid;
            final callProvider = context.read<CallProvider>();

            await callProvider.startCall(
              callerId: currentUid,
              receiverId: privateFriend!.uid,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/chat-room-info',
              arguments: {'room': room, 'privateFriend': privateFriend},
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    String initial = 'U';

    if (room.isGroup) {
      initial = room.roomName.isNotEmpty ? room.roomName[0].toUpperCase() : 'G';
    } else if (privateFriend?.displayName.isNotEmpty == true) {
      initial = privateFriend!.displayName[0].toUpperCase();
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChatTitleInfo() {
    final isOnline = privateFriend?.isOnline ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          room.isGroup ? room.roomName : (privateFriend?.displayName ?? 'User'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 2),

        if (room.isGroup)
          const Text(
            'Group Chat',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: isOnline ? Colors.green : Colors.grey,
                  fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
