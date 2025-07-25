import 'package:flutter/material.dart';

class CustomDrawer extends StatefulWidget {
  final String selectedEvent;
  final TabController tabController;
  final void Function(String selectedCity, String selectedEvent)?
      onSelectionChanged;
  final List<String> events;

  const CustomDrawer({
    Key? key,
    required this.tabController,
    required this.selectedEvent,
    required this.events,
    this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String userName = 'Aritra';
  String selectedCity = 'Mumbai';

  // final List<String> events = ['The Viral Night'];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/sidenavbg.png',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Welcome !',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Select Event
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Select Event',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildDropdown<String>(
                      value: widget.selectedEvent,
                      items: widget.events,
                      onChanged: (value) {
                        if (value != null) {
                          widget.onSelectionChanged?.call(selectedCity, value);
                          Navigator.pop(context); // auto close on select
                        }
                      },
                      icon: Icons.event,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Menu
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),

                  ListTile(
                    leading:
                        const Icon(Icons.qr_code_scanner, color: Colors.black),
                    title: const Text(
                      'Scan',
                      style: TextStyle(color: Colors.black),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.tabController.animateTo(0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.black),
                    title: const Text(
                      'Register',
                      style: TextStyle(color: Colors.black),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.tabController.animateTo(1);
                    },
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, left: 16),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Made By ',
                            style: TextStyle(
                              color: Color.fromARGB(255, 117, 116, 116),
                            ),
                          ),
                          TextSpan(
                            text: '\nARITRA DEB',
                            style: TextStyle(
                              color: Color.fromARGB(255, 117, 116, 116),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required void Function(T) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 242, 236, 252),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.arrow_drop_down),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 10),
                  Text(item.toString()),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
