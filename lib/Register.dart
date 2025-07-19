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
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:utkarsheventapp/notification_util.dart';

class RegisterTab extends StatefulWidget {
  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final users = FirebaseFirestore.instance.collection('users');
  bool _isSubmitting = false, _isQrLoading = false;
  String _searchQuery = '';
  String _paymentFilter = 'All',
      _passTypeFilter = 'All',
      _enteredFilter = 'All';

  final _searchController = TextEditingController();
  int _filteredVisitorCount = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final q = _searchQuery.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    final phone = (data['phone'] ?? '').toString().toLowerCase();
    final status = (data['status'] ?? '').toString().toLowerCase();
    final gender = (data['gender'] ?? '').toString().toLowerCase();
    final entered = (data['isNotEntered'] == true ? 'no' : 'yes');

    return (name.contains(q) || phone.contains(q) || status.contains(q)) &&
        (_paymentFilter == 'All' || status == _paymentFilter.toLowerCase()) &&
        (_passTypeFilter == 'All' || gender == _passTypeFilter.toLowerCase()) &&
        (_enteredFilter == 'All' || entered == _enteredFilter.toLowerCase());
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
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (!isLoading)
                    IconButton(
                      icon: Icon(Icons.share, color: Colors.deepPurple),
                      onPressed: () async {
                        try {
                          RenderRepaintBoundary boundary =
                              _qrKey.currentContext!.findRenderObject()
                                  as RenderRepaintBoundary;

                          final image = await boundary.toImage(pixelRatio: 3.0);
                          final byteData = await image.toByteData(
                              format: ImageByteFormat.png);

                          if (byteData == null)
                            throw Exception("Image capture failed");

                          final pngBytes = byteData.buffer.asUint8List();

                          final tempDir = await getTemporaryDirectory();
                          final filePath =
                              '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
                          final file = await File(filePath).create();
                          await file.writeAsBytes(pngBytes);

                          await Share.shareXFiles([XFile(file.path)],
                              text: "QR Ticket for $userName");
                        } catch (e) {
                          Fluttertoast.showToast(
                            msg: "Failed to share QR: ${e.toString()}",
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                          );
                        }
                      },
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
    String _selectedStatus = userData['status'];
    String _selectedGender = userData['gender'];
    bool validPhone = true, validTables = true;

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

                  if (name.isEmpty ||
                      !validPhone ||
                      (_selectedGender == 'Tables' && !validTables)) return;

                  final data = {
                    'name': name,
                    'phone': phone,
                    'status': _selectedStatus,
                    'gender': _selectedGender,
                    'tableCount': _selectedGender == 'Tables'
                        ? int.parse(tables)
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
    String status = 'Paid', gender = 'Male';
    bool validPhone = true, validTables = true;

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
            title: Text(
              'Register User',
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

                  // Status dropdown
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: InputDecoration(
                      labelText: 'Payment Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Paid', 'Not Paid']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setDialog(() => status = val!),
                  ),
                  SizedBox(height: 12),

                  // Gender dropdown
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: InputDecoration(
                      labelText: 'Pass Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Male', 'Female', 'Tables']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setDialog(() => gender = val!),
                  ),

                  // Table count (only if 'Tables' selected)
                  if (gender == 'Tables') ...[
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

                  if (name.isEmpty ||
                      !validPhone ||
                      (gender == 'Tables' && !validTables)) return;

                  final entry = {
                    'name': name,
                    'phone': phone,
                    'status': status,
                    'gender': gender,
                    if (gender == 'Tables') 'tableCount': tables,
                    'timestamp': FieldValue.serverTimestamp(),
                    'isNotEntered': true,
                  };

                  await users.add(entry);
                  Navigator.pop(context);
                },
                child: Text('Submit'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> downloadUserListAsExcel(BuildContext context) async {
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
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        Fluttertoast.showToast(
          msg: "No users to export.",
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
        TextCellValue('Pass Type'),
        TextCellValue('Table Count'),
      ]);

      // ➕ Data rows
      for (final doc in snapshot.docs) {
        final data = doc.data();
        sheet.appendRow([
          TextCellValue(data['name']?.toString() ?? '-'),
          TextCellValue(data['phone']?.toString() ?? '-'),
          TextCellValue(data['status']?.toString() ?? '-'),
          TextCellValue(data['gender']?.toString() ?? '-'),
          TextCellValue(data['tableCount']?.toString() ?? '-'),
        ]);
      }

      // 📦 Encode file
      final List<int>? fileBytes = excel.encode();
      if (fileBytes == null) throw Exception('Failed to encode Excel');

      // 💾 Save file
      final Uint8List bytes = Uint8List.fromList(fileBytes);
      final dir = Directory('/storage/emulated/0/Download');
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = "${dir.path}/UserList_$stamp.xlsx";

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      await showDownloadNotification(filePath, "Excel Sheet of Users");
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

  void _updateFilteredVisitorCount(List<QueryDocumentSnapshot> docs) {
    final filtered = docs
        .where((doc) => _matchesFilters(doc.data() as Map<String, dynamic>))
        .toList();
    setState(() => _filteredVisitorCount = filtered.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
                            hintText: 'Search by name, phone, or status',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
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

                      // // ⬇️ Download Button
                      // Row(
                      //   children: [
                      //     ElevatedButton.icon(
                      //       onPressed: () => downloadUserListAsExcel(context),
                      //       icon: Icon(Icons.download),
                      //       label: Text("Download Excel"),
                      //       style: ElevatedButton.styleFrom(
                      //         backgroundColor: Colors.deepPurple,
                      //         foregroundColor: Colors.white,
                      //       ),
                      //     ),
                      //   ],
                      // ),
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
                            .where((d) => _matchesFilters(
                                d.data() as Map<String, dynamic>))
                            .toList();

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
                                      onPressed: () =>
                                          downloadUserListAsExcel(context),
                                      icon: Icon(Icons.download),
                                      label: Text("Download Excel"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 20,
                                  ),
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
                              child: docs.isEmpty
                                  ? Center(
                                      child: Text('No matching users found'))
                                  : ListView.builder(
                                      padding: EdgeInsets.only(bottom: 80),
                                      itemCount: docs.length,
                                      itemBuilder: (ctx, idx) {
                                        final doc = docs[idx];
                                        final data =
                                            doc.data() as Map<String, dynamic>;

                                        return Card(
                                          elevation: 6,
                                          color: Color.fromARGB(
                                              255, 227, 225, 241),
                                          margin:
                                              EdgeInsets.symmetric(vertical: 6),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
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
                                                            strokeWidth: 2),
                                                  )
                                                : IconButton(
                                                    icon: Icon(
                                                      Icons.visibility,
                                                      color: Colors.deepPurple,
                                                    ),
                                                    onPressed: () =>
                                                        _showQrDialog(doc.id),
                                                  ),
                                            title:
                                                Text(data['name'] ?? 'No Name'),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('Phone: ${data['phone']}'),
                                                Text(
                                                    'Status: ${data['status']}'),
                                                Text(
                                                    'Entered: ${data['isNotEntered'] == true ? 'No' : 'Yes'}'),
                                                Text(
                                                    'Pass Type: ${data['gender']}'),
                                                if (data['tableCount'] != null)
                                                  Text(
                                                      'No of People: ${data['tableCount']}'),
                                              ],
                                            ),
                                            trailing: PopupMenuButton<String>(
                                              onSelected: (v) {
                                                if (v == 'edit')
                                                  _showEditDialog(doc.id, data);
                                                else if (v == 'delete')
                                                  _confirmAndDelete(doc.id);
                                              },
                                              itemBuilder: (ctx) => [
                                                PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('Edit')),
                                                PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Delete')),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
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
