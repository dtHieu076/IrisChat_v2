import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/message_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/chat_provider.dart';

class ChatMessageListWidget extends StatelessWidget {
  final ScrollController scrollController;
  final String currentUid;
  final Map<String, UserModel> users;
  final ChatRoomModel room;
  final String? highlightedMessageId;

  // Các Callback xử lý sự kiện đẩy ngược về file mẹ
  final Function(MessageModel message, bool isMe) onMessageLongPress;
  final Function(MessageModel message) onMessageDoubleTap;
  final Function(MessageModel message) onReplyTap;

  const ChatMessageListWidget({
    super.key,
    required this.scrollController,
    required this.currentUid,
    required this.users,
    required this.room,
    required this.highlightedMessageId,
    required this.onMessageLongPress,
    required this.onMessageDoubleTap,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final messages = chatProvider.messages;

        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'Say hello to start the conversation!',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isMe = message.senderId == currentUid;
            final sender = users[message.senderId];

            // Phân tách ngày tháng dựa trên vị trí phần tử index
            bool showDateSeparator = false;
            if (index == messages.length - 1) {
              showDateSeparator = true;
            } else {
              final previousMessage =
                  messages[messages.length - 1 - (index + 1)];
              final currentDate = DateTime.fromMillisecondsSinceEpoch(
                message.timestamp,
              );
              final previousDate = DateTime.fromMillisecondsSinceEpoch(
                previousMessage.timestamp,
              );

              showDateSeparator =
                  currentDate.day != previousDate.day ||
                  currentDate.month != previousDate.month ||
                  currentDate.year != previousDate.year;
            }

            return GestureDetector(
              onLongPress: message.isDeleted
                  ? null
                  : () => onMessageLongPress(message, isMe),
              onDoubleTap: () => onMessageDoubleTap(message),
              child: Column(
                children: [
                  if (showDateSeparator) _buildDateSeparator(message.timestamp),
                  _buildMessageBubble(context, message, isMe, sender),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // CÁC HÀM BỔ TRỢ GIAO DIỆN (WIDGET COMPONENT HÀM THUẦN)
  // ===========================================================================

  Widget _buildDateSeparator(int timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _formatDate(timestamp),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    MessageModel message,
    bool isMe,
    UserModel? sender,
  ) {
    final bool isImageMessage =
        message.type == 'image' && message.mediaUrl != null;
    final bool isHighlighted = message.messageId == highlightedMessageId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: isImageMessage
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              // Đổi màu nền sang Vàng nhạt nhấp nháy khi được kích hoạt Highlight tính năng jump-to-reply
              color: isHighlighted
                  ? Colors.yellow.shade200
                  : (isImageMessage
                        ? Colors.white
                        : (isMe ? Colors.blueAccent : Colors.grey.shade200)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
              boxShadow: isImageMessage
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.isGroup)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      isMe ? 'You' : (sender?.displayName ?? 'User'),
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (message.replyToMessageId != null)
                  _buildReplyInBubble(message, isMe),
                _buildMessageContent(message, isMe),
                const SizedBox(height: 4),
                _buildMessageStatusRow(message, isMe),
              ],
            ),
          ),
          if (message.reactions != null && message.reactions!.isNotEmpty)
            _buildReactions(message, isMe),
        ],
      ),
    );
  }

  Widget _buildReplyInBubble(MessageModel message, bool isMe) {
    final replySenderName = message.replySenderId == currentUid
        ? 'You'
        : (users[message.replySenderId]?.displayName ?? 'User');

    return GestureDetector(
      onTap: () =>
          onReplyTap(message), // Kích hoạt callback khi nhấn vào khung reply
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replySenderName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              (message.replyText?.isNotEmpty == true)
                  ? message.replyText!
                  : '[Message unavailable]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMe) {
    if (message.isDeleted) {
      return Text(
        isMe ? 'You recalled a message' : 'This message was recalled',
        style: TextStyle(
          color: isMe ? Colors.white70 : Colors.black45,
          fontStyle: FontStyle.italic,
        ),
      );
    } else if (message.type == 'image' && message.mediaUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              message.mediaUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 40),
            ),
          ),
          if (message.text.isNotEmpty) _buildCaptionText(message.text, isMe),
        ],
      );
    } else if (message.type == 'file') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file,
                color: isMe ? Colors.white : Colors.blue,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.fileName ?? 'File',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          if (message.text.isNotEmpty) _buildCaptionText(message.text, isMe),
        ],
      );
    }

    return Text(
      message.text,
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black87,
        fontSize: 15,
      ),
    );
  }

  Widget _buildCaptionText(String text, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMessageStatusRow(MessageModel message, bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            color: isMe ? Colors.white70 : Colors.black45,
            fontSize: 10,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.status == 'read' ? Icons.done_all : Icons.done,
            size: 14,
            color: message.status == 'read'
                ? Colors.lightBlueAccent
                : Colors.white70,
          ),
        ],
      ],
    );
  }

  Widget _buildReactions(MessageModel message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: message.reactions!.values
              .toSet()
              .map(
                (emoji) => Text(
                  emoji.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }
}
