import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/message_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final ChatRoomModel room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? currentUid;
  final Map<String, UserModel> users = {};
  MessageModel? _replyingMessage;

  UserModel? privateFriend;

  @override
  void initState() {
    super.initState();

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    currentUid = user.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Vào phòng chat
      context.read<ChatProvider>().enterChatRoom(
        roomId: widget.room.roomId,
        currentUid: currentUid!,
      );

      // Tải thông tin các thành viên một lần duy nhất tại initState
      final userProvider = context.read<UserProvider>();
      for (final uid in widget.room.participants) {
        if (uid == currentUid) continue;

        final fetched = await userProvider.fetchUserById(uid);
        if (fetched != null) {
          users[uid] = fetched;
        }
      }

      // THỐNG NHẤT: Xác định privateFriend ngay sau khi fetch xong data
      if (!widget.room.isGroup) {
        final friendUid = widget.room.participants.firstWhere(
          (id) => id != currentUid,
          orElse: () => '',
        );
        privateFriend = users[friendUid];
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    try {
      context.read<ChatProvider>().leaveChatRoom();
    } catch (_) {}
    super.dispose();
  }

  void _onSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUid == null) return;

    final chatProvider = context.read<ChatProvider>();

    if (_replyingMessage != null) {
      chatProvider.sendReplyMessage(
        roomId: widget.room.roomId,
        currentUid: currentUid!,
        text: text,
        replyToMessageId: _replyingMessage!.messageId,
        replyText: _replyingMessage!.text.isNotEmpty
            ? _replyingMessage!.text
            : (_replyingMessage!.type == 'image' ? '[Image]' : '[File]'),
        replySenderId: _replyingMessage!.senderId,
      );

      setState(() {
        _replyingMessage = null;
      });
    } else {
      chatProvider.sendTextMessage(
        roomId: widget.room.roomId,
        currentUid: currentUid!,
        text: text,
      );
    }

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null || currentUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            _buildChatTitleInfo(),
            const Spacer(),
            _buildMenuButton(),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildSendingIndicator(),
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingMessage != null) _buildReplyPreview(),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    String initial = 'U';
    if (widget.room.isGroup) {
      initial = widget.room.roomName.isNotEmpty
          ? widget.room.roomName[0].toUpperCase()
          : 'G';
    } else if (privateFriend?.displayName.isNotEmpty == true) {
      initial = privateFriend!.displayName[0].toUpperCase();
    }

    return CircleAvatar(
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.room.isGroup
              ? widget.room.roomName
              : (privateFriend?.displayName ?? 'User'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        widget.room.isGroup
            ? const Text(
                'Group Chat',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            : Row(
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
                      fontWeight: isOnline
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildMenuButton() {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () {
        Navigator.pushNamed(
          context,
          '/chat-room-info',
          arguments: {'room': widget.room, 'privateFriend': privateFriend},
        );
      },
    );
  }

  Widget _buildMessageList() {
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
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isMe = message.senderId == currentUid;
            final sender = users[message.senderId];

            // Logic tính toán DateSeparator được giữ lại ở đây vì nó phụ thuộc vào vị trí phần tử index
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
                  : () => _showMessageActions(message, isMe),
              onDoubleTap: () => setState(() => _replyingMessage = message),
              child: Column(
                children: [
                  if (showDateSeparator) _buildDateSeparator(message.timestamp),
                  _buildMessageBubble(message, isMe, sender),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMessageActions(MessageModel message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // =========================
              // REACTION BAR
              // =========================
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _reactionButton(message, '❤️'),
                    _reactionButton(message, '👍'),
                    _reactionButton(message, '😂'),
                    _reactionButton(message, '😮'),
                    _reactionButton(message, '😢'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =========================
              // ACTIONS
              // =========================
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _actionButton(
                    icon: Icons.reply,
                    label: 'Reply',
                    onTap: () {
                      Navigator.pop(context);

                      setState(() {
                        _replyingMessage = message;
                      });
                    },
                  ),

                  _actionButton(
                    icon: Icons.copy,
                    label: 'Copy',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  _actionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  if (isMe)
                    _actionButton(
                      icon: Icons.undo,
                      label: 'Recall',
                      onTap: () async {
                        Navigator.pop(context);
                        await context.read<ChatProvider>().recallMessage(
                          roomId: widget.room.roomId,
                          messageId: message.messageId,
                        );
                      },
                    ),

                  if (isMe)
                    _actionButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _reactionButton(MessageModel message, String emoji) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        Navigator.pop(context);

        context.read<ChatProvider>().toggleReaction(
          roomId: widget.room.roomId,
          messageId: message.messageId,
          currentUid: currentUid!,
          emoji: emoji,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              child: Icon(icon, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

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
    MessageModel message,
    bool isMe,
    UserModel? sender,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.grey.shade200,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.room.isGroup)
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

    return Container(
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

  Widget _buildSendingIndicator() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (!chatProvider.isSending) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Sending...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Icon(Icons.reply, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Replying...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  _replyingMessage!.text.isNotEmpty
                      ? _replyingMessage!.text
                      : (_replyingMessage!.type == 'image'
                            ? '[Image]'
                            : '[File]'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyingMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image, color: Colors.blue),
            onPressed: () => _pickAndSendMedia('image'),
          ),
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.blue),
            onPressed: () => _pickAndSendMedia('file'),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Enter a message...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _onSendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendMedia(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: type == 'image' ? FileType.image : FileType.any,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      if (!mounted) return;
      context.read<ChatProvider>().uploadAndSendMedia(
        roomId: widget.room.roomId,
        currentUid: currentUid!,
        type: type,
        fileBytes: result.files.single.bytes!,
        fileName: result.files.single.name,
        fileSize: result.files.single.size,
      );
    }
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
