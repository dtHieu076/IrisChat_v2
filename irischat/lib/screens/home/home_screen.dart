import 'package:flutter/material.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/providers/chat_provider.dart';
import 'package:provider/provider.dart';

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
    }
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
