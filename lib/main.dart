import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/firebase_options.dart';
import 'package:ziesocial/service/fcm_service.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/create_post_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/notification_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/viewmodel/register_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase hanya pada platform mobile (Android / iOS)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[Firebase] Inisialisasi dilewati/menunggu konfigurasi: $e');
    }
  }

  final apiClient = ApiClient();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => RegisterViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => CreatePostViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => PostViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => ProfileViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => SearchViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => StoryViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => ChatViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => NotificationViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZieSocial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 54, 103, 159),
        ),
        useMaterial3: true,
      ),
      home: const LoginView(),
    );
  }
}
