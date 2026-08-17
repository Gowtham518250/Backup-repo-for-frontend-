import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'transaction_service.dart';

class TransactionRecorderPage extends StatefulWidget {
  const TransactionRecorderPage({super.key});

  @override
  State<TransactionRecorderPage> createState() => _TransactionRecorderPageState();
}

class _TransactionRecorderPageState extends State<TransactionRecorderPage> {
  static const Color _primary = Color(0xFF6366F1);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'PAID'; // PAID, RECEIVED, PENDING
  String _selectedSource = 'Manual';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final txn = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: _selectedSource,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        amount: double.parse(_amountController.text),
        type: _selectedType,
        createdAt: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        reference: null,
      );

      await TransactionService.saveTransaction(txn);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Transaction recorded successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Record Transaction',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Type
              Text('Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton('PAID', _selectedType == 'PAID', () {
                      setState(() => _selectedType = 'PAID');
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypeButton('RECEIVED', _selectedType == 'RECEIVED', () {
                      setState(() => _selectedType = 'RECEIVED');
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypeButton('PENDING', _selectedType == 'PENDING', () {
                      setState(() => _selectedType = 'PENDING');
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Source
              Text('Source', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton(
                  value: _selectedSource,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: ['Manual', 'SMS_BANK', 'UPI', 'WhatsApp', 'Other']
                      .map((src) => DropdownMenuItem(
                            value: src,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(src, style: GoogleFonts.poppins(fontSize: 13)),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSource = val);
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Customer Name
              Text('Customer Name', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Raj Kumar, Family Store',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              // Phone
              Text('Phone Number', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '10-digit phone number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length != 10) {
                    return 'Phone must be 10 digits';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              // Amount
              Text('Amount (₹)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(val) == null) {
                    return 'Invalid amount';
                  }
                  if (double.parse(val) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              // Date
              Text('Date & Time', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy hh:mm a').format(_selectedDate),
                    style: GoogleFonts.poppins(color: Colors.black, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Notes
              Text('Notes (Optional)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any notes about this transaction...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text(
                          'Save Transaction',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, bool isSelected, VoidCallback onTap) {
    final colors = {
      'PAID': Colors.red,
      'RECEIVED': Colors.green,
      'PENDING': Colors.orange,
    };
    final color = colors[label] ?? Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey[50],
          border: Border.all(color: isSelected ? color : Colors.grey[300]!, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected ? color : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
