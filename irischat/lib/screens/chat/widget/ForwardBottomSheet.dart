import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/message_model.dart';
import 'package:irischat/providers/chat_provider.dart';
import 'package:irischat/providers/user_provider.dart';
import 'package:provider/provider.dart';

class ForwardBottomSheet extends StatefulWidget {
  final MessageModel originalMessage;
  final String currentUid; // UID của chính bạn

  const ForwardBottomSheet({
    super.key,
    required this.originalMessage,
    required this.currentUid,
  });

  @override
  State<ForwardBottomSheet> createState() => _ForwardBottomSheetState();
}

class _ForwardBottomSheetState extends State<ForwardBottomSheet> {
  final List<String> _selectedRoomIds = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height:
          MediaQuery.of(context).size.height *
          0.65, // Tăng nhẹ chiều cao để list thoáng hơn
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Forward message to...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const Divider(),

          // Danh sách phòng chat
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final rooms = chatProvider.chatRooms;

                if (rooms.isEmpty) {
                  return const Center(child: Text('No active chat rooms.'));
                }

                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final isSelected = _selectedRoomIds.contains(room.roomId);

                    return _buildRoomTile(room, isSelected);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Nút bấm gửi đi
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _selectedRoomIds.isEmpty
                  ? null
                  : () async {
                      final chatProvider = context.read<ChatProvider>();
                      Navigator.pop(context);

                      await chatProvider.forwardMessageSimple(
                        originalMessage: widget.originalMessage,
                        targetRoomIds: _selectedRoomIds,
                        currentUid: widget.currentUid,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message forwarded successfully!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: const Text(
                'Send',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget xử lý hiển thị Tên, Avatar động cho từng phòng chat
  Widget _buildRoomTile(ChatRoomModel room, bool isSelected) {
    UserProvider userProvider = context.read<UserProvider>();

    String displayName = '';
    Widget avatarWidget;

    // Kiểm tra xem phòng là Group hay Private dựa trên dữ liệu của bạn
    // (Giả định: room.isGroup == true HOẶC kiểm tra room.roomName != null)
    final isGroupChat = room.roomName != null && room.roomName!.isNotEmpty;

    if (isGroupChat) {
      // 1. Xử lý hiển thị cho GROUP CHAT
      displayName = room.roomName!;
      avatarWidget = CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: const Icon(Icons.group, color: Colors.blue),
      );
    } else {
      // 2. Xử lý hiển thị cho PRIVATE CHAT
      final otherUserId = room.participants.firstWhere(
        (id) => id != widget.currentUid,
        orElse: () => 'User',
      );

      // Thay thế dòng này bằng trường chứa tên thật của bạn bè trong ChatRoomModel của bạn (ví dụ: room.otherUserName)
      displayName = userProvider.getDisplayNameFromCache(otherUserId);

      avatarWidget = CircleAvatar(
        backgroundColor: Colors.orange.shade100,
        child: const Icon(Icons.person, color: Colors.orange),
      );
    }

    // Sử dụng InkWell kết hợp Row để tự chế CheckboxListTile có custom Avatar đẹp hơn
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedRoomIds.remove(room.roomId);
          } else {
            _selectedRoomIds.add(room.roomId);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            avatarWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Checkbox(
              value: isSelected,
              activeColor: Theme.of(context).primaryColor,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedRoomIds.add(room.roomId);
                  } else {
                    _selectedRoomIds.remove(room.roomId);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
