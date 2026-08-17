import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'local_storage_service.dart';
import 'sync_queue_manager.dart';
import 'sync_service.dart';

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});
  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  bool _loading = true;
  List<dynamic> _orders = [];

  static const _bg = Color(0xFF1A1A2E);
  static const _card = Color(0xFF16213E);

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      // Load from local storage first for immediate response (offline-first)
      final prefs = await SharedPreferences.getInstance();
      final localPOData = prefs.getString('purchase_orders_data');
      
      if (localPOData != null && localPOData.isNotEmpty) {
        try {
          final d = jsonDecode(localPOData);
          setState(() => _orders = d is List ? d : (d['orders'] ?? []));
          debugPrint('✅ Purchase orders loaded from local storage');
        } catch (e) {
          debugPrint('⚠️ Error parsing local PO data: $e');
        }
      }
      
      // Then sync with backend for latest data
      try {
        final res = await ApiClient.getJson('/purchase-orders/');
        if (res.statusCode == 200) {
          final d = jsonDecode(res.body);
          setState(() => _orders = d is List ? d : (d['orders'] ?? []));
          // Save to local storage for offline use
          await prefs.setString('purchase_orders_data', json.encode(d));
          debugPrint('✅ Purchase orders synced from backend');
        }
      } catch (e) {
        debugPrint('⚠️ Backend PO sync failed, using local data: $e');
        // Keep using local data if backend sync fails
      }
    } catch (e) {
      debugPrint('❌ PO fetch error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED': return Colors.greenAccent;
      case 'CANCELLED': return Colors.redAccent;
      default: return Colors.orangeAccent;
    }
  }

  Future<void> _markDelivered(dynamic poId) async {
    try {
      final res = await ApiClient.postJson('/purchase-orders/$poId/mark-delivered', {}).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 && res.statusCode != 201) throw Exception('status ${res.statusCode}');
    } catch (e) {
      debugPrint('⚠️ Failed to mark PO as delivered live, queuing for retry: $e');
      // 🔧 FIX: previously a failure here was just logged and dropped —
      // the PO would silently stay PENDING forever with no retry.
      await SyncQueueManager.enqueue('update_purchase_order_status', {
        'po_id': poId,
        'po_action': 'mark-delivered',
      });
      unawaited(SyncService.processQueueSafe());
    }
    await _fetchOrders();
  }

  Future<void> _cancelPO(dynamic poId) async {
    try {
      final res = await ApiClient.postJson('/purchase-orders/$poId/cancel', {}).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 && res.statusCode != 201) throw Exception('status ${res.statusCode}');
    } catch (e) {
      debugPrint('⚠️ Failed to cancel PO live, queuing for retry: $e');
      await SyncQueueManager.enqueue('update_purchase_order_status', {
        'po_id': poId,
        'po_action': 'cancel',
      });
      unawaited(SyncService.processQueueSafe());
    }
    _fetchOrders();
  }

  /// 🔧 FIX: previously this always sent `'items': []` — the backend's
  /// PurchaseOrderCreate schema requires `items: List[POItem]` with at
  /// least one entry (`min_length=1`), so every single "Create PO" here
  /// was rejected by the backend with a 422 the moment it tried to sync.
  /// This also durably queues the create so a flaky connection doesn't
  /// silently lose the order (matches the retry pattern used for sales).
  Future<void> _createPurchaseOrder(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('purchase_orders_data');
      final list = <dynamic>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) list.addAll(decoded);
      }
      final localOrder = {...payload, 'id': 'LOCAL-PO-${DateTime.now().millisecondsSinceEpoch}', 'status': 'PENDING', 'created_at': DateTime.now().toIso8601String(), 'sync_status': 'pending'};
      list.insert(0, localOrder);
      await prefs.setString('purchase_orders_data', jsonEncode(list));
      if (mounted) setState(() => _orders = list);

      final res = await ApiClient.postJson('/purchase-orders/', payload).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchOrders();
        return;
      }
      throw Exception('Backend rejected PO: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('⚠️ PO create failed live, queuing for retry: $e');
      await SyncQueueManager.enqueue('create_purchase_order', payload);
      unawaited(SyncService.processQueueSafe());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase order saved offline and queued for sync.')));
    }
  }

  void _showCreatePO() {
    final supplierC = TextEditingController();
    final notesC = TextEditingController();
    List<Map<String, dynamic>> orderItems = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickProduct() async {
            final products = await LocalStorageService.loadBackendProducts();
            if (!ctx.mounted) return;
            final selected = await showDialog<Map<String, dynamic>>(
              context: ctx,
              builder: (dCtx) => AlertDialog(
                backgroundColor: _card,
                title: const Text('Select Product', style: TextStyle(color: Colors.white)),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 340,
                  child: products.isEmpty
                      ? const Center(child: Text('No products in inventory yet', style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (_, i) {
                            final p = products[i];
                            return ListTile(
                              title: Text(p['product_name']?.toString() ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                              subtitle: Text('Stock: ${p['current_stock'] ?? 0}', style: const TextStyle(color: Colors.white38)),
                              onTap: () => Navigator.pop(dCtx, p),
                            );
                          },
                        ),
                ),
              ),
            );
            if (selected == null || !ctx.mounted) return;

            final qtyC = TextEditingController(text: '1');
            final costC = TextEditingController(text: (selected['price'] ?? 0).toString());
            final add = await showDialog<bool>(
              context: ctx,
              builder: (dCtx) => AlertDialog(
                backgroundColor: _card,
                title: Text(selected['product_name']?.toString() ?? 'Item', style: const TextStyle(color: Colors.white)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  _field(qtyC, 'Quantity', numeric: true),
                  const SizedBox(height: 12),
                  _field(costC, 'Unit Cost (₹)', numeric: true),
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Add')),
                ],
              ),
            );
            final qty = int.tryParse(qtyC.text.trim()) ?? 0;
            if (add == true && qty > 0) {
              setModalState(() {
                orderItems.add({
                  'product_id': selected['id'],
                  'product_name': selected['product_name'],
                  'quantity': qty,
                  'unit_cost': double.tryParse(costC.text.trim()) ?? 0.0,
                });
              });
            }
          }

          final total = orderItems.fold<double>(
            0.0,
            (sum, it) => sum + ((it['quantity'] as int) * (it['unit_cost'] as num).toDouble()),
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Purchase Order', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _field(supplierC, 'Supplier Name'),
                  const SizedBox(height: 12),
                  _field(notesC, 'Notes (optional)'),
                  const SizedBox(height: 16),
                  Text('Items (at least one required)', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...orderItems.asMap().entries.map((e) {
                    final i = e.key;
                    final it = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Expanded(child: Text('${it['product_name']}', style: const TextStyle(color: Colors.white))),
                        Text('${it['quantity']} × ₹${it['unit_cost']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => setModalState(() => orderItems.removeAt(i)),
                        ),
                      ]),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: pickProduct,
                    icon: const Icon(Icons.add, color: Colors.indigoAccent),
                    label: const Text('Add Item', style: TextStyle(color: Colors.indigoAccent)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.indigoAccent)),
                  ),
                  const SizedBox(height: 12),
                  Text('Estimated Total: ₹${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final supplierName = supplierC.text.trim();
                        if (supplierName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Supplier name is required')));
                          return;
                        }
                        if (orderItems.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Add at least one item')));
                          return;
                        }
                        final payload = {
                          'supplier_name': supplierName,
                          'items': orderItems,
                          if (notesC.text.trim().isNotEmpty) 'notes': notesC.text.trim(),
                        };
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _createPurchaseOrder(payload);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Create PO', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {bool numeric = false}) {
    return TextField(
      controller: c,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: Text('Purchase Orders', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigoAccent,
        onPressed: _showCreatePO,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              child: _orders.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.receipt_long, color: Colors.white24, size: 80),
                      const SizedBox(height: 16),
                      Text('No purchase orders yet', style: GoogleFonts.poppins(color: Colors.white38)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (ctx, i) {
                        final po = _orders[i];
                        final status = (po['status'] ?? 'PENDING').toString().toUpperCase();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('PO #${po['id'] ?? i + 1}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                child: Text(status, style: GoogleFonts.poppins(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text(po['supplier_name']?.toString() ?? 'Supplier', style: GoogleFonts.poppins(color: Colors.white70)),
                            Text('Rs ${po['total_cost']?.toString() ?? '0'}', style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                            if (status == 'PENDING') ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _markDelivered(po['id']),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Delivered'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _cancelPO(po['id']),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Cancel'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                  ),
                                ),
                              ]),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
    );
  }
}