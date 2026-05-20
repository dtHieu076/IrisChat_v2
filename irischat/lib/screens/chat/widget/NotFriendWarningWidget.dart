import 'package:flutter/material.dart';
import 'package:irischat/providers/auth_provider.dart';
import 'package:irischat/screens/home/widget/friendship_action_button.dart';
import 'package:provider/provider.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/friendship_provider.dart';

class NotFriendWarningWidget extends StatelessWidget {
  final ChatRoomModel room;
  final UserModel? privateFriend;

  const NotFriendWarningWidget({
    super.key,
    required this.room,
    required this.privateFriend,
  });

  @override
  Widget build(BuildContext context) {
    if (room.isGroup || privateFriend == null) {
      return const SizedBox.shrink();
    }

    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;

    if (currentUser == null) return const SizedBox.shrink();

    final friendshipProvider = context.watch<FriendshipProvider>();
    final isFriend = friendshipProvider.friendsList.any(
      (user) => user.uid == privateFriend!.uid,
    );

    // If they are already friends, no need to show warning
    if (isFriend) {
      return const SizedBox.shrink();
    }

    // Not friends -> show warning with action button
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are not friends with ${privateFriend!.displayName}.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: FriendshipActionButton(
              targetUser: privateFriend!,
              currentUser: currentUser,
            ),
          ),
        ],
      ),
    );
  }
}
