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
import 'package:irischat/screens/chat/widget/ChatMessageListWidget.dart'; // Import file mới bóc tách
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
  String? _highlightedMessageId; // Quản lý ID tin nhắn gốc cần nhấp nháy

  bool _isSearchBarVisible = false; // Ẩn/hiện thanh nhập từ khóa ở đỉnh
  List<MessageModel> _searchResults = []; // Danh sách tin nhắn khớp từ khóa
  int _currentSearchIndex =
      -1; // Chỉ số tin nhắn đang tập trung (-1 là chưa chọn)

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

    // Lọc danh sách tin nhắn: Thỏa mãn chứa keyword, không bị xóa, và là tin nhắn text
    final matches = chatProvider.messages.where((msg) {
      final isText = msg.type == 'text' || msg.type == null;
      return isText &&
          !msg.isDeleted &&
          msg.text.toLowerCase().contains(keyword.trim().toLowerCase());
    }).toList();

    setState(() {
      _searchResults = matches;
      if (_searchResults.isNotEmpty) {
        // Mặc định nhảy tới tin nhắn mới nhất khớp kết quả (nằm ở cuối mảng matches)
        _currentSearchIndex = _searchResults.length - 1;
        _jumpToSearchMatch(_currentSearchIndex);
      } else {
        _currentSearchIndex = -1;
        _highlightedMessageId = null;
      }
    });
  }

  // Điều hướng qua lại giữa các kết quả (Mũi tên lên/xuống)
  void _navigateSearch(bool goUp) {
    if (_searchResults.isEmpty) return;

    setState(() {
      if (goUp) {
        // Lên trên = tìm tin cũ hơn = giảm index trong mảng kết quả
        if (_currentSearchIndex > 0) {
          _currentSearchIndex--;
        } else {
          _currentSearchIndex =
              _searchResults.length - 1; // Vòng lặp lại tin mới nhất
        }
      } else {
        // Xuống dưới = tìm tin mới hơn = tăng index trong mảng kết quả
        if (_currentSearchIndex < _searchResults.length - 1) {
          _currentSearchIndex++;
        } else {
          _currentSearchIndex = 0; // Vòng lặp lại tin cũ nhất
        }
      }
      _jumpToSearchMatch(_currentSearchIndex);
    });
  }

  // Thực hiện cuộn màn hình và highlight tin nhắn được chọn
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

      // Gán ID để Widget con tô màu vàng cố định (không dùng bộ Timer tự tắt nữa)
      _highlightedMessageId = targetMessage.messageId;
    }
  }

  // Tắt chế độ tìm kiếm, dọn dẹp bộ nhớ tạm
  void _closeSearchMode() {
    setState(() {
      _isSearchBarVisible = false;
      _searchController.clear();
      _searchResults.clear();
      _currentSearchIndex = -1;
      _highlightedMessageId = null;
    });
  }

  // ===========================================================================
  // CÁC HÀM LOGIC XỬ LÝ SỰ KIỆN GIỮ LẠI Ở FILE MẸ
  // ===========================================================================
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
          title: const Text('Search Messages'),
          content: TextField(
            decoration: const InputDecoration(
              hintText: 'Enter keyword...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (keyword) {
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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
                    onTap: () => Navigator.pop(context),
                  ),
                  _actionButton(
                    icon: Icons.forward, // Hoặc Icons.share
                    label: 'Forward',
                    onTap: () {
                      // 1. Đóng menu hành động tin nhắn hiện tại trước
                      Navigator.pop(context);

                      // 2. Lấy UID của bạn (ví dụ lấy từ widget.currentUid hoặc từ Provider tùy cấu trúc app)
                      final myUid = widget.room.participants.firstWhere(
                        (id) =>
                            id !=
                            widget
                                .room
                                .roomName, // Chỉnh lại logic lấy UID của chính bạn tại đây
                        orElse: () => '',
                      );

                      // 3. Hiển thị BottomSheet chứa widget vừa tách
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => ForwardBottomSheet(
                          originalMessage:
                              message, // Đối tượng MessageModel của tin nhắn đang chọn
                          currentUid: myUid,
                        ),
                      );
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
                      onTap: () => Navigator.pop(context),
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

  // ===========================================================================
  // BUILD METHOD CHÍNH
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null || currentUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: ChatAppBarWidget(
        room: widget.room,
        privateFriend: privateFriend,
        onSearchPressed: () =>
            setState(() => _isSearchBarVisible = true), // Mở thanh tìm kiếm
      ),
      body: Column(
        children: [
          _buildTopSearchBar(), // ◄ Thanh gõ từ khóa ở đỉnh
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
          _buildBottomSearchNavigator(), // ◄ Thanh số lượng X/Y và nút Lên/Xuống
          // CHỐNG CHẶN CHAT REALTIME
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

                    // Nếu trường 'blockedBy' trong DB không rỗng chứng tỏ cuộc hội thoại đang bị chặn
                    if (friendData != null && friendData.blockedBy.isNotEmpty) {
                      final bool amITheBlocker =
                          friendData.blockedBy == currentUid;

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey.shade50,
                        alignment: Alignment.center,
                        child: Text(
                          amITheBlocker
                              ? 'You have blocked this user. Unblock to resume chat.'
                              : 'This user has blocked you. You cannot reply to this conversation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    // Không có ai chặn -> Trả lại quyền gõ phím bình thường
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

  // 1. Thanh nhập từ khóa (Nằm ngay dưới AppBar)
  Widget _buildTopSearchBar() {
    if (!_isSearchBarVisible) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // Di chuyển color và border vào bên trong BoxDecoration
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search message content...',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: _closeSearchMode,
          ),
        ],
      ),
    );
  }

  // 2. Thanh hiển thị số lượng và nút bấm điều hướng (Nằm trên thanh Chat Input)
  Widget _buildBottomSearchNavigator() {
    if (!_isSearchBarVisible || _searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    // Hiển thị dạng thân thiện con người (Ví dụ: kết quả thứ 1/3 thay vì chỉ số mảng 0/3)
    final int displayCurrent = _currentSearchIndex + 1;
    final int displayTotal = _searchResults.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // Đã sửa: Gom color và border vào đúng vị trí trong BoxDecoration
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Found matches: $displayCurrent/$displayTotal',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                tooltip: 'Older message',
                onPressed: () => _navigateSearch(true), // Đi lên trên
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                tooltip: 'Newer message',
                onPressed: () => _navigateSearch(false), // Đi xuống dưới
              ),
            ],
          ),
        ],
      ),
    );
  }
}
