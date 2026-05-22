import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/friendship_provider.dart';
import 'package:irischat/routes/app_routes.dart';
import 'package:provider/provider.dart';

class FriendshipActionButton extends StatelessWidget {
  final UserModel targetUser;
  final UserModel currentUser;

  const FriendshipActionButton({
    super.key,
    required this.targetUser,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendshipProvider>();

    bool isFriend = provider.friendsList.any((f) => f.uid == targetUser.uid);
    bool hasSentRequest = provider.sentRequests.any(
      (r) => r.receiverId == targetUser.uid,
    );
    bool hasReceivedRequest = provider.receivedRequests.any(
      (r) => r.senderId == targetUser.uid,
    );

    // already friends -> message button
    if (isFriend) {
      return ElevatedButton.icon(
        onPressed: () {
          final room = ChatRoomModel.create1to1(
            currentUid: currentUser.uid,
            friendUid: targetUser.uid,
            friendName: targetUser.displayName,
            friendAvatar: targetUser.avatarUrl,
          );
          Navigator.pushNamed(context, AppRoutes.chat, arguments: room);
        },
        icon: const Icon(Icons.chat, size: 16),
        label: const Text("Chat"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Invetation sent -> disabled button
    if (hasSentRequest) {
      return const OutlinedButton(onPressed: null, child: Text("Request Sent"));
    }

    // Received friend request -> show accept button
    if (hasReceivedRequest) {
      return ElevatedButton(
        onPressed: () {
          final req = provider.receivedRequests.firstWhere(
            (r) => r.senderId == targetUser.uid,
          );
          provider.acceptRequest(req);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text("Accept"),
      );
    }

    // No relationship -> show add friend button
    return ElevatedButton.icon(
      onPressed: () async {
        try {
          await provider.sendFriendRequest(
            senderId: currentUser.uid,
            senderEmail: currentUser.email,
            receiverId: targetUser.uid,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Friend request sent!")),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error sending friend request: $e")),
            );
          }
        }
      },
      icon: const Icon(Icons.person_add, size: 16),
      label: const Text("Add Friend"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
