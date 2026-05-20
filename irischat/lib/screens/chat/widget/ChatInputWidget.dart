import 'package:flutter/material.dart';
import 'package:irischat/models/message_model.dart';

class ChatInputWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingMessage != null) _buildReplyPreview(),

          _buildInputArea(),
        ],
      ),
    );
  }

  // =========================================================
  // REPLY PREVIEW
  // =========================================================
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
                  replyingMessage!.text.isNotEmpty
                      ? replyingMessage!.text
                      : (replyingMessage!.type == 'image'
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
            onPressed: onCancelReply,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INPUT AREA
  // =========================================================
  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image, color: Colors.blue),
            onPressed: onPickImage,
          ),

          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.blue),
            onPressed: onPickFile,
          ),

          Expanded(
            child: TextField(
              controller: controller,
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
              onPressed: onSendPressed,
            ),
          ),
        ],
      ),
    );
  }
}
