import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/firebase_options.dart';

/// Background message handler untuk FCM (Wajib top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[FCM BG] Init error / already initialized: $e');
  }
  debugPrint('[FCM BG] Pesan notifikasi masuk di background: ${message.data}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Inisialisasi FCM service
  Future<void> init({required int userId}) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (_initialized) {
      await _registerTokenToServer(userId);
      return;
    }

    try {
      // 1. Request permission notifikasi (Android 13+ & iOS)
      await _requestPermission();

      // 2. Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Tangani pembaruan token
      _messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToServer(userId, newToken);
      });

      // Registrasi token awal ke server
      await _registerTokenToServer(userId);

      // 4. Tangani pesan foreground (bisa integrasi dengan in-app banner jika perlu)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Pesan masuk: ${message.notification?.title} - ${message.notification?.body}');
      });

      // 5. Tangani saat notifikasi di tray HP di-klik (aplikasi di background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message);
      });

      // 6. Tangani jika aplikasi awalnya tertutup total dan dibuka lewat klik notifikasi
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Error initialization: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Status izin notifikasi: ${settings.authorizationStatus}');
  }

  Future<void> _registerTokenToServer(int userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[FCM] Token device: $token');
        await _sendTokenToServer(userId, token);
      }
    } catch (e) {
      debugPrint('[FCM] Gagal mengambil token: $e');
    }
  }

  Future<void> _sendTokenToServer(int userId, String token) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.saveFcmToken),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'user_id': userId,
          'fcm_token': token,
        }),
      );
      debugPrint('[FCM] Kirim token ke backend response: ${res.statusCode}');
    } catch (e) {
      debugPrint('[FCM] Gagal mengirim token ke backend: $e');
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('[FCM] Notifikasi diklik, payload: ${message.data}');
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[FCM] Gagal delete token: $e');
    }
  }
}
