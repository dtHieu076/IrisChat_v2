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

          if (call.status == 'ended') {
            await context.read<CallProvider>().endCall();

            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        });
  }

  // Giao diện Hộp thoại cuộc gọi đến được thiết kế lại đẹp và sang hơn
  void _showIncomingCallDialog(CallModel call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.phone_callback_rounded,
                color: Colors.teal[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Cuộc gọi đến',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn có cuộc gọi mới từ:',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                call.callerId,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.blueGrey[800],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onPressed: () async {
                // GIỮ NGUYÊN LOGIC KÍCH HOẠT CUỘC GỌI
                await context.read<CallProvider>().acceptCall(call.callId);
              },
              child: const Text('Chấp nhận'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
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

    final primaryColor = Colors.teal[600]!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Chat App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),

      body: IndexedStack(index: currentIndex, children: pages),

      // Custom lại BottomNavigationBar bo góc nhẹ kèm đổ bóng mờ hiện đại
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => setState(() => currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.blueGrey[300],
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              label: 'Trò chuyện',
              icon: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        currentIndex == 0
                            ? Icons.chat_rounded
                            : Icons.chat_bubble_outline_rounded,
                      ),
                      if (chatProvider.hasUnreadMessages)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            BottomNavigationBarItem(
              label: 'Bạn bè',
              icon: Consumer<FriendshipProvider>(
                builder: (context, friendshipProvider, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        currentIndex == 1
                            ? Icons.people_rounded
                            : Icons.people_outline_rounded,
                      ),
                      if (friendshipProvider.hasNotification)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              // Chuẩn hóa viền trắng đồng bộ góc nhìn cực sạch
                              border: Border.all(
                                color: Colors.white,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            BottomNavigationBarItem(
              label: 'Cá nhân',
              icon: Icon(
                currentIndex == 2
                    ? Icons.person_rounded
                    : Icons.person_outline_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
