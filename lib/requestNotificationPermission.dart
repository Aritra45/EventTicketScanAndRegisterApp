import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }
}
