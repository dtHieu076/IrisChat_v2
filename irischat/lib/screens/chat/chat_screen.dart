import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/friend_model.dart';
import 'package:irischat/models/message_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/friendship_provider.dart';
import 'package:irischat/providers/user_provider.dart';
import 'package:irischat/screens/chat/widget/ChatAppBarWidget.dart';
import 'package:irischat/screens/chat/widget/ChatInputWidget.dart';
import 'package:irischat/screens/chat/widget/ChatSendingIndecatorWidget.dart';
import 'package:irischat/screens/chat/widget/ForwardBottomSheet.dart';
import 'package:irischat/screens/chat/widget/NotFriendWarningWidget.dart';
import 'package:irischat/screens/chat/widget/ChatMessageListWidget.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? currentUid;
  UserModel? privateFriend;
  final Map<String, UserModel> users = {};

  MessageModel? _replyingMessage;
  String? _highlightedMessageId;

  bool _isSearchBarVisible = false;
  List<MessageModel> _searchResults = [];
  int _currentSearchIndex = -1;

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

  void _onSearchChanged(String keyword) {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _currentSearchIndex = -1;
        _highlightedMessageId = null;
      });
      return;
    }

    final chatProvider = context.read<ChatProvider>();

    final matches = chatProvider.messages.where((msg) {
      final isText = msg.type == 'text' || msg.type == null;
      return isText &&
          !msg.isDeleted &&
          msg.text.toLowerCase().contains(keyword.trim().toLowerCase());
    }).toList();

    setState(() {
      _searchResults = matches;
      if (_searchResults.isNotEmpty) {
        _currentSearchIndex = _searchResults.length - 1;
        _jumpToSearchMatch(_currentSearchIndex);
      } else {
        _currentSearchIndex = -1;
        _highlightedMessageId = null;
      }
    });
  }

  void _navigateSearch(bool goUp) {
    if (_searchResults.isEmpty) return;

    setState(() {
      if (goUp) {
        if (_currentSearchIndex > 0) {
          _currentSearchIndex--;
        } else {
          _currentSearchIndex = _searchResults.length - 1;
        }
      } else {
        if (_currentSearchIndex < _searchResults.length - 1) {
          _currentSearchIndex++;
        } else {
          _currentSearchIndex = 0;
        }
      }
      _jumpToSearchMatch(_currentSearchIndex);
    });
  }

  void _jumpToSearchMatch(int searchIndex) {
    if (searchIndex < 0 || searchIndex >= _searchResults.length) return;

    final targetMessage = _searchResults[searchIndex];
    final chatProvider = context.read<ChatProvider>();

    if (chatProvider.messageIndexMap.containsKey(targetMessage.messageId)) {
      final int rawIndex =
          chatProvider.messageIndexMap[targetMessage.messageId]!;
      final int uiIndex = chatProvider.messages.length - 1 - rawIndex;

      final double estimatedOffset = uiIndex * 90.0;
      _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      _highlightedMessageId = targetMessage.messageId;
    }
  }

  void _closeSearchMode() {
    setState(() {
      _isSearchBarVisible = false;
      _searchController.clear();
      _searchResults.clear();
      _currentSearchIndex = -1;
      _highlightedMessageId = null;
    });
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
      setState(() => _replyingMessage = null);
    } else {
      chatProvider.sendTextMessage(
        roomId: widget.room.roomId,
        currentUid: currentUid!,
        text: text,
      );
    }
    _messageController.clear();
  }

  void _onReplyMessageTap(MessageModel message) {
    final targetMsgId = message.replyToMessageId;
    if (targetMsgId == null) return;

    final chatProvider = context.read<ChatProvider>();
    if (chatProvider.messageIndexMap.containsKey(targetMsgId)) {
      final int rawIndex = chatProvider.messageIndexMap[targetMsgId]!;
      final int uiIndex = chatProvider.messages.length - 1 - rawIndex;

      _scrollController.animateTo(
        uiIndex * 90.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

      setState(() => _highlightedMessageId = targetMsgId);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted &&
            _highlightedMessageId == targetMsgId &&
            !_isSearchBarVisible) {
          setState(() => _highlightedMessageId = null);
        }
      });
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Tìm kiếm tin nhắn',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Nhập từ khóa...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal),
              ),
            ),
            onSubmitted: (keyword) {
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showMessageActions(MessageModel message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh vuốt trên cùng của Bottom Sheet tạo cảm giác mượt mà
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Khối chứa các biểu cảm cảm xúc (Rections) bồng bềnh
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.grey.shade100),
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
              const SizedBox(height: 24),
              // Menu các phím chức năng dạng lưới/hàng ngang phân bổ khoa học
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _actionButton(
                    icon: Icons.reply_rounded,
                    label: 'Trả lời',
                    color: Colors.blue[50]!,
                    iconColor: Colors.blue[700]!,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _replyingMessage = message;
                      });
                    },
                  ),
                  _actionButton(
                    icon: Icons.content_copy_rounded,
                    label: 'Sao chép',
                    color: Colors.orange[50]!,
                    iconColor: Colors.orange[700]!,
                    onTap: () => Navigator.pop(context),
                  ),
                  _actionButton(
                    icon: Icons.forward_rounded,
                    label: 'Chuyển tiếp',
                    color: Colors.teal[50]!,
                    iconColor: Colors.teal[700]!,
                    onTap: () {
                      Navigator.pop(context);
                      final myUid = widget.room.participants.firstWhere(
                        (id) => id != widget.room.roomName,
                        orElse: () => '',
                      );

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (context) => ForwardBottomSheet(
                          originalMessage: message,
                          currentUid: myUid,
                        ),
                      );
                    },
                  ),
                  if (isMe)
                    _actionButton(
                      icon: Icons.history_rounded,
                      label: 'Thu hồi',
                      color: Colors.deepPurple[50]!,
                      iconColor: Colors.deepPurple[700]!,
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
                      icon: Icons.delete_outline_rounded,
                      label: 'Xóa',
                      color: Colors.red[50]!,
                      iconColor: Colors.red[700]!,
                      onTap: () => Navigator.pop(context),
                    ),
                ],
              ),
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
      child: Transform.scale(
        scale: 1.1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null || currentUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: ChatAppBarWidget(
        room: widget.room,
        privateFriend: privateFriend,
        onSearchPressed: () => setState(() => _isSearchBarVisible = true),
      ),
      body: Column(
        children: [
          _buildTopSearchBar(),
          NotFriendWarningWidget(
            room: widget.room,
            privateFriend: privateFriend,
          ),

          Expanded(
            child: ChatMessageListWidget(
              scrollController: _scrollController,
              currentUid: currentUid!,
              users: users,
              room: widget.room,
              highlightedMessageId: _highlightedMessageId,
              onMessageLongPress: (message, isMe) =>
                  _showMessageActions(message, isMe),
              onMessageDoubleTap: (message) =>
                  setState(() => _replyingMessage = message),
              onReplyTap: _onReplyMessageTap,
            ),
          ),

          ChatSendingIndicatorWidget(),
          _buildBottomSearchNavigator(),

          widget.room.isGroup
              ? ChatInputWidget(
                  controller: _messageController,
                  replyingMessage: _replyingMessage,
                  onSendPressed: _onSendMessage,
                  onPickImage: () => _pickAndSendMedia('image'),
                  onPickFile: () => _pickAndSendMedia('file'),
                  onCancelReply: () => setState(() => _replyingMessage = null),
                )
              : StreamBuilder<FriendModel?>(
                  stream: context
                      .read<FriendshipProvider>()
                      .listenFriendshipState(
                        currentUid!,
                        privateFriend?.uid ?? '',
                      ),
                  builder: (context, snapshot) {
                    final friendData = snapshot.data;

                    if (friendData != null && friendData.blockedBy.isNotEmpty) {
                      final bool amITheBlocker =
                          friendData.blockedBy == currentUid;

                      // Nâng cấp Banner chặn cuộc gọi tinh tế, trang nhã hơn
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.block_rounded,
                              color: Colors.red[400],
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                amITheBlocker
                                    ? 'Bạn đã chặn người dùng này. Bỏ chặn để tiếp tục trò chuyện.'
                                    : 'Bạn không thể phản hồi cuộc trò chuyện này lúc này.',
                                style: TextStyle(
                                  color: Colors.red[800],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ChatInputWidget(
                      controller: _messageController,
                      replyingMessage: _replyingMessage,
                      onSendPressed: _onSendMessage,
                      onPickImage: () => _pickAndSendMedia('image'),
                      onPickFile: () => _pickAndSendMedia('file'),
                      onCancelReply: () =>
                          setState(() => _replyingMessage = null),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTopSearchBar() {
    if (!_isSearchBarVisible) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.teal[600], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Tìm nội dung tin nhắn...',
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
            onPressed: _closeSearchMode,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSearchNavigator() {
    if (!_isSearchBarVisible || _searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    final int displayCurrent = _currentSearchIndex + 1;
    final int displayTotal = _searchResults.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal[50]!.withOpacity(0.6),
        border: Border(top: BorderSide(color: Colors.teal.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Đã tìm thấy: $displayCurrent / $displayTotal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal[800],
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                color: Colors.teal[700],
                tooltip: 'Tin nhắn cũ hơn',
                onPressed: () => _navigateSearch(true),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                color: Colors.teal[700],
                tooltip: 'Tin nhắn mới hơn',
                onPressed: () => _navigateSearch(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
