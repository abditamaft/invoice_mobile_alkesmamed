import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class MobileScannerScreen extends StatefulWidget {
  final Function(String) onDetected;
  const MobileScannerScreen({super.key, required this.onDetected});

  @override
  State<MobileScannerScreen> createState() => _MobileScannerScreenState();
}

class _MobileScannerScreenState extends State<MobileScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Invoice"),
        backgroundColor: const Color(0xFF11213D),
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_scanned) return;
          final barcode = capture.barcodes.first.rawValue;
          if (barcode != null) {
            _scanned = true;
            Navigator.pop(context);
            widget.onDetected(barcode);
          }
        },
      ),
    );
  }
}
