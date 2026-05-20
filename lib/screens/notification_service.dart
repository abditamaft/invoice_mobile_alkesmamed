import 'package:flutter/material.dart'; // Wajib untuk fungsi Color
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // 🔥 FORMAT ATURAN BARU VERSI 21.0.0 (Pakai format titik dua ":")
    await _notificationsPlugin.initialize(
      initializationSettings, // tanpa "initializationSettings:"
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );
  }

  static Future<void> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'alkesmamed_channel',
          'Alkes Mamed Notifications',
          channelDescription: 'Notifikasi pesanan masuk dan update status',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF11213D),
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    // Format lama
    await _notificationsPlugin.show(
      id, // tanpa "id:"
      title, // tanpa "title:"
      body, // tanpa "body:"
      notificationDetails, // tanpa named parameter
    );
  }
}
