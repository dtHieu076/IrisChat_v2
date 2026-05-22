import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final service = callProvider
        .getService(); // Bạn cần thêm getter này trong Provider

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video của đối phương (To, toàn màn hình)
          Positioned.fill(
            child: RTCVideoView(
              service.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // 2. Video của mình (Nhỏ, góc trên bên phải)
          Positioned(
            top: 50,
            right: 20,
            width: 120,
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(
                  service.localRenderer,
                  mirror: true, // Soi gương cho camera trước
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

          // 3. Các nút điều khiển (Dưới cùng)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. Nút Mic
                FloatingActionButton(
                  heroTag: 'mic_btn', // 🔥 THÊM DÒNG NÀY (Định danh duy nhất)
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.mic, color: Colors.black),
                  onPressed: () {},
                ),

                // 2. Nút Cúp máy
                FloatingActionButton(
                  heroTag:
                      'end_call_btn', // 🔥 THÊM DÒNG NÀY (Định danh duy nhất)
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white),
                  onPressed: () {
                    callProvider.endCall();
                    Navigator.pop(context);
                  },
                ),

                // 3. Nút Camera
                FloatingActionButton(
                  heroTag: 'video_btn', // 🔥 THÊM DÒNG NÀY (Định danh duy nhất)
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.videocam, color: Colors.black),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
