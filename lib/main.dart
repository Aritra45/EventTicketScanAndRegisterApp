import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:utkarsheventapp/Register.dart';
import 'package:utkarsheventapp/Scan.dart';
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
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'Utkarsh BSDK',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          labelColor: Colors.white,
          indicatorColor: Colors.amber,
          unselectedLabelColor: Colors.white,
          controller: _tabController,
          tabs: const [
            Tab(text: 'Scan'),
            Tab(text: 'Register'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ScanTab(),
          RegisterTab(),
        ],
      ),
    );
  }
}
