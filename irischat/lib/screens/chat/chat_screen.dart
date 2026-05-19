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

  @override
  void initState() {
    super.initState();

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    currentUid = user.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<ChatProvider>().enterChatRoom(
        roomId: widget.room.roomId,
        currentUid: currentUid!,
      );

      final userProvider = context.read<UserProvider>();

      for (final uid in widget.room.participants) {
        if (uid == currentUid) continue;

        final fetched = await userProvider.fetchUserById(uid);
        if (fetched != null) {
          users[uid] = fetched;
        }
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
    if (text.isEmpty) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final uid = user.uid;
    final chatProvider = context.read<ChatProvider>();

    if (_replyingMessage != null) {
      // 1. Send a reply message with reference to the original message
      chatProvider.sendReplyMessage(
        roomId: widget.room.roomId,
        currentUid: uid,
        text: text,
        replyToMessageId: _replyingMessage!.messageId,
        replyText: _replyingMessage!.text.isNotEmpty
            ? _replyingMessage!.text
            : (_replyingMessage!.type == 'image' ? '[Image]' : '[File]'),
        replySenderId: _replyingMessage!.senderId,
      );

      // 2. Remove the reply status after successfully sending the reply message
      setState(() {
        _replyingMessage = null;
      });
    } else {
      // 3. Send a normal text message
      chatProvider.sendTextMessage(
        roomId: widget.room.roomId,
        currentUid: uid,
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

    final uid = currentUid!;

    // CHAT 1-1
    UserModel? privateFriend;

    if (!widget.room.isGroup) {
      final friendUid = widget.room.participants.firstWhere(
        (id) => id != uid,
        orElse: () => '',
      );

      privateFriend = users[friendUid];
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                widget.room.isGroup
                    ? widget.room.roomName[0].toUpperCase()
                    : (privateFriend?.displayName.isNotEmpty == true
                          ? privateFriend!.displayName[0].toUpperCase()
                          : 'U'),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.room.isGroup
                      ? widget.room.roomName
                      : privateFriend?.displayName ?? 'User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                              color: privateFriend?.isOnline ?? false
                                  ? Colors.green
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),

                          const SizedBox(width: 6),

                          Text(
                            privateFriend?.isOnline ?? false
                                ? 'Online'
                                : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              color: privateFriend?.isOnline ?? false
                                  ? Colors.green
                                  : Colors.grey,
                              fontWeight: privateFriend?.isOnline ?? false
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
            const Spacer(),
            // tree-dot menu button
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/chat-room-info',
                  arguments: {
                    'room': widget.room,
                    'privateFriend': privateFriend,
                  },
                );
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
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

                    final isMe = message.senderId == uid;

                    final isGroup = widget.room.isGroup;

                    // User sending this message
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

                    // Wrap with GestureDetector to capture Reaction/Reply events
                    return GestureDetector(
                      onLongPress: () {
                        // Press and hold to toggle "❤️" reaction for this message
                        context.read<ChatProvider>().toggleReaction(
                          roomId: widget.room.roomId,
                          messageId: message.messageId,
                          currentUid: uid,
                          emoji: '❤️',
                        );
                      },
                      onDoubleTap: () {
                        // Double-tap to activate Reply mode
                        setState(() {
                          _replyingMessage = message;
                        });
                      },
                      child: Column(
                        children: [
                          if (showDateSeparator)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      _formatDate(message.timestamp),
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
                            ),

                          Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.blue
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 16),
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isGroup)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        message.senderId == uid
                                            ? 'You'
                                            : (sender?.displayName ?? 'User'),
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.black54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),

                                  // UI script reply message preview (if any)
                                  if (message.replyToMessageId != null)
                                    Container(
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.replySenderId == uid
                                                ? 'You'
                                                : 'Other user',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            message.replyText ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isMe
                                                  ? Colors.white70
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // UI categorizes and displays main content (text/image/file)
                                  if (message.type == 'image' &&
                                      message.mediaUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        message.mediaUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.broken_image,
                                              size: 40,
                                            ),
                                      ),
                                    )
                                  else if (message.type == 'file')
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.insert_drive_file,
                                          color: isMe
                                              ? Colors.white
                                              : Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            message.fileName ?? 'File',
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else // The default setting is to display plain text messages
                                    Text(
                                      message.text,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),

                                  // UI displays additional caption text if sending image/file with description (Caption)
                                  if (message.type != 'text' &&
                                      message.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        message.text,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatTime(message.timestamp),
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.black45,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          message.status == 'read'
                                              ? Icons.done_all
                                              : Icons.done,
                                          size: 14,
                                          color: message.status == 'read'
                                              ? Colors.lightBlueAccent
                                              : Colors.white70,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // UI synchronizes and displays the list of reactions (if any) below the message bubble
                          if (message.reactions != null &&
                              message.reactions!.isNotEmpty)
                            Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  right: 10,
                                  bottom: 4,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
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
                                        .map((emoji) {
                                          return Text(
                                            emoji.toString(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              if (chatProvider.isSending) {
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
              }

              return const SizedBox.shrink();
            },
          ),

          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // UI displays the message being selected for replying (Reply Preview)
                if (_replyingMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _replyingMessage = null),
                        ),
                      ],
                    ),
                  ),

                // Main input area - text field + send button
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // NÚT CHỌN VÀ GỬI ẢNH THẬT ĐI CLOUDINARY
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.blue),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData:
                                true, // Bắt buộc để lấy được bytes trên cả Mobile/Web
                          );

                          if (result != null &&
                              result.files.single.bytes != null) {
                            final fileBytes = result.files.single.bytes!;
                            final name = result.files.single.name;
                            final size = result.files.single.size;

                            if (!mounted) return;
                            context.read<ChatProvider>().uploadAndSendMedia(
                              roomId: widget.room.roomId,
                              currentUid: currentUid!,
                              type: 'image',
                              fileBytes: fileBytes,
                              fileName: name,
                              fileSize: size,
                            );
                          }
                        },
                      ),

                      // NÚT CHỌN VÀ GỬI TÀI LIỆU/FILE THẬT ĐI CLOUDINARY
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.blue),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                            withData: true, // Bắt buộc để lấy được bytes
                          );

                          if (result != null &&
                              result.files.single.bytes != null) {
                            final fileBytes = result.files.single.bytes!;
                            final name = result.files.single.name;
                            final size = result.files.single.size;

                            if (!mounted) return;
                            context.read<ChatProvider>().uploadAndSendMedia(
                              roomId: widget.room.roomId,
                              currentUid: currentUid!,
                              type: 'file',
                              fileBytes: fileBytes,
                              fileName: name,
                              fileSize: size,
                            );
                          }
                        },
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
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _onSendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    return '${date.day}/${date.month}/${date.year}';
  }
}
