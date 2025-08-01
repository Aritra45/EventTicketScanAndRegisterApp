import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:utkarsheventapp/LoginPage.dart';
import 'package:utkarsheventapp/Register.dart';
import 'package:utkarsheventapp/Scan.dart';
import 'package:utkarsheventapp/custom_appbar.dart';
import 'package:utkarsheventapp/custom_drawer.dart';
import 'package:utkarsheventapp/notification_util.dart';
import 'package:utkarsheventapp/requestNotificationPermission.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyCq3Sq4i9prX08ArJBLmJXaU0XWPTKBahM',
        appId: '1:160101428562:android:0fd323df99351cf8b7de8b',
        messagingSenderId: '160101428562',
        projectId: 'utkarsheventapp-682ac',
        storageBucket: 'utkarsheventapp-682ac.firebasestorage.app',
      ),
    );
  }

  await Hive.initFlutter();
  await requestNotificationPermission();
  await initNotification();

  await _checkAppVersion(); // 🔒 version check here

  var box = await Hive.openBox('userBox');
  final savedUsername = box.get('username');
  final savedPassword = box.get('password');
  final bool isLoggedIn = savedUsername != null && savedPassword != null;

  runApp(MyApp(isLoggedIn ? const HomePage() : const LoginPage()));
}

/// 🔐 Version Check Function
Future<void> _checkAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('android')
        .get();

    final String minVersion = doc['min_version'] ?? '1.0.0';
    final bool forceUpdate = doc['force_update'] ?? false;

    if (forceUpdate && _isLowerVersion(currentVersion, minVersion)) {
      if (!kDebugMode) {
        exit(0); // 🚪 Close the app silently in release
      } else {
        debugPrint("🚫 Version too old: $currentVersion < $minVersion");
      }
    }
  } catch (e) {
    debugPrint("❌ Version check failed: $e");
  }
}

/// 🔁 Version compare logic
bool _isLowerVersion(String current, String min) {
  List<int> currentParts =
      current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  List<int> minParts = min.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  for (int i = 0; i < 3; i++) {
    if (currentParts[i] < minParts[i]) return true;
    if (currentParts[i] > minParts[i]) return false;
  }
  return false;
}

class MyApp extends StatelessWidget {
  final Widget home;
  const MyApp(this.home, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Registration App',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: home,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> listevents = [];
  String _selectedEvent = '';
  late final StreamSubscription _eventSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSubscription = FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .listen((snapshot) {
      final List<String> updatedEvents =
          snapshot.docs.map((doc) => doc['name'].toString()).toList();

      setState(() {
        listevents = updatedEvents;
        if (listevents.isEmpty) {
          _selectedEvent = '';
        } else if (!listevents.contains(_selectedEvent)) {
          _selectedEvent = listevents.first;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _eventSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: CustomDrawer(
        tabController: _tabController!,
        selectedEvent: _selectedEvent,
        onSelectionChanged: (city, event) {
          setState(() => _selectedEvent = event);
        },
        events: listevents,
      ),
      appBar: CustomAppBar(
        tabController: _tabController!,
        isBackButtonShow: false,
        title: "Influencer Lab Event",
        subTitle: _selectedEvent,
        isShowNotification: false,
        isShowMenu: true,
        icon: Icons.add,
        isShowLogo: true,
        isReturnValue: false,
      ),
      body: (_tabController == null)
          ? const Center(child: CircularProgressIndicator())
          : (listevents.isEmpty)
              ? const Center(
                  child: Text(
                    'No Events Created.\nPlease add an event from the + icon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : TabBarView(
                  controller: _tabController!,
                  children: [
                    ScanTab(selectedEvent: _selectedEvent),
                    RegisterTab(
                      selectedEvent: _selectedEvent,
                      events: listevents,
                    ),
                  ],
                ),
    );
  }
}
