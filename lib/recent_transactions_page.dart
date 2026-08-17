import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'local_storage_service.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';

class RecentTransaction {
  final String transactionId;
  final String type; // 'UPI', 'CASH', 'KHATA'
  final String customerName;
  final String customerPhone;
  final double amount;
  final DateTime timestamp;
  final String status; // 'COMPLETED', 'PENDING', 'FAILED'
  final String? reference; // UPI ref, invoice ID, etc.
  final String? paymentMethod;

  RecentTransaction({
    required this.transactionId,
    required this.type,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    required this.timestamp,
    required this.status,
    this.reference,
    this.paymentMethod,
  });

  factory RecentTransaction.fromMap(Map<String, dynamic> map) => RecentTransaction(
    transactionId: map['id']?.toString() ?? '',
    type: map['type']?.toString() ?? 'CASH',
    customerName: map['customerName']?.toString() ?? 'Unknown',
    customerPhone: map['customerPhone']?.toString() ?? '',
    amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0,
    timestamp: map['timestamp'] != null 
      ? DateTime.parse(map['timestamp'].toString())
      : DateTime.now(),
    status: map['status']?.toString() ?? 'COMPLETED',
    reference: map['reference']?.toString(),
    paymentMethod: map['paymentMethod']?.toString(),
  );
}

class RecentTransactionsService {
  static Future<List<RecentTransaction>> fetchRecentTransactions({int limit = 50}) async {
    try {
      final sales = await LocalStorageService.loadSales();
      final transactions = <RecentTransaction>[];

      final today = DateTime.now();
      
      for (var sale in sales) {
        if (sale is! Map) continue;

        final saleDate = DateTime.tryParse(sale['sale_date']?.toString() ?? '');
        if (saleDate == null) continue;

        // Only get today's transactions
        if (!(saleDate.year == today.year && 
              saleDate.month == today.month && 
              saleDate.day == today.day)) continue;

        transactions.add(RecentTransaction(
          transactionId: sale['id']?.toString() ?? '',
          type: sale['payment_method']?.toString() ?? 'CASH',
          customerName: sale['customer_name']?.toString() ?? 'Walk-in Customer',
          customerPhone: sale['phone']?.toString() ?? '',
          amount: double.tryParse(sale['total']?.toString() ?? '0') ?? 0,
          timestamp: saleDate,
          status: 'COMPLETED',
          reference: sale['reference']?.toString(),
          paymentMethod: sale['payment_method']?.toString() ?? 'CASH',
        ));
      }

      // Sort by timestamp descending
      transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return transactions.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      return [];
    }
  }

  static Future<List<RecentTransaction>> fetchOnlinePayments() async {
    try {
      // ✅ Fetch from backend online payments endpoint
      final token = await SecureTokenStorage.getToken();
      if (token == null || token.isEmpty) {
        return [];
      }

      final response = await ApiClient.getJson(
        '/api/transactions/online-payments?days=30&limit=100',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactions = (data['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        return transactions.map((t) {
          DateTime timestamp;
          try {
            timestamp = DateTime.parse(t['timestamp']?.toString() ?? DateTime.now().toIso8601String());
          } catch (e) {
            timestamp = DateTime.now();
          }
          
          return RecentTransaction(
            transactionId: t['transactionId']?.toString() ?? '',
            type: 'UPI', // Online payments are marked as UPI
            customerName: t['customerName']?.toString() ?? 'Unknown',
            customerPhone: t['customerPhone']?.toString() ?? '',
            amount: double.tryParse(t['amount']?.toString() ?? '0') ?? 0,
            timestamp: timestamp,
            status: 'COMPLETED',
            reference: t['referenceId']?.toString(),
            paymentMethod: t['paymentMethod']?.toString() ?? 'UPI',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching online payments: $e');
      return [];
    }
  }
}

class RecentTransactionsPage extends StatefulWidget {
  const RecentTransactionsPage({super.key});

  @override
  State<RecentTransactionsPage> createState() => _RecentTransactionsPageState();
}

class _RecentTransactionsPageState extends State<RecentTransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RecentTransaction> _allTransactions = [];
  List<RecentTransaction> _onlineTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    final all = await RecentTransactionsService.fetchRecentTransactions();
    final online = await RecentTransactionsService.fetchOnlinePayments();

    setState(() {
      _allTransactions = all;
      _onlineTransactions = online;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('Transactions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey.shade600,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Color(0xFF6366F1), width: 3),
          ),
          tabs: [
            Tab(text: 'All (${_allTransactions.length})'),
            Tab(text: 'Online (${_onlineTransactions.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(_allTransactions),
                _buildTransactionList(_onlineTransactions),
              ],
            ),
    );
  }

  Widget _buildTransactionList(List<RecentTransaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No transactions', style: GoogleFonts.poppins()),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) => _buildTransactionCard(transactions[index]),
    );
  }

  Widget _buildTransactionCard(RecentTransaction txn) {
    final isCash = txn.type == 'CASH';
    final isKhata = txn.type == 'KHATA';

    Color typeColor = Colors.blue;
    IconData typeIcon = Icons.payment;

    if (isCash) {
      typeColor = Colors.green;
      typeIcon = Icons.money;
    } else if (isKhata) {
      typeColor = Colors.orange;
      typeIcon = Icons.book;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(typeIcon, color: typeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.customerName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            txn.customerPhone,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${txn.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    txn.status,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: txn.status == 'COMPLETED' ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(txn.timestamp),
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  txn.type,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          if (txn.reference != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Ref: ${txn.reference}',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
