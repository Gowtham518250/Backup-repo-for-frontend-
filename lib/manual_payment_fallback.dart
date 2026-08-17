import 'package:flutter/material.dart';
import 'payment_event.dart';

/// Manual Payment Fallback Widget - Record payment when auto-detection fails
class ManualPaymentFallbackWidget extends StatefulWidget {
  final double saleAmount;
  final Function(ManualPaymentEntry) onPaymentRecorded;
  final Function()? onCancel;
  
  const ManualPaymentFallbackWidget({
    required this.saleAmount,
    required this.onPaymentRecorded,
    this.onCancel,
    Key? key,
  }) : super(key: key);
  
  @override
  State<ManualPaymentFallbackWidget> createState() => 
      _ManualPaymentFallbackWidgetState();
}

class _ManualPaymentFallbackWidgetState 
    extends State<ManualPaymentFallbackWidget> {
  
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  String _selectedMethod = 'CASH';
  String? _selectedBank;
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.saleAmount.toString();
  }
  
  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.warning_amber, color: Colors.amber[700]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manual Payment Entry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Auto-detection failed. Record manually.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      widget.onCancel?.call();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Amount
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount Received (₹)',
                  suffixText: '₹',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Payment Method
              DropdownButtonFormField<String>(
                value: _selectedMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('💵 Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('📱 UPI')),
                  DropdownMenuItem(value: 'CARD', child: Text('💳 Card')),
                  DropdownMenuItem(value: 'BANK', child: Text('🏦 Bank Transfer')),
                  DropdownMenuItem(value: 'CHEQUE', child: Text('📄 Cheque')),
                ]
                    .map((item) => DropdownMenuItem(
                      value: item.value,
                      child: item.child,
                    ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedMethod = value!),
              ),
              const SizedBox(height: 16),
              
              // Bank selection for non-cash payments
              if (_selectedMethod != 'CASH') ...[
                DropdownButtonFormField<String>(
                  value: _selectedBank,
                  decoration: InputDecoration(
                    labelText: 'Bank / UPI App',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    'HDFC Bank',
                    'SBI Bank',
                    'ICICI Bank',
                    'Axis Bank',
                    'Google Pay',
                    'PhonePe',
                    'Paytm',
                    'Other',
                  ]
                      .map((bank) => DropdownMenuItem(
                        value: bank,
                        child: Text(bank),
                      ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedBank = value),
                ),
                const SizedBox(height: 16),
              ],
              
              // Reference ID
              TextField(
                controller: _refCtrl,
                decoration: InputDecoration(
                  labelText: _selectedMethod == 'CASH'
                      ? 'Notes (optional)'
                      : 'Reference ID / UTR',
                  hintText: _selectedMethod == 'CASH'
                      ? 'e.g., received by Raj'
                      : 'e.g., 123456789012',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This payment will be recorded immediately. You can verify it in the transaction history.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[800],
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _recordPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('✓ Record Payment'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _recordPayment() async {
    try {
      setState(() => _isProcessing = true);
      
      final amount = double.tryParse(_amountCtrl.text) ?? widget.saleAmount;
      
      // Validate amount
      if (amount <= 0) {
        _showError('Amount must be greater than 0');
        return;
      }
      
      if (amount > widget.saleAmount * 2) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ Amount Mismatch'),
            content: Text(
              'Received amount (₹$amount) is more than 2x the sale amount (₹${widget.saleAmount}).\n\nContinue?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ?? false;
        
        if (!confirm) return;
      }
      
      // Validate reference for non-cash
      if (_selectedMethod != 'CASH' && _refCtrl.text.isEmpty) {
        _showError('Reference ID required for $_selectedMethod payments');
        return;
      }
      
      final entry = ManualPaymentEntry(
        amount: amount,
        method: _selectedMethod,
        bank: _selectedBank,
        referenceId: _refCtrl.text.isNotEmpty ? _refCtrl.text : null,
        timestamp: DateTime.now(),
        isManualEntry: true,
      );
      
      widget.onPaymentRecorded(entry);
      
      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Payment recorded successfully! ✅');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Data model for manually entered payment
class ManualPaymentEntry {
  final double amount;
  final String method;      // CASH, UPI, CARD, BANK, CHEQUE
  final String? bank;       // Optional bank/app name
  final String? referenceId; // Optional: UTR, Ref No., etc.
  final DateTime timestamp;
  final bool isManualEntry;
  
  ManualPaymentEntry({
    required this.amount,
    required this.method,
    this.bank,
    this.referenceId,
    required this.timestamp,
    this.isManualEntry = true,
  });
  
  Map<String, dynamic> toJson() => {
    'amount': amount,
    'method': method,
    'bank': bank,
    'referenceId': referenceId,
    'timestamp': timestamp.toIso8601String(),
    'isManualEntry': isManualEntry,
  };
}
