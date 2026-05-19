import 'package:flutter/material.dart';
import 'package:irischat/models/chat_room_model.dart';
import 'package:irischat/models/user_model.dart';
import 'package:irischat/screens/chat/chatRoomInfo_screen.dart';
import 'package:irischat/screens/chat/chat_screen.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';

class AppPages {
  static Map<String, WidgetBuilder> routes = {
    '/login': (context) => const LoginScreen(),

    '/register': (context) => const RegisterScreen(),

    '/home': (context) => const HomeScreen(),

    '/chat': (context) {
      final room = ModalRoute.of(context)!.settings.arguments as ChatRoomModel;
      return ChatScreen(room: room);
    },

    '/chat-room-info': (context) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return ChatRoomInfoScreen(
        room: args['room'] as ChatRoomModel,
        privateFriend: args['privateFriend'] as UserModel?,
      );
    },
  };
}
