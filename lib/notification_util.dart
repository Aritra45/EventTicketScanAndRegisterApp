import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotification() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final String? payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        print("Notification tapped. Opening file: $payload");
        final result = await OpenFile.open(payload);
        print("OpenFile result: ${result.message}");
      } else {
        print("No payload found in notification");
        Fluttertoast.showToast(
          msg: "Failed to open image or the image does not exist",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    },
  );

  final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'download_channel',
      'Downloads',
      description: 'Channel for download notifications',
      importance: Importance.high,
    ),
  );
}

Future<void> showDownloadNotification(String filePath, String fileName) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'download_channel',
    'Downloads',
    channelDescription: 'Channel for download notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    'Download Complete',
    '$fileName saved to Downloads',
    platformDetails,
    payload: filePath, // <-- pass full path here
  );
}
