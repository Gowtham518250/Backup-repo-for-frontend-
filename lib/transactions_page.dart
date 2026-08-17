import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'transaction_service.dart';
import 'format_helper.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  static const Color _primary = Color(0xFF6366F1);
  
  List<Transaction> _transactions = [];
  bool _loading = true;
  String _filterType = 'ALL'; // ALL, PAID, RECEIVED, PENDING
  String _selectedSource = 'ALL'; // ALL, Manual, SMS, UPI, etc.
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
      final txns = await TransactionService.loadTransactions();
      
      double total = 0;
      for (var t in txns) {
        total += t.amount;
      }

      setState(() {
        _transactions = txns;
        _totalAmount = total;
        _loading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _loading = false);
    }
  }

  List<Transaction> get _filteredTransactions {
    return _transactions.where((t) {
      bool typeMatch = _filterType == 'ALL' || t.type == _filterType;
      bool sourceMatch = _selectedSource == 'ALL' || t.source == _selectedSource;
      return typeMatch && sourceMatch;
    }).toList();
  }

  void _showDeleteDialog(Transaction txn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Delete transaction of ₹${txn.amount} from ${txn.name ?? "Unknown"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TransactionService.deleteTransaction(txn.id);
              await _loadTransactions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Transaction deleted'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTxns = _filteredTransactions;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Transaction History',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Transactions', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('₹${_totalAmount.toStringAsFixed(0)}', 
                            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                          Text('${_transactions.length} entries',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('Type: All', _filterType == 'ALL', () {
                        setState(() => _filterType = 'ALL');
                      }),
                      _buildFilterChip('Type: Paid', _filterType == 'PAID', () {
                        setState(() => _filterType = 'PAID');
                      }),
                      _buildFilterChip('Type: Received', _filterType == 'RECEIVED', () {
                        setState(() => _filterType = 'RECEIVED');
                      }),
                      _buildFilterChip('Src: All', _selectedSource == 'ALL', () {
                        setState(() => _selectedSource = 'ALL');
                      }),
                      _buildFilterChip('Src: Manual', _selectedSource == 'Manual', () {
                        setState(() => _selectedSource = 'Manual');
                      }),
                      _buildFilterChip('Src: SMS', _selectedSource == 'SMS_BANK', () {
                        setState(() => _selectedSource = 'SMS_BANK');
                      }),
                      _buildFilterChip('Src: UPI', _selectedSource == 'UPI', () {
                        setState(() => _selectedSource = 'UPI');
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Transactions List
                if (filteredTxns.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No transactions', style: GoogleFonts.poppins(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredTxns.length,
                      itemBuilder: (ctx, idx) {
                        final txn = filteredTxns[idx];
                        return _buildTransactionCard(txn);
                      },
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/transaction-recorder').then((_) {
            _loadTransactions();
          });
        },
        backgroundColor: _primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction txn) {
    final isReceived = txn.type == 'RECEIVED';
    final colors = {
      'PAID': Colors.red,
      'RECEIVED': Colors.green,
      'PENDING': Colors.orange,
    };
    final color = colors[txn.type] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.name ?? 'Unknown',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${txn.phone ?? ''} • ${txn.source}',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, hh:mm a').format(txn.createdAt),
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Amount & Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${txn.amount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: color),
              ),
              const SizedBox(height: 4),
              PopupMenuButton(
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    child: const Text('View Details'),
                    onTap: () {
                      _showTransactionDetails(txn);
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      _showDeleteDialog(txn);
                    },
                  ),
                ],
                child: Icon(Icons.more_vert, color: Colors.grey[600], size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(Transaction txn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transaction Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Name:', txn.name ?? 'N/A'),
              _detailRow('Phone:', txn.phone ?? 'N/A'),
              _detailRow('Amount:', '₹${txn.amount}'),
              _detailRow('Type:', txn.type),
              _detailRow('Source:', txn.source),
              _detailRow('Reference:', txn.reference ?? 'N/A'),
              _detailRow('Date:', DateFormat('MMM dd, yyyy hh:mm a').format(txn.createdAt)),
              if (txn.notes != null) _detailRow('Notes:', txn.notes!),
              if (txn.rawMessage != null) ...[
                const SizedBox(height: 12),
                Text('Raw Message:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(txn.rawMessage!, style: const TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}
