import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' show CellValue, Excel, Sheet, TextCellValue;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:utkarsheventapp/QRViewScanner.dart';
import 'package:utkarsheventapp/notification_util.dart';
import 'package:flutter/services.dart';

const platform = MethodChannel('com.utkarsh.utkarsheventapp/whatsapp');

class RegisterTab extends StatefulWidget {
  final String selectedEvent;
  final List<String> events;
  const RegisterTab(
      {Key? key, required this.selectedEvent, required this.events})
      : super(key: key);

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final users = FirebaseFirestore.instance.collection('users');
  bool _isQrLoading = false;
  String _searchQuery = '';
  String _paymentFilter = 'All',
      _passTypeFilter = 'All',
      _enteredFilter = 'All';
  final _searchController = TextEditingController();
  int _filteredVisitorCount = 0;
  List<Map<String, dynamic>> docs = [];
  bool isLoading = true;
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    _fetchVisitorsFromFirestore();
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final q = _searchQuery.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    final phone = (data['phone'] ?? '').toString().toLowerCase();
    final status = (data['status'] ?? '').toString().toLowerCase();
    final gender = (data['gender'] ?? '').toString().toLowerCase();
    final entered = (data['isNotEntered'] == true ? 'no' : 'yes');
    final event = (data['event'] ?? '').toString().toLowerCase();
    final docId = (data['id'] ?? '').toString().toLowerCase(); // 👈 Add this

    return (name.contains(q) ||
            phone.contains(q) ||
            status.contains(q) ||
            docId.contains(q)) && // 👈 Include this in the match
        (_paymentFilter == 'All' || status == _paymentFilter.toLowerCase()) &&
        (_passTypeFilter == 'All' || gender == _passTypeFilter.toLowerCase()) &&
        (_enteredFilter == 'All' || entered == _enteredFilter.toLowerCase()) &&
        (widget.selectedEvent.isEmpty ||
            event == widget.selectedEvent.toLowerCase());
  }

  void _updateFilteredVisitorCount(List<QueryDocumentSnapshot> docs) {
    final filtered = docs
        .where((doc) => _matchesFilters(doc.data() as Map<String, dynamic>))
        .toList();
    setState(() => _filteredVisitorCount = filtered.length);
  }

  Widget _buildDropdown(
      String value, List<String> options, ValueChanged<String?> onChange) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
            value: value,
            onChanged: onChange,
            items: options
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList()),
      ),
    );
  }

  String toBold(String input) {
    const boldOffset = 0x1D400 - 0x41; // Unicode bold offset for A-Z
    return input.split('').map((char) {
      if (char.contains(RegExp(r'[A-Z]'))) {
        return String.fromCharCode(char.codeUnitAt(0) + boldOffset);
      } else if (char.contains(RegExp(r'[a-z]'))) {
        return String.fromCharCode(char.codeUnitAt(0) + (0x1D41A - 0x61));
      } else if (char.contains(RegExp(r'[0-9]'))) {
        return String.fromCharCode(char.codeUnitAt(0) + (0x1D7CE - 0x30));
      } else {
        return char;
      }
    }).join('');
  }

  Future<File?> _captureQrImage(GlobalKey key) async {
    try {
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);

      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();

      final directory = await getExternalStorageDirectory(); // ✅ External
      final filePath =
          '${directory!.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to capture image: $e');
      return null;
    }
  }

  Future<void> shareImageToWhatsApp(
      String phoneNumber, File imageFile, String message) async {
    try {
      await platform.invokeMethod('shareToWhatsApp', {
        'phone': phoneNumber,
        'imagePath': imageFile.path,
        'text': message,
      });
    } on PlatformException catch (e) {
      Fluttertoast.showToast(msg: "WhatsApp share failed: ${e.message}");
    }
  }

  Future<void> _showQrDialog(String docId) async {
    final _qrKey = GlobalKey();
    bool isLoading = true;
    String userName = '';

    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            if (isLoading) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(docId)
                  .get()
                  .then((doc) {
                final d = doc.data() as Map<String, dynamic>?;
                setDialog(() {
                  userName = d?['name'] ?? 'Unknown';
                  isLoading = false;
                });
              });
            }

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QR Code',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Spacer(),
                  if (!isLoading)
                    IconButton(
                      icon: Icon(Icons.share, color: Colors.deepPurple),
                      onPressed: () async {
                        final file = await _captureQrImage(_qrKey);

                        if (file != null) {
                          await Share.shareXFiles(
                            [XFile(file.path)],
                            text:
                                "QR Ticket for ${toBold(userName)}, Don't Share This QR With Anyone, Ticket ID ${toBold(docId)}",
                          );
                        }
                      },
                    ),
                  if (!isLoading)
                    IconButton(
                      icon:
                          Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                      onPressed: () async {
                        final doc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(docId)
                            .get();

                        final data = doc.data() as Map<String, dynamic>?;
                        final phone = data?['phone']
                                ?.toString()
                                .replaceAll('+', '')
                                .replaceAll(' ', '') ??
                            '';

                        if (phone.isEmpty) {
                          Fluttertoast.showToast(msg: "Phone number not found");
                          return;
                        }

                        final file = await _captureQrImage(_qrKey);
                        final text =
                            "Hi 👋, this is your ticket for the event.\nQR Ticket for ${toBold(userName)}\nTicket ID: ${toBold(docId)}\nDon't share this with anyone.";

                        final methodChannel = MethodChannel(
                            'com.utkarsh.utkarsheventapp/whatsapp');

                        // Step 1: Open WhatsApp chat (text-only)
                        await methodChannel.invokeMethod('openWhatsAppChat', {
                          'phone': '+91$phone',
                          'text': text,
                        });

                        // Step 2: Ask user if we should proceed with image
                        await Future.delayed(
                            Duration(seconds: 2)); // wait for WhatsApp to open
                        final sendImage = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text("Send QR Image?"),
                            content: Text(
                                "Did you send a message to the person?\nIf yes, we can now send the QR image."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text("Send Image"),
                              ),
                            ],
                          ),
                        );

                        if (sendImage == true && file != null) {
                          try {
                            await methodChannel
                                .invokeMethod('shareToWhatsApp', {
                              'phone': '+91$phone',
                              'imagePath': file.path,
                              'text': text,
                            });
                          } catch (e) {
                            Fluttertoast.showToast(
                                msg: "Failed to send image: $e");
                          }
                        }
                      },
                    ),
                  if (!isLoading)
                    IconButton(
                      onPressed: () async {
                        final doc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(docId)
                            .get();

                        final data = doc.data() as Map<String, dynamic>?;
                        final Uri phoneUri = Uri(
                          scheme: 'tel',
                          path: data?['phone']?.toString() ?? '',
                        );

                        if (await canLaunchUrl(phoneUri)) {
                          await launchUrl(phoneUri);
                        } else {
                          Fluttertoast.showToast(
                              msg: "Cannot launch phone dialer");
                        }
                      },
                      icon: Icon(
                        Icons.phone,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),
              content: isLoading
                  ? SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()))
                  : RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.all(10),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('Ticket ID: $docId',
                                  style: TextStyle(fontSize: 12)),
                              SizedBox(height: 10),
                              QrImageView(
                                  data: docId,
                                  version: QrVersions.auto,
                                  size: 200),
                              SizedBox(height: 10),
                              Text('Name: $userName',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text("Don't Share This QR Code",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold)),
                            ]),
                      ),
                    ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close')),
                if (!isLoading)
                  TextButton(
                    onPressed: () async {
                      setDialog(() => isLoading = true);
                      try {
                        RenderRepaintBoundary boundary = _qrKey.currentContext!
                            .findRenderObject() as RenderRepaintBoundary;
                        final img = await boundary.toImage(pixelRatio: 3.0);
                        final byteData =
                            await img.toByteData(format: ImageByteFormat.png);
                        final bytes = byteData!.buffer.asUint8List();

                        // ✅ Use app-specific external storage
                        // final dir = Directory('/storage/emulated/0/Download');
                        final downloadsDir =
                            Directory('/storage/emulated/0/Download');
                        if (!downloadsDir.existsSync()) {
                          downloadsDir.createSync(recursive: true);
                        }

                        final stamp = DateFormat('yyyyMMdd_HHmmss')
                            .format(DateTime.now());
                        final filePath = "${downloadsDir.path}/QR_$stamp.png";

                        final file = File(filePath);
                        await file.writeAsBytes(bytes);

                        await showDownloadNotification(
                            filePath, "Ticket of $userName");

                        Fluttertoast.showToast(
                          msg: "QR saved to Downloads",
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                        );
                      } catch (e) {
                        Fluttertoast.showToast(
                          msg: "Failed to save QR: ${e.toString()}",
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        );
                      } finally {
                        setDialog(() => isLoading = false);
                      }
                    },
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Download'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(
    String docId,
    Map<String, dynamic> userData,
  ) async {
    final nameCtl = TextEditingController(text: userData['name']);
    final phoneCtl = TextEditingController(text: userData['phone']);
    final tableCtl =
        TextEditingController(text: userData['tableCount']?.toString() ?? '');
    final amountCtl =
        TextEditingController(text: userData['amount']?.toString() ?? '');
    String _selectedStatus = userData['status'];
    String _selectedGender = userData['gender'];
    String? _selectedEvent = userData['event'];
    bool validPhone = true, validTables = true, validAmount = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (ctx, setDialog) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Edit User',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  TextField(
                    controller: nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Phone
                  TextField(
                    controller: phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      errorText: validPhone ? null : 'Invalid phone number',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setDialog(() =>
                        validPhone = RegExp(r'^\d{10}$').hasMatch(v.trim())),
                  ),
                  SizedBox(height: 12),

                  // Event dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedEvent,
                    decoration: InputDecoration(
                      labelText: 'Select Event',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.events
                        .map((event) =>
                            DropdownMenuItem(value: event, child: Text(event)))
                        .toList(),
                    onChanged: (val) => setDialog(() => _selectedEvent = val),
                  ),
                  SizedBox(height: 12),

                  // Status Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Payment Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Paid', 'Not Paid']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setDialog(() => _selectedStatus = val!),
                  ),
                  if (_selectedStatus == 'Paid') ...[
                    SizedBox(height: 12),
                    TextField(
                      controller: amountCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        errorText: validAmount ? null : 'Invalid number',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setDialog(
                          () => validAmount = int.tryParse(v.trim()) != null),
                    ),
                  ],
                  SizedBox(height: 12),

                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      labelText: 'Pass Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Male', 'Female', 'Tables']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setDialog(() => _selectedGender = val!),
                  ),

                  // Table count if Tables selected
                  if (_selectedGender == 'Tables') ...[
                    SizedBox(height: 12),
                    TextField(
                      controller: tableCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'No. of People',
                        errorText: validTables ? null : 'Invalid number',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setDialog(
                          () => validTables = int.tryParse(v.trim()) != null),
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final name = nameCtl.text.trim();
                  final phone = phoneCtl.text.trim();
                  final tables = tableCtl.text.trim();
                  final amount = amountCtl.text.trim();

                  if (name.isEmpty ||
                      !validPhone ||
                      (_selectedGender == 'Tables' && !validTables) ||
                      (_selectedStatus == 'Paid' && !validAmount)) return;

                  final data = {
                    'name': name,
                    'phone': phone,
                    'status': _selectedStatus,
                    'gender': _selectedGender,
                    'event': _selectedEvent,
                    'tableCount': _selectedGender == 'Tables'
                        ? int.parse(tables)
                        : FieldValue.delete(),
                    'amount': _selectedStatus == 'Paid'
                        ? int.parse(amount)
                        : FieldValue.delete(),
                  };

                  await users.doc(docId).update(data);
                  Navigator.pop(context);
                },
                child: Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _confirmAndDelete(String docId) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Confirm Deletion'),
              content: Text('Delete this user?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ));

    if (ok == true) await users.doc(docId).delete();
  }

  Future<void> _showRegisterDialog() async {
    final nameCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final tableCtl = TextEditingController();
    final amountCtl = TextEditingController();
    bool validName = true;

    String status = 'Paid';
    String gender = 'Male';
    String? selectedEvent = widget.selectedEvent; // <-- NEW
    bool validPhone = true,
        validTables = true,
        validEvent = true,
        validAmount = true; // <-- NEW

    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (ctx, setDialog) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Register User',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Name Field
                  TextField(
                    controller: nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      border: const OutlineInputBorder(),
                      errorText: validName ? null : 'Name is required',
                    ),
                    onChanged: (value) {
                      setDialog(() => validName = value.trim().isNotEmpty);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextField(
                    controller: phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      errorText: validPhone ? null : 'Invalid phone number',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setDialog(() =>
                        validPhone = RegExp(r'^\d{10}$').hasMatch(v.trim())),
                  ),
                  const SizedBox(height: 12),

                  // Event Dropdown (NEW)
                  DropdownButtonFormField<String>(
                    value: selectedEvent,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Select Event *',
                      border: const OutlineInputBorder(),
                      errorText: validEvent ? null : 'Event is required',
                    ),
                    items: widget.events
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setDialog(() {
                      selectedEvent = val;
                      validEvent = true;
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Payment Status Dropdown
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Payment Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Paid', 'Not Paid']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setDialog(() => status = val!),
                  ),
                  if (status == 'Paid') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        errorText: validAmount ? null : 'Invalid number',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setDialog(
                          () => validAmount = int.tryParse(v.trim()) != null),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Gender / Pass Type Dropdown
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: const InputDecoration(
                      labelText: 'Pass Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Male', 'Female', 'Tables']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setDialog(() => gender = val!),
                  ),

                  // Table Count (if Tables selected)
                  if (gender == 'Tables') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: tableCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'No. of People',
                        errorText: validTables ? null : 'Invalid number',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setDialog(
                          () => validTables = int.tryParse(v.trim()) != null),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final name = nameCtl.text.trim();
                  final phone = phoneCtl.text.trim();
                  final tables = tableCtl.text.trim();
                  final amount = amountCtl.text.trim();

                  // Validate event selection
                  if (selectedEvent == null) {
                    setDialog(() => validEvent = false);
                    return;
                  }

                  if (name.isEmpty ||
                      !validPhone ||
                      (gender == 'Tables' && !validTables) ||
                      (status == 'Paid' && !validAmount)) return;

                  final entry = {
                    'name': name.toUpperCase(),
                    'phone': phone,
                    'event': selectedEvent,
                    'status': status,
                    if (status == 'Paid') 'amount': amount,
                    'gender': gender,
                    if (gender == 'Tables') 'tableCount': tables,
                    'timestamp': FieldValue.serverTimestamp(),
                    'isNotEntered': true,
                  };

                  await users.add(entry);
                  Navigator.pop(context);
                },
                child: const Text('Submit'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> downloadUserListAsExcel(
      BuildContext context, String selectedEvent) async {
    try {
      // 📱 Request permission
      if (Platform.isAndroid &&
          !(await Permission.manageExternalStorage.request().isGranted ||
              await Permission.storage.request().isGranted)) {
        Fluttertoast.showToast(
          msg: "Storage permission denied.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // 🔄 Fetch data
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('event', isEqualTo: selectedEvent)
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        Fluttertoast.showToast(
          msg: "No users found for '$selectedEvent'.",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // 🧾 Create Excel
      final Excel excel = Excel.createExcel();
      final Sheet sheet = excel['Users'];
      excel.delete('Sheet1'); // Optional: remove default empty sheet

      // ➕ Header row
      sheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Phone'),
        TextCellValue('Status'),
        TextCellValue('Amount'),
        TextCellValue('Pass Type'),
        TextCellValue('Table Count'),
        TextCellValue('Event'),
      ]);

      // ➕ Data rows
      for (final doc in snapshot.docs) {
        final data = doc.data();
        sheet.appendRow([
          TextCellValue(data['name']?.toString() ?? '-'),
          TextCellValue(data['phone']?.toString() ?? '-'),
          TextCellValue(data['status']?.toString() ?? '-'),
          TextCellValue(data['amount']?.toString() ?? '-'),
          TextCellValue(data['gender']?.toString() ?? '-'),
          TextCellValue(data['tableCount']?.toString() ?? '-'),
          TextCellValue(data['event']?.toString() ?? '-'),
        ]);
      }

      // 📦 Encode file
      final List<int>? fileBytes = excel.encode();
      if (fileBytes == null) throw Exception('Failed to encode Excel');

      // 💾 Save file
      final Uint8List bytes = Uint8List.fromList(fileBytes);
      final dir = Directory('/storage/emulated/0/Download');
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = "${dir.path}/UserList_${selectedEvent}_$stamp.xlsx";

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      await showDownloadNotification(filePath, "Excel Sheet of $selectedEvent");
      Fluttertoast.showToast(
        msg: "Excel saved to Downloads",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint("❌ Error exporting Excel: $e");
      Fluttertoast.showToast(
        msg: "Failed to save Excel",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _fetchVisitorsFromFirestore() async {
    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('event', isEqualTo: widget.selectedEvent)
          .get();

      setState(() {
        docs = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // add document ID
          return data;
        }).toList();
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to load visitors: ${e.toString()}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _paymentFilter = 'All';
      _passTypeFilter = 'All';
      _enteredFilter = 'All';
    });

    await _fetchVisitorsFromFirestore(); // Fetch fresh data
  }

  void _showViewDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          data['name'] ?? 'No Name',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            _buildRichRow('Phone', data['phone']),
            const SizedBox(height: 4),
            _buildRichRow('Status', data['status']),
            const SizedBox(height: 4),
            if (data['amount'] != null) _buildRichRow('Amount', data['amount']),
            const SizedBox(height: 4),
            _buildRichRow(
              'Entered',
              data['isNotEntered'] == true ? 'No' : 'Yes',
            ),
            const SizedBox(height: 4),
            _buildRichRow('Pass Type', data['gender']),
            const SizedBox(height: 4),
            if (data['tableCount'] != null)
              _buildRichRow('No. of People', data['tableCount']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildRichRow(String label, dynamic value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 14),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value?.toString() ?? '',
          ),
        ],
      ),
    );
  }

  void _startScan() async {
    final scannedDocId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScanPage()),
    );

    if (scannedDocId != null) {
      if (_isProbablyValidDocId(scannedDocId)) {
        _searchController.text = scannedDocId;
        setState(() {
          _searchQuery = scannedDocId;
        });
        // Optionally trigger fetch here if needed:
        // _fetchUserByDocId(scannedDocId);
      } else {
        Fluttertoast.showToast(
          msg: "Invalid QR Code scanned. Please scan a valid ticket.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  bool _isProbablyValidDocId(String input) {
    final trimmed = input.trim();

    final isValidLength = trimmed.length >= 15 && trimmed.length <= 28;
    final isAlphanumeric = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
    final isNotSuspicious = !(trimmed.startsWith('http') ||
        trimmed.startsWith('upi:') ||
        trimmed.contains('@') ||
        trimmed.contains('gpay'));

    return isValidLength && isAlphanumeric && isNotSuspicious;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (ctx, constraints) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 🔍 Search Field

                      SizedBox(
                        width: constraints.maxWidth < 600
                            ? constraints.maxWidth
                            : 350,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search by name or phone',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,

                            // ✅ Clear & QR Icons
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ❌ Clear Button (only shows when text is entered)
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    tooltip: 'Clear search',
                                  ),
                                IconButton(
                                  icon: Icon(Icons.qr_code_scanner),
                                  onPressed: _startScan,
                                  tooltip: 'Scan QR Code',
                                ),
                              ],
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.trim()),
                        ),
                      ),

                      // 📌 Payment Filter
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Status',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          _buildDropdown(
                            _paymentFilter,
                            ['All', 'Paid', 'Not Paid'],
                            (val) => setState(() => _paymentFilter = val!),
                          ),
                        ],
                      ),

                      // 🎫 Pass Type Filter
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pass Type',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          _buildDropdown(
                            _passTypeFilter,
                            ['All', 'Male', 'Female', 'Tables'],
                            (val) => setState(() => _passTypeFilter = val!),
                          ),
                        ],
                      ),

                      // ✅ Entered Filter
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entered',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          _buildDropdown(
                            _enteredFilter,
                            ['All', 'Yes', 'No'],
                            (val) => setState(() => _enteredFilter = val!),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // 🧑‍🤝‍🧑 Total Visitors + List
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: users
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (ctx, snap) {
                        if (snap.hasError)
                          return Center(child: Text('Error loading data'));
                        if (!snap.hasData)
                          return Center(child: CircularProgressIndicator());

                        final docs = snap.data!.docs
                            .map((d) {
                              final data = d.data() as Map<String, dynamic>;
                              data['id'] =
                                  d.id; // 👈 inject Firestore document ID
                              return data;
                            })
                            .where(_matchesFilters)
                            .toList();

                        // ✅ FIXED: Post-frame setState to avoid build-time errors
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _updateFilteredVisitorCount(snap.data!.docs);
                        });

                        final visitorCount = docs.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => downloadUserListAsExcel(
                                          context, widget.selectedEvent),
                                      icon: Icon(Icons.download),
                                      label: Text("Download Excel"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  AutoSizeText(
                                    maxLines: 2,
                                    "Total Count: $visitorCount",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: isLoading
                                  ? Center(child: CircularProgressIndicator())
                                  : RefreshIndicator(
                                      onRefresh: _onRefresh,
                                      child: docs.isEmpty
                                          ? ListView(
                                              physics:
                                                  AlwaysScrollableScrollPhysics(),
                                              children: [
                                                SizedBox(
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height /
                                                            3),
                                                Center(
                                                  child: Text(
                                                    'No matching visitors found',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : ListView.builder(
                                              physics:
                                                  AlwaysScrollableScrollPhysics(),
                                              padding:
                                                  EdgeInsets.only(bottom: 80),
                                              itemCount: docs.length,
                                              itemBuilder: (ctx, idx) {
                                                final data = docs[idx];
                                                final docId = data['id'];

                                                return Card(
                                                  elevation: 6,
                                                  color: Color.fromARGB(
                                                      255, 227, 225, 241),
                                                  margin: EdgeInsets.symmetric(
                                                      vertical: 6),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: ListTile(
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8),
                                                    leading: _isQrLoading
                                                        ? SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2),
                                                          )
                                                        : IconButton(
                                                            icon: Icon(
                                                                Icons.qr_code,
                                                                color: Colors
                                                                    .deepPurple),
                                                            onPressed: () =>
                                                                _showQrDialog(
                                                                    docId),
                                                          ),
                                                    title: Text(
                                                      data['name'] ?? 'No Name',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    subtitle: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                            'Phone: ${data['phone'] ?? ''}'),
                                                        Text(
                                                            'Status: ${data['status'] ?? ''}'),
                                                      ],
                                                    ),
                                                    trailing: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(
                                                              Icons
                                                                  .remove_red_eye,
                                                              color: Colors
                                                                  .deepPurple),
                                                          onPressed: () =>
                                                              _showViewDialog(
                                                                  data),
                                                        ),
                                                        PopupMenuButton<String>(
                                                          onSelected: (v) {
                                                            if (v == 'edit') {
                                                              _showEditDialog(
                                                                  docId, data);
                                                            } else if (v ==
                                                                'delete') {
                                                              _confirmAndDelete(
                                                                  docId);
                                                            }
                                                          },
                                                          itemBuilder: (ctx) =>
                                                              [
                                                            PopupMenuItem(
                                                                value: 'edit',
                                                                child: Text(
                                                                    'Edit')),
                                                            PopupMenuItem(
                                                                value: 'delete',
                                                                child: Text(
                                                                    'Delete')),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                            )
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _showRegisterDialog,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
