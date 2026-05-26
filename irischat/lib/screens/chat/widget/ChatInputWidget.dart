import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:irischat/models/message_model.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final MessageModel? replyingMessage;

  final VoidCallback onSendPressed;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onCancelReply;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.replyingMessage,
    required this.onSendPressed,
    required this.onPickImage,
    required this.onPickFile,
    required this.onCancelReply,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  bool _showEmoji = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() {
          _showEmoji = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    if (_showEmoji) {
      setState(() {
        _showEmoji = false;
      });
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() {
        _showEmoji = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showEmoji) {
          setState(() {
            _showEmoji = false;
          });
        }
      },
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.replyingMessage != null) _buildReplyPreview(),
              _buildInputArea(),
              if (_showEmoji) _buildEmojiPicker(),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // REPLY PREVIEW (Giao diện trả lời tin nhắn cao cấp)
  // =========================================================
  Widget _buildReplyPreview() {
    final reply = widget.replyingMessage!;
    final themeColor = Colors.teal[600]!;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: themeColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: themeColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang phản hồi...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: foundation.kIsWeb
                        ? FontWeight.bold
                        : FontWeight.w700,
                    color: themeColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reply.text.isNotEmpty
                      ? reply.text
                      : (reply.type == 'image' ? '[Hình ảnh]' : '[Tập tin]'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blueGrey[700],
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onCancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INPUT AREA (Khu vực nhập liệu phẳng hiện đại)
  // =========================================================
  Widget _buildInputArea() {
    final themeColor = Colors.teal[600]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Tiện ích đính kèm ảnh
          IconButton(
            onPressed: widget.onPickImage,
            icon: Icon(Icons.image_outlined, color: Colors.blueGrey[600]),
            splashRadius: 22,
          ),
          // Tiện ích đính kèm file
          IconButton(
            onPressed: widget.onPickFile,
            icon: Icon(Icons.attach_file_rounded, color: Colors.blueGrey[600]),
            splashRadius: 22,
          ),

          // Ô nhập liệu tin nhắn
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 15, color: Colors.blueGrey[900]),
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                isDense: true,
                // Viền mặc định bo góc mềm mại
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade100, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Colors.teal.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                // Nút chuyển đổi Emoji/Bàn phím tích hợp tinh tế bên trong
                prefixIcon: IconButton(
                  onPressed: _toggleEmojiPicker,
                  icon: Icon(
                    _showEmoji
                        ? Icons.keyboard_alt_outlined
                        : Icons.emoji_emotions_outlined,
                    color: _showEmoji ? themeColor : Colors.grey[500],
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nút gửi tin nhắn bóng đổ Neumorphic nhẹ
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeColor,
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.transparent,
              child: IconButton(
                onPressed: widget.onSendPressed,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMOJI PICKER (Bảng điều khiển biểu tượng cảm xúc đồng bộ)
  // =========================================================
  Widget _buildEmojiPicker() {
    final themeColor = Colors.teal[600]!;
    const panelBgColor = Color(
      0xFFF9FAFB,
    ); // Làm sáng nền hơn giúp Emoji nổi bật

    return SizedBox(
      height: 320,
      child: EmojiPicker(
        textEditingController: widget.controller,
        config: Config(
          height: 320,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 7,
            emojiSizeMax:
                32 *
                (foundation.defaultTargetPlatform == TargetPlatform.iOS
                    ? 1.30
                    : 1.0),
            verticalSpacing: 0,
            horizontalSpacing: 0,
            gridPadding: EdgeInsets.zero,
            backgroundColor: panelBgColor,
            recentsLimit: 28,
            noRecents: Center(
              child: Text(
                'Chưa có biểu tượng gần đây',
                style: TextStyle(fontSize: 15, color: Colors.grey[400]),
              ),
            ),
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: panelBgColor,
            indicatorColor: themeColor,
            iconColor: Colors.grey[400]!,
            iconColorSelected: themeColor,
            recentTabBehavior: RecentTabBehavior.RECENT,
            tabIndicatorAnimDuration: kTabScrollDuration,
          ),
          skinToneConfig: const SkinToneConfig(
            dialogBackgroundColor: Colors.white,
            indicatorColor: Colors.grey,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: panelBgColor,
            buttonColor: themeColor,
          ),
          searchViewConfig: const SearchViewConfig(
            backgroundColor: panelBgColor,
          ),
        ),
      ),
    );
  }
}
