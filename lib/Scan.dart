import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:utkarsheventapp/QRViewScanner.dart';

class ScanTab extends StatefulWidget {
  final String selectedEvent;

  const ScanTab({Key? key, required this.selectedEvent}) : super(key: key);

  @override
  _ScanState createState() => _ScanState();
}

class _ScanState extends State<ScanTab> {
  String scannedUserName = '';
  String scannedDocId = '';
  String status = '';
  String? amount = '';
  bool? isNotEntered;
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Needed to show/hide clear button
    });
  }

  final TextEditingController _searchController = TextEditingController();

  void _startScan() async {
    final scannedDocId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScanPage()),
    );

    if (scannedDocId != null) {
      // Optional: add validation here
      if (_isProbablyValidDocId(scannedDocId)) {
        _searchController.text = scannedDocId;
        _fetchUserByDocId(scannedDocId);
      } else {
        Fluttertoast.showToast(
          msg: "Invalid QR Code scanned. This doesn't look like a ticket.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  bool _isProbablyValidDocId(String input) {
    final trimmed = input.trim();

    // You can add your own logic here — maybe all ticket IDs are alphanumeric and 20 chars long?
    final isValidLength = trimmed.length >= 15 && trimmed.length <= 28;
    final isAlphanumeric = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
    final isNotUrlOrUpi = !(trimmed.startsWith('http') ||
        trimmed.startsWith('upi:') ||
        trimmed.contains('@'));

    return isValidLength && isAlphanumeric && isNotUrlOrUpi;
  }

  Future<void> _fetchUserByDocId(String docId) async {
    setState(() {
      isLoading = true;
      scannedUserName = '';
      scannedDocId = docId;
    });

    try {
      final docSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(docId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final userEvent = data['event'] ?? '';

        if (userEvent != widget.selectedEvent) {
          setState(() {
            scannedUserName = 'User registered for a different event!';
            isNotEntered = null;
          });

          Fluttertoast.showToast(
            msg:
                "This user is registered for '$userEvent', not for '${widget.selectedEvent}'",
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          return;
        }

        setState(() {
          scannedUserName = data['name'] ?? 'Unknown';
          isNotEntered = data['isNotEntered'] ?? true;
          status = data['status'];
          amount = data['amount'];
        });
      } else {
        setState(() {
          scannedUserName = 'User not found';
          isNotEntered = null;
        });
      }
    } catch (e) {
      setState(() {
        scannedUserName = 'Error loading user';
        isNotEntered = null;
      });
      Fluttertoast.showToast(
        msg: 'Error fetching user: ${e.toString()}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _toggleEntryStatus(bool newValue) async {
    setState(() {
      isNotEntered = newValue;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(scannedDocId)
          .update({'isNotEntered': newValue});
    } catch (e) {
      setState(() {
        isNotEntered = !newValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update entry status")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  FocusScope.of(context).unfocus(); // hide keyboard
                  _fetchUserByDocId(value.trim());
                }
              },
              decoration: InputDecoration(
                hintText: 'Enter Ticket ID and press Enter',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            scannedUserName = '';
                            scannedDocId = '';
                            isNotEntered = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // 🔄 Loading or Result
          Expanded(
            child: Center(
              child: isLoading
                  ? CircularProgressIndicator()
                  : scannedUserName.isEmpty
                      ? const Text('Scan a QR or Search to show visitor info')
                      : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            color: isNotEntered == null
                                ? Colors.white
                                : (isNotEntered!
                                    ? Colors.red[100]
                                    : Colors.green[100]),
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person,
                                      size: 50, color: Colors.deepPurple),
                                  SizedBox(height: 12),

                                  // Visitor Name (center-aligned by default)
                                  Text(
                                    'Visitor Name: $scannedUserName',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  SizedBox(height: 12),

                                  // Left-aligned details below
                                  if (scannedUserName != 'User not found')
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            text: 'Ticket ID: ',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold),
                                            children: [
                                              TextSpan(
                                                text: scannedDocId,
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        RichText(
                                          text: TextSpan(
                                            text: 'Status: ',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold),
                                            children: [
                                              TextSpan(
                                                text: status,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  color: status.toLowerCase() ==
                                                          'paid'
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        if (status == 'Paid')
                                          RichText(
                                            text: TextSpan(
                                              text: 'Amount: ',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold),
                                              children: [
                                                TextSpan(
                                                  text: '${amount}',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),

                                  SizedBox(height: 16),

                                  if (isNotEntered != null && status == 'Paid')
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Entered: ',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Switch(
                                          value: !isNotEntered!,
                                          onChanged: (val) =>
                                              _toggleEntryStatus(!val),
                                          activeColor: Colors.green,
                                          inactiveThumbColor: Colors.red,
                                          inactiveTrackColor: Colors.red[200],
                                        ),
                                        Text(
                                          isNotEntered! ? 'No' : 'Yes',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isNotEntered!
                                                  ? Colors.red
                                                  : Colors.green),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _startScan,
        child: Icon(
          Icons.qr_code_scanner,
          color: Colors.white,
        ),
        tooltip: 'Scan QR Code',
      ),
    );
  }
}
