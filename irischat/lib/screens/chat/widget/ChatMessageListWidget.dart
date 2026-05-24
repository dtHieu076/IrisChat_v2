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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'Say hello to start the conversation!',
                  style: TextStyle(
                    color: Colors.blueGrey[300],
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isMe = message.senderId == currentUid;
            final sender = users[message.senderId];

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
  // DATE SEPARATOR (Đường chia ngày thiết kế tối giản)
  // ===========================================================================
  Widget _buildDateSeparator(int timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(timestamp),
            style: TextStyle(
              color: Colors.blueGrey[400],
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MESSAGE BUBBLE (Bóng chat cao cấp, bo góc mượt)
  // ===========================================================================
  Widget _buildMessageBubble(
    BuildContext context,
    MessageModel message,
    bool isMe,
    UserModel? sender,
  ) {
    final bool isImageMessage =
        message.type == 'image' && message.mediaUrl != null;
    final bool isHighlighted = message.messageId == highlightedMessageId;
    final themeColor = Colors.teal[600]!;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Hiển thị tên thành viên nếu là Group Chat
            if (room.isGroup && !isMe)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 3),
                child: Text(
                  sender?.displayName ?? 'User',
                  style: TextStyle(
                    color: Colors.blueGrey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Khối nội dung bong bóng chính
            Container(
              padding: isImageMessage
                  ? (message.text.isNotEmpty
                        ? const EdgeInsets.all(4)
                        : EdgeInsets.zero)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: isHighlighted
                    ? LinearGradient(
                        colors: [Colors.amber.shade100, Colors.amber.shade50],
                      )
                    : (isMe
                          ? LinearGradient(
                              colors: [
                                themeColor,
                                themeColor.withValues(alpha: 0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF1F5F9), Color(0xFFF1F5F9)],
                            )),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isMe ? 0.04 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.73,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyToMessageId != null)
                    _buildReplyInBubble(message, isMe),
                  _buildMessageContent(message, isMe),
                  const SizedBox(height: 3),
                  _buildMessageStatusRow(message, isMe),
                ],
              ),
            ),

            // Khu vực thả cảm xúc (Reactions) dưới bóng chat
            if (message.reactions != null && message.reactions!.isNotEmpty)
              _buildReactions(message, isMe),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // REPLY IN BUBBLE (Trích dẫn tin nhắn cũ lồng trong bóng chat)
  // ===========================================================================
  Widget _buildReplyInBubble(MessageModel message, bool isMe) {
    final replySenderName = message.replySenderId == currentUid
        ? 'You'
        : (users[message.replySenderId]?.displayName ?? 'User');

    return GestureDetector(
      onTap: () => onReplyTap(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white70 : Colors.teal.shade400,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replySenderName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isMe ? Colors.white : Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              (message.replyText?.isNotEmpty == true)
                  ? message.replyText!
                  : '[Message unavailable]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.blueGrey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CONTENT BUILDERS (Hình ảnh, Tập tin, Văn bản)
  // ===========================================================================
  Widget _buildMessageContent(MessageModel message, bool isMe) {
    if (message.isDeleted) {
      return Text(
        isMe ? 'You recalled a message' : 'This message was recalled',
        style: TextStyle(
          color: isMe ? Colors.white.withValues(alpha: 0.6) : Colors.grey[400],
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
      );
    }

    // Tin nhắn Dạng Hình ảnh
    if (message.type == 'image' && message.mediaUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              message.mediaUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 160,
                  width: 200,
                  color: Colors.grey[100],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isMe ? Colors.white54 : Colors.teal,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey[100],
                child: const Icon(
                  Icons.broken_image_outlined,
                  size: 36,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          if (message.text.isNotEmpty) _buildCaptionText(message.text, isMe),
        ],
      );
    }

    // Tin nhắn Dạng File đính kèm
    if (message.type == 'file') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isMe ? null : Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.teal.shade50,
                  child: Icon(
                    Icons.description_rounded,
                    size: 18,
                    color: isMe ? Colors.white : Colors.teal[600],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message.fileName ?? 'Tập tin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.blueGrey[800],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.text.isNotEmpty) _buildCaptionText(message.text, isMe),
        ],
      );
    }

    // Tin nhắn Văn bản thường
    return Text(
      message.text,
      style: TextStyle(
        color: isMe ? Colors.white : Colors.blueGrey[900],
        fontSize: 15,
        height: 1.3,
      ),
    );
  }

  Widget _buildCaptionText(String text, bool isMe) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Text(
        text,
        style: TextStyle(
          color: isMe
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.blueGrey[800],
          fontSize: 14,
        ),
      ),
    );
  }

  // ===========================================================================
  // STATUS ROW (Thời gian nhận & Icon tích xanh đôi nhận diện trạng thái)
  // ===========================================================================
  Widget _buildMessageStatusRow(MessageModel message, bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 24), // Tạo khoảng trống tối thiểu tránh đè chữ
        Text(
          _formatTime(message.timestamp),
          style: TextStyle(
            color: isMe
                ? Colors.white.withValues(alpha: 0.65)
                : Colors.blueGrey[300],
            fontSize: 9.5,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.status == 'read'
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 13,
            color: message.status == 'read'
                ? Colors.cyan[200]
                : Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // REACTIONS (Hiển thị biểu tượng cảm xúc bong bóng chồng góc)
  // ===========================================================================
  Widget _buildReactions(MessageModel message, bool isMe) {
    return Transform.translate(
      offset: Offset(isMe ? -4 : 4, -5), // Tạo độ nhô đè lên thành bóng chat
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: message.reactions!.values
              .toSet()
              .map(
                (emoji) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    emoji.toString(),
                    style: const TextStyle(fontSize: 11),
                  ),
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
