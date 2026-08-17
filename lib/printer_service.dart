import 'dart:async';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'printer_settings_page.dart';

class PrinterService {
  static BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  static BluetoothDevice? _selectedDevice;
  static bool _isConnected = false;

  /// Get available Bluetooth printers
  static Future<List<BluetoothPrinter>> getAvailablePrinters() async {
    final devices = await bluetooth.getBondedDevices();
    return devices.map((device) => BluetoothPrinter(
      deviceName: device.name,
      address: device.address,
    )).toList();
  }

  static void updateConnectionState(bool connected, BluetoothDevice? device) {
    _isConnected = connected;
    _selectedDevice = device;
  }

  /// Connect to the selected printer
  static Future<bool> connect(BluetoothPrinter device) async {
    try {
      final bluetoothDevice = BluetoothDevice(device.deviceName, device.address);
      await bluetooth.connect(bluetoothDevice);
      _selectedDevice = bluetoothDevice;
      _isConnected = true;

      // Save last used printer
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_printer_name', device.deviceName ?? '');
      await prefs.setString('last_printer_address', device.address ?? '');

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('last_printer_address');
      final savedName = prefs.getString('last_printer_name');
      
      if (savedAddress != null && savedAddress.isNotEmpty) {
        final device = BluetoothPrinter(deviceName: savedName, address: savedAddress);
        await connect(device);
      }
    } catch (e) {
      // ignore
    }
  }

  /// Disconnect from the printer
  static Future<void> disconnect() async {
    try {
      await bluetooth.disconnect();
      _selectedDevice = null;
      _isConnected = false;
    } catch (e) {}
  }

  /// Print bill receipt
  static Future<void> printBill({
    required BuildContext context,
    required String invoiceId,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    double gstPercent = 18.0,
  }) async {
    if (!_isConnected || _selectedDevice == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🔵 Bluetooth printer not found — tap to reconnect.'),
            action: SnackBarAction(
              label: 'Reconnect',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrinterSettingsPage()),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    try {
      // Get shop details
      final prefs = await SharedPreferences.getInstance();
      final shopName = prefs.getString('shop_name') ?? 'Shop Name';
      final shopAddress = prefs.getString('shop_address') ?? '';
      final shopPhone = prefs.getString('shop_phone') ?? '';
      final shopGst = prefs.getString('shop_gst') ?? '';

      bluetooth.printNewLine();
      bluetooth.printCustom(shopName, 3, 1);
      bluetooth.printNewLine();

      if (shopAddress.isNotEmpty) {
        bluetooth.printCustom(shopAddress, 1, 1);
        bluetooth.printNewLine();
      }

      if (shopPhone.isNotEmpty) {
        bluetooth.printCustom("Tel: $shopPhone", 1, 1);
        bluetooth.printNewLine();
      }

      if (shopGst.isNotEmpty) {
        bluetooth.printCustom("GSTIN: $shopGst", 1, 1);
        bluetooth.printNewLine();
      }

      bluetooth.printCustom("TAX INVOICE", 2, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Bill No: $invoiceId", 1, 0);
      bluetooth.printNewLine();
      bluetooth.printCustom("Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}", 1, 0);
      bluetooth.printNewLine();
      bluetooth.printCustom("Customer: $customerName", 1, 0);
      bluetooth.printNewLine();
      bluetooth.printCustom("-" * 32, 1, 1);
      bluetooth.printNewLine();

      // Items header
      bluetooth.printLeftRight("Item", "Qty  Price", 1);
      bluetooth.printCustom("-" * 32, 1, 1);
      bluetooth.printNewLine();

      double subTotal = 0.0;
      for (var item in items) {
        final name = item['product_name'] ?? 'Item';
        final qty = item['qty'] ?? '1';
        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        subTotal += price;

        // Handle long names
        if (name.length > 20) {
          bluetooth.printCustom(name.substring(0, 20), 1, 0);
          bluetooth.printNewLine();
          bluetooth.printLeftRight("", "$qty x ${price.toStringAsFixed(2)}", 1);
        } else {
          bluetooth.printLeftRight(name, "$qty x ${price.toStringAsFixed(2)}", 1);
        }
        bluetooth.printNewLine();
      }

      bluetooth.printCustom("-" * 32, 1, 1);
      bluetooth.printNewLine();

      // Totals
      final gstAmount = subTotal * gstPercent / 100;
      final total = subTotal + gstAmount;

      bluetooth.printLeftRight("Subtotal", subTotal.toStringAsFixed(2), 1);
      bluetooth.printNewLine();
      bluetooth.printLeftRight("GST ($gstPercent%)", gstAmount.toStringAsFixed(2), 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("-" * 32, 1, 1);
      bluetooth.printNewLine();
      bluetooth.printLeftRight("TOTAL", "Rs ${total.toStringAsFixed(2)}", 3); // Bold large font
      bluetooth.printNewLine();
      bluetooth.printCustom("-" * 32, 1, 1);
      bluetooth.printNewLine();

      // Premium QR Code addition
      bluetooth.printCustom("Scan to view online", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printQRcode("https://aishop.invoice/view/$invoiceId", 200, 200, 1);
      bluetooth.printNewLine();

      bluetooth.printCustom("Thank You! Visit Again", 2, 1); // Bold thank you
      bluetooth.printNewLine();
      bluetooth.printCustom("Terms: No returns without bill", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill printed successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  static Future<void> printTestReceipt({required BuildContext context}) async {
    if (!_isConnected || _selectedDevice == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🔵 Bluetooth printer not found — tap to reconnect.'),
            action: SnackBarAction(
              label: 'Reconnect',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrinterSettingsPage()),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    try {
      bluetooth.printNewLine();
      bluetooth.printCustom("PRINTER TEST", 3, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("AI Shop Pro", 2, 1);
      bluetooth.printCustom("Bluetooth ESC/POS Printing OK", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printLeftRight("Left Align", "Right Align", 1);
      bluetooth.printNewLine();
      bluetooth.printQRcode("https://aishop.invoice/test", 200, 200, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("-" * 32, 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print sent')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test print failed: $e')),
        );
      }
    }
  }
}

class BluetoothPrinter {
  final String? deviceName;
  final String? address;
  final bool isBle;

  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.isBle = false,
  });

  static Future<bool> printBillWithRecovery({
    required BuildContext context,
    required String invoiceId,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    double gstPercent = 18.0,
  }) async {
    bool printSuccess = false;
    int retryCount = 0;
    const maxRetries = 3;

    while (!printSuccess && retryCount < maxRetries) {
      try {
        await PrinterService.printBill(
          context: context,
          invoiceId: invoiceId,
          customerName: customerName,
          items: items,
          totalAmount: totalAmount,
          gstPercent: gstPercent,
        );
        printSuccess = true;
      } catch (e) {
        retryCount++;
        if (!context.mounted) break;
        
        // Show Recovery UI using Dialog
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.print_disabled, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Printer Error', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text('The printer disconnected or is out of paper. The invoice is securely saved. Do you want to retry printing?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CONTINUE WITHOUT PRINTING', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('RETRY PRINT'),
              ),
            ],
          ),
        );
        
        if (retry != true) {
          break; // User chose to continue without printing
        }
        
        // Try to auto-connect before next retry
        await PrinterService.autoConnect();
      }
    }
    
    return printSuccess;
  }
}
