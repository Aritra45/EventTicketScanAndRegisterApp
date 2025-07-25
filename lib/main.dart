import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

  await requestNotificationPermission();
  await initNotification();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Registration App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
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
    _eventSubscription.cancel(); // 🧹 Cleanup
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
                  ));
  }
}
