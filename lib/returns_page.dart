import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'local_storage_service.dart';
import 'format_helper.dart';
import 'visual_widgets.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> with SingleTickerProviderStateMixin {
  // Modern SaaS Colors - synced with visual_widgets.dart
  static const Color _primary = AppColors.primary;  // #635BFF
  
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _returns = [];
  bool _loading = true;
  late TabController _tabController;
  late TextEditingController _phoneController;
  String _selectedInvoiceId = '';

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sales = await LocalStorageService.loadSales();
      
      setState(() {
        _sales = sales.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _processReturn({
    required String invoiceId,
    required String productName,
    required double quantity,
    required double returnAmount,
    String? reason,
  }) async {
    // Find original sale
    final originalSale = _sales.firstWhere(
      (s) => (s['sale_id'] ?? s['id'] ?? '').toString() == invoiceId,
      orElse: () => {},
    );

    if (originalSale.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original invoice not found')),
      );
      return;
    }

    // Create return record
    final returnRecord = {
      'return_id': 'RET-${DateTime.now().millisecondsSinceEpoch}',
      'original_invoice_id': invoiceId,
      'product_name': productName,
      'quantity_returned': quantity,
      'return_amount': returnAmount,
      'reason': reason ?? 'Damage/Defect',
      'original_amount': originalSale['total'],
      'customer_name': originalSale['customer_name'],
      'customer_phone': originalSale['customer_phone'],
      'return_date': DateTime.now().toIso8601String(),
      'status': 'PROCESSED',
      'credit_note_generated': true,
    };

    // Save return
    setState(() => _returns.add(returnRecord));

    // Reverse inventory
    if (originalSale['items'] is List) {
      for (var item in originalSale['items'] as List) {
        if (item['product_name'] == productName) {
          final products = await LocalStorageService.loadBackendProducts();
          for (var product in products) {
            if (product['product_name'] == productName) {
              product['current_stock'] = (double.tryParse(product['current_stock']?.toString() ?? '0') ?? 0) + quantity;
              break;
            }
          }
          await LocalStorageService.saveBackendProducts(products);
          break;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Return processed! Credit Note: ${returnRecord['return_id']}'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Returns & Credit Notes'), backgroundColor: _primary),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalReturned = _returns.fold<double>(0, (sum, r) => sum + (r['return_amount'] as double? ?? 0));
    final returnCount = _returns.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Returns & Credit Notes'),
        backgroundColor: _primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create Return'),
            Tab(text: 'Returns History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Create Return Tab
          _buildCreateReturnTab(),

          // Returns History Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // KPI Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildKPICard(
                        'Total Returns',
                        '₹${totalReturned.toStringAsFixed(0)}',
                        Colors.orange,
                        Icons.undo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKPICard(
                        'Return Count',
                        '$returnCount',
                        Colors.blue,
                        Icons.receipt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Returns List
                Text(
                  'Return History',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._buildReturnsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateReturnTab() {
    if (_sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'No Sales Found',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a sale first to process returns',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone Number Input
          Text(
            'Enter Phone Number',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() => _selectedInvoiceId = ''),
            decoration: InputDecoration(
              hintText: 'Enter customer phone (10 digits)',
              prefixIcon: const Icon(Icons.phone_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            'Select Original Invoice (Last 3)',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Filter invoices by phone and get last 3
          Builder(
            builder: (context) {
              final phone = _phoneController.text.trim();
              final filteredSales = phone.isEmpty
                  ? []
                  : _sales
                      .where((sale) => sale['customer_phone']?.toString().contains(phone) ?? false)
                      .toList()
                      .reversed
                      .take(3)
                      .toList();

              if (phone.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_rounded, color: Colors.amber.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enter phone number to see available invoices',
                          style: GoogleFonts.poppins(color: Colors.amber.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (filteredSales.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No invoices found for this phone number',
                          style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Invoice Selection
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedInvoiceId.isEmpty ? null : _selectedInvoiceId,
                  items: filteredSales.map((sale) {
                    final invoiceId = sale['sale_id'] ?? sale['id'] ?? 'Unknown';
                    final customerName = sale['customer_name'] ?? 'Guest';
                    final amount = sale['total'] ?? 0;
                    
                    return DropdownMenuItem(
                      value: invoiceId.toString(),
                      child: Text('$invoiceId - $customerName (₹$amount)'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedInvoiceId = val ?? ''),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: InputBorder.none,
                    hintText: 'Choose invoice',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          if (_selectedInvoiceId.isNotEmpty) ...[
            _buildReturnForm(),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Center(
                child: Text(
                  'Select an invoice above to create a return',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.blue.shade700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnForm() {
    final sale = _sales.firstWhere(
      (s) => (s['sale_id'] ?? s['id'] ?? '').toString() == _selectedInvoiceId,
      orElse: () => {},
    );

    if (sale.isEmpty) return const SizedBox.shrink();

    final items = (sale['items'] as List?) ?? [];

    return Column(
      children: [
        // Original Invoice Details
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Invoice', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  Text(_selectedInvoiceId, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Customer', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  Text(sale['customer_name'] ?? 'Other', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  Text('₹${sale['total']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Product Selection for Return
        Text(
          'Select Product to Return',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value as Map;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: () => _showReturnDialog(
                invoiceId: _selectedInvoiceId,
                productName: item['product_name']?.toString() ?? 'Unknown',
                salePrice: double.tryParse(item['price']?.toString() ?? '0') ?? 0,
                saleQty: double.tryParse(item['qty']?.toString() ?? '1') ?? 1,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['product_name']?.toString() ?? 'Unknown',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Qty: ${item['qty']} @ ₹${item['price']}',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: _primary),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showReturnDialog({
    required String invoiceId,
    required String productName,
    required double salePrice,
    required double saleQty,
  }) {
    double returnQty = 1;
    String reason = 'Damage/Defect';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text("Return $productName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity to Return',
                  hintText: '1',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) => returnQty = double.tryParse(val) ?? 1,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: reason,
                items: [
                  'Damage/Defect',
                  'Wrong Item',
                  'Customer Return',
                  'Expired',
                  'Other',
                ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => reason = val ?? 'Damage/Defect'),
                decoration: InputDecoration(
                  labelText: 'Return Reason',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Return Amount: ₹${(returnQty * salePrice).toStringAsFixed(0)}',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _primary),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                _processReturn(
                  invoiceId: invoiceId,
                  productName: productName,
                  quantity: returnQty,
                  returnAmount: returnQty * salePrice,
                  reason: reason,
                );
                Navigator.pop(ctx);
                _tabController.animateTo(1);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              child: const Text('Process Return'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReturnsList() {
    return _returns.isEmpty
        ? [
            Center(
              child: Text(
                'No returns yet',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            ),
          ]
        : _returns.map((returnData) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        returnData['return_id']?.toString() ?? 'Unknown',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PROCESSED',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invoice: ${returnData['original_invoice_id']}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Product: ${returnData['product_name']} (Qty: ${returnData['quantity_returned']})',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  Text(
                    'Reason: ${returnData['reason']}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd').format(DateTime.parse(returnData['return_date']?.toString() ?? '')),
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Text(
                        '₹${returnData['return_amount']}',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList();
  }

  Widget _buildKPICard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
