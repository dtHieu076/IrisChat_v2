import 'package:flutter/material.dart';
import 'package:irischat/models/call_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/call_provider.dart';
import 'package:irischat/providers/chat_provider.dart';
import 'package:irischat/screens/call/call_screen.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/friendship_provider.dart';

import 'tabs/home_tab.dart';
import 'tabs/friends_tab.dart';
import 'tabs/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  late UserModel currentUser;
  late AuthProvider authProvider;
  late FriendshipProvider friendshipProvider;
  late ChatProvider chatProvider;
  StreamSubscription<CallModel>? _callSubscription;

  @override
  void initState() {
    super.initState();

    authProvider = context.read<AuthProvider>();
    friendshipProvider = context.read<FriendshipProvider>();
    chatProvider = context.read<ChatProvider>();

    final user = authProvider.user;

    if (user != null) {
      currentUser = user;
      chatProvider.setCurrentUid(user.uid);

      friendshipProvider.listenReceivedRequests(user.uid);
      friendshipProvider.listenSentRequests(user.uid);
      friendshipProvider.listenFriends(user.uid);
      chatProvider.listenAllChatRooms(user.uid);

      // 🔥 LẮNG NGHE QUA PROVIDER (Đúng chuẩn kiến trúc)
      // _listenToIncomingCalls(user.uid);
    }
  }

  void _listenToIncomingCalls(String uid) {
    _callSubscription = context
        .read<CallProvider>()
        .incomingCallStream(uid)
        .listen((call) async {
          if (call.status == 'ringing' && call.receiverId == uid) {
            _showIncomingCallDialog(call);
          }

          if (call.status == 'accepted') {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            await context.read<CallProvider>().getService().initRenderers();
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CallScreen()),
              );
            }
          }

          // 🔥 KHI NHẬN ĐƯỢC TÍN HIỆU 'ended' TỪ ĐỐI PHƯƠNG
          if (call.status == 'ended') {
            // Máy còn lại cũng tự gọi Provider để dọn dẹp cam/mic của mình
            await context.read<CallProvider>().endCall();

            // Nếu đang ở trong màn hình CallScreen thì lùi ra ngoài
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        });
  }

  void _showIncomingCallDialog(CallModel call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Cuộc gọi đến'),
          content: Text('Người gọi: ${call.callerId}'),
          actions: [
            TextButton(
              onPressed: () async {
                // Người nhận bấm nút này CHỈ làm 1 nhiệm vụ duy nhất:
                // Báo lên Firebase là tôi đã đồng ý nhận cuộc gọi.
                // Việc chuyển màn hình sẽ do hàm "_listenToIncomingCalls" ở trên lo liệu tự động.
                await context.read<CallProvider>().acceptCall(call.callId);
              },
              child: const Text(
                'Chấp nhận',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // 🔥 QUAN TRỌNG: Hủy lắng nghe cuộc gọi khi màn hình này bị đóng
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(),
      FriendsTab(currentUser: currentUser),
      ProfileTab(authProvider: authProvider),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Chat App')),

      body: IndexedStack(index: currentIndex, children: pages),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        items: [
          BottomNavigationBarItem(
            label: 'Home',
            icon: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.home),

                    if (chatProvider.hasUnreadMessages)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          BottomNavigationBarItem(
            label: 'Friends',
            icon: Consumer<FriendshipProvider>(
              builder: (context, friendshipProvider, child) {
                return Stack(
                  children: [
                    const Icon(Icons.people),

                    if (friendshipProvider.hasNotification)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          BottomNavigationBarItem(label: 'Profile', icon: Icon(Icons.person)),
        ],
      ),
    );
  }
}
