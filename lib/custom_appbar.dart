import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;
  final bool isBackButtonShow;
  final String title;
  final String? subTitle;
  final bool isShowNotification;
  final bool isShowMenu;
  final IconData icon;
  final bool isShowLogo;
  final bool isReturnValue;
  final String? imageLogo;

  const CustomAppBar({
    Key? key,
    required this.tabController,
    required this.isBackButtonShow,
    required this.title,
    this.subTitle,
    required this.isShowNotification,
    required this.isShowMenu,
    required this.icon,
    required this.isShowLogo,
    required this.isReturnValue,
    this.imageLogo = 'assets/homelogo.jpg',
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(120);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.deepPurple,
      elevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: isBackButtonShow
            ? IconButton(
                onPressed: () {
                  if (isReturnValue) {
                    Navigator.of(context).pop(true);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.arrow_back, color: Colors.black),
              )
            : isShowLogo
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipOval(
                      child: Image.asset(
                        imageLogo!,
                        width: 36, // 🔁 Adjust size as needed
                        height: 36,
                        fit: BoxFit.cover, // makes it fill the circle better
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          if (subTitle != null)
            Text(
              subTitle!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
        ],
      ),
      actions: [
        if (isShowNotification)
          IconButton(
            onPressed: () {},
            icon:
                const Icon(Icons.notifications_none_sharp, color: Colors.black),
          ),

        // 🔘 Custom icon before menu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: () => _showEventManagerDialog(context),
          ),
        ),

        // 🍔 Menu button
        if (isShowMenu)
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu, color: Colors.white),
            ),
          ),
      ],
      bottom: TabBar(
        controller: tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white,
        indicatorColor: Colors.amber,
        tabs: const [
          Tab(text: 'Scan'),
          Tab(text: 'Register'),
        ],
      ),
    );
  }

  void _showEventManagerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Events',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _showAddEventDialog(context);
                },
                icon: Icon(Icons.add, color: Colors.deepPurple),
                label: Text('Add Event'),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('events').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text('No events added yet.');
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (ctx, index) {
                    final doc = docs[index];
                    final eventName = doc['name'];

                    return ListTile(
                      title: Text(eventName),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Confirm Delete"),
                              content: Text(
                                  "Are you sure you want to delete '$eventName'?"),
                              actions: [
                                TextButton(
                                  child: const Text("Cancel"),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                TextButton(
                                  child: const Text("Delete",
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () async {
                                    Navigator.of(context)
                                        .pop(); // close confirm box
                                    await FirebaseFirestore.instance
                                        .collection('events')
                                        .doc(doc.id)
                                        .delete();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAddEventDialog(BuildContext context) {
    final TextEditingController _eventController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add New Event"),
        content: TextField(
          controller: _eventController,
          decoration: InputDecoration(
            hintText: "Enter event name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final eventName = _eventController.text.trim();
              if (eventName.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('events')
                    .add({'name': eventName});
                Navigator.pop(context);
              }
            },
            child: Text("Add"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
        ],
      ),
    );
  }
}
