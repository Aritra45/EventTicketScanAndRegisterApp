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
  bool? isNotEntered;
  bool isLoading = false;

  void _startScan() async {
    final scannedDocId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScanPage()),
    );

    if (scannedDocId != null) {
      setState(() {
        isLoading = true;
        scannedUserName = '';
        this.scannedDocId = scannedDocId;
      });

      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(scannedDocId)
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          final userEvent = data['event'] ?? '';

          if (userEvent != widget.selectedEvent) {
            setState(() {
              scannedUserName = 'User registered for a different event!';
              isNotEntered = null;
            });

            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(
            //         'This user is registered for "$userEvent", not for "${widget.selectedEvent}".'),
            //   ),
            // );
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
      } finally {
        setState(() {
          isLoading = false;
        });
      }
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
      // If failed, revert the toggle
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
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : scannedUserName.isEmpty
                ? Text('Scan a QR to show visitor info')
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
                            Text(
                              'Visitor Name: $scannedUserName',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ticket ID: $scannedDocId',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 16),
                            if (isNotEntered != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Entered: ',
                                    style: TextStyle(fontSize: 16),
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
