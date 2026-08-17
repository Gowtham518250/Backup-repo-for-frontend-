import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _connected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPrinter();
  }

  Future<void> _initPrinter() async {
    bool? isConnected = await _bluetooth.isConnected;
    List<BluetoothDevice> devices = [];
    try {
      devices = await _bluetooth.getBondedDevices();
    } catch (e) {
      // Ignore
    }

    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('last_printer_address');

    BluetoothDevice? savedDevice;
    if (savedAddress != null && savedAddress.isNotEmpty) {
      try {
        savedDevice = devices.firstWhere((d) => d.address == savedAddress);
      } catch (e) {
        // Not found
      }
    }

    if (mounted) {
      setState(() {
        _devices = devices;
        _selectedDevice = savedDevice;
        _connected = isConnected ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _connect() async {
    if (_selectedDevice == null) return;

    setState(() => _isLoading = true);
    try {
      bool? connected = await _bluetooth.connect(_selectedDevice!);
      if (connected == true) {
        setState(() => _connected = true);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_printer_name', _selectedDevice!.name ?? '');
        await prefs.setString('last_printer_address', _selectedDevice!.address ?? '');
        
        PrinterService.updateConnectionState(true, _selectedDevice);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printer connected successfully'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    try {
      await _bluetooth.disconnect();
      setState(() => _connected = false);
      PrinterService.updateConnectionState(false, null);
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  Future<void> _testPrint() async {
    if (!_connected || _selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect a printer first')),
      );
      return;
    }
    
    // Send a test print
    await PrinterService.printTestReceipt(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('Thermal Printer', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _connected ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.print_rounded,
                            color: _connected ? Colors.green : Colors.red,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _connected ? 'Printer Connected' : 'Printer Disconnected',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (_selectedDevice != null)
                                Text(
                                  _selectedDevice!.name ?? 'Unknown Device',
                                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Paired Devices', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  if (_devices.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No paired Bluetooth printers found.\nPlease pair your thermal printer in Android Settings first.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.grey[500]),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isSelected = _selectedDevice?.address == device.address;
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isSelected ? Colors.indigo : Colors.grey[200]!, width: isSelected ? 2 : 1),
                            ),
                            child: ListTile(
                              leading: Icon(Icons.bluetooth_rounded, color: isSelected ? Colors.indigo : Colors.grey[400]),
                              title: Text(device.name ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              subtitle: Text(device.address ?? '', style: GoogleFonts.poppins(fontSize: 12)),
                              trailing: isSelected && _connected
                                  ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedDevice = device;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  
                  if (_devices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _selectedDevice == null ? null : (_connected ? _disconnect : _connect),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _connected ? Colors.red[50] : Colors.indigo,
                              foregroundColor: _connected ? Colors.red : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(
                              _connected ? 'DISCONNECT' : 'CONNECT PRINTER',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (_connected) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _testPrint,
                              icon: const Icon(Icons.receipt_long_rounded),
                              label: Text('TEST PRINT', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.indigo,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.indigo),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ]
                ],
              ),
            ),
    );
  }
}
