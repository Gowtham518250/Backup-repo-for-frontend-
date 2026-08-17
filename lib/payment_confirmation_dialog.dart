import 'package:flutter/material.dart';
import 'smart_payment_matcher_service.dart';
import 'transaction_service.dart';

/// Payment Confirmation Dialog
/// Shows when payment is detected and needs user verification
/// Handles conflicts (same amount at same time from multiple sales)
/// FIX-D: Fast 1-tap confirm path for trusted apps with high amounts
class PaymentConfirmationDialog extends StatefulWidget {
  final Transaction payment;
  final PaymentConfidence confidence;
  final VoidCallback onConfirmed;
  final VoidCallback onDenied;
  final VoidCallback? onViewDetails;

  const PaymentConfirmationDialog({
    required this.payment,
    required this.confidence,
    required this.onConfirmed,
    required this.onDenied,
    this.onViewDetails,
  });

  static void show(
    BuildContext context,
    Transaction payment,
    PaymentConfidence confidence,
    VoidCallback onConfirmed,
    VoidCallback onDenied,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentConfirmationDialog(
        payment: payment,
        confidence: confidence,
        onConfirmed: () {
          Navigator.pop(context);
          onConfirmed();
        },
        onDenied: () {
          Navigator.pop(context);
          onDenied();
        },
        onViewDetails: () {
          // Show detailed breakdown
        },
      ),
    );
  }

  @override
  State<PaymentConfirmationDialog> createState() => _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  late bool _isProcessing;

  @override
  void initState() {
    super.initState();
    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    final isMediumConfidence = widget.confidence.status == 'NEEDS_CONFIRMATION';
    final hasConflicts = widget.confidence.conflicts.isNotEmpty;

    // FIX-D: Fast 1-tap confirm for trusted app without UTR requirement
    // When decision is LIKELY + trusted app (GPay/PhonePe) + amount > ₹2000
    final isTrustedSource = _isTrustedApp(widget.payment.source);
    final isHighAmount = widget.payment.amount > 2000;
    final isLikelyConfidence = widget.confidence.score >= 60; // LIKELY tier

    if (isLikelyConfidence && isTrustedSource && isHighAmount) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.green[600], size: 56),
              const SizedBox(height: 16),
              const Text(
                'Confirm payment?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '₹${widget.payment.amount} via ${widget.payment.source}.\n'
                'No UTR found — tap Confirm if you received this.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDenied();
                      },
                      child: const Text('Not received'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // FIX-D: 1-tap confirm upgrades decision to CONFIRMED
                        // (PaymentDetectionService.userConfirmPayment call would happen in caller)
                        widget.onConfirmed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                      ),
                      child: const Text('Yes, received'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ========== STANDARD DIALOG (for all other cases) ===========

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ========== HEADER ==========
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.confidence.status.replaceAll('_', ' '),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.confidence.reason,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ========== PAYMENT DETAILS ==========
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _detailRow('Amount', '₹${widget.payment.amount}', bold: true, large: true),
                  const SizedBox(height: 12),
                  _detailRow('Name', widget.payment.name ?? 'N/A'),
                  if (widget.payment.phone != null)
                    _detailRow('Phone', widget.payment.phone!),
                  _detailRow('Source', widget.payment.source),
                  _detailRow('Time', _formatTime(widget.payment.createdAt)),
                  if (widget.payment.reference != null && widget.payment.reference!.isNotEmpty)
                    _detailRow('Reference', widget.payment.reference!, fontSize: 11),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ========== CONFIDENCE BREAKDOWN ==========
            ExpansionTile(
              title: Row(
                children: [
                  Text(
                    'Confidence Score: ${widget.confidence.score.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  _buildConfidenceBar(),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildScoreDetails(),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ========== CONFLICTS (If any) ==========
            if (hasConflicts) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Multiple payments detected with same amount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.confidence.conflicts.map((conflict) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '• $conflict',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                    Text(
                      'Please verify which sale this payment is for',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ========== ACTION BUTTONS ==========
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isProcessing ? null : _handleDeny,
                    child: const Text('Not This Payment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStatusColor(),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Confirm Payment',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ========== DETAILS BUTTON ==========
            TextButton.icon(
              onPressed: _showDetailedBreakdown,
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('View Audit Details'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== HELPERS ==========
  Color _getStatusColor() {
    switch (widget.confidence.status) {
      case 'AUTO_CONFIRMED':
        return Colors.green;
      case 'NEEDS_CONFIRMATION':
        return Colors.orange;
      case 'MANUAL_REVIEW':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.confidence.status) {
      case 'AUTO_CONFIRMED':
        return Icons.verified;
      case 'NEEDS_CONFIRMATION':
        return Icons.help_outline;
      case 'MANUAL_REVIEW':
        return Icons.warning_amber;
      default:
        return Icons.help;
    }
  }

  Widget _detailRow(
    String label,
    String value, {
    bool bold = false,
    bool large = false,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 18 : fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  List<Widget> _buildScoreDetails() {
    return (widget.confidence.details.entries).map((entry) {
      final value = entry.value.toString();
      final isPositive = value.contains('+');
      final color = isPositive ? Colors.green : (value.contains('-') ? Colors.red : Colors.grey);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.key.replaceAll(RegExp(r'_'), ' ').toUpperCase(),
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildConfidenceBar() {
    return Container(
      width: 60,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(3),
      ),
      child: Stack(
        children: [
          Container(
            width: 60 * (widget.confidence.score / 100),
            decoration: BoxDecoration(
              color: _getStatusColor(),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleConfirm() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onConfirmed();
  }

  Future<void> _handleDeny() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onDenied();
  }

  // FIX-D: Check if payment is from trusted app (GPay, PhonePe, Paytm)
  bool _isTrustedApp(String? source) {
    if (source == null) return false;
    final lowerSource = source.toLowerCase();
    return lowerSource.contains('googlepay') ||
        lowerSource.contains('google_pay') ||
        lowerSource.contains('phonpe') ||
        lowerSource.contains('phone_pe') ||
        lowerSource.contains('paytm') ||
        lowerSource.contains('gpay');
  }

  void _showDetailedBreakdown() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Matching Audit Trail',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment Details:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 8),
                _detailRow('Name', widget.payment.name ?? 'Unknown'),
                _detailRow('Amount', '₹${widget.payment.amount}'),
                _detailRow('Phone', widget.payment.phone ?? 'N/A'),
                _detailRow('Source', widget.payment.source),
                _detailRow('Reference', widget.payment.reference ?? 'N/A'),
                const SizedBox(height: 16),
                Text(
                  'Matching Score Breakdown:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildScoreDetails(),
                const SizedBox(height: 16),
                Text(
                  'Final Score: ${widget.confidence.score.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
