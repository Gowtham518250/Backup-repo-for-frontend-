import 'package:flutter/material.dart';

class QrScannerPage extends StatelessWidget {
  const QrScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner Unavailable')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('QR scanner is not available on web. Use a mobile device to scan or use the "Show QR" option to display the code.'),
        ),
      ),
    );
  }
}
