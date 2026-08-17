import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'scheme_engine.dart';
import 'visual_widgets.dart';

class SchemesPage extends StatefulWidget {
  const SchemesPage({super.key});

  @override
  State<SchemesPage> createState() => _SchemesPageState();
}

class _SchemesPageState extends State<SchemesPage> {
  // Modern SaaS Colors - synced with visual_widgets.dart
  static const Color _primary = AppColors.primary;  // #635BFF
  
  List<Map<String, dynamic>> _schemes = [];
  bool _loading = true;
  String _selectedType = SchemeEngine.PERCENT_OFF;

  @override
  void initState() {
    super.initState();
    _loadSchemes();
  }

  Future<void> _loadSchemes() async {
    final schemes = await SchemeEngine.loadSchemes();
    setState(() {
      _schemes = schemes;
      _loading = false;
    });
  }

  Future<void> _deleteScheme(String schemeId) async {
    await SchemeEngine.deleteScheme(schemeId);
    await _loadSchemes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Scheme deleted'), backgroundColor: Colors.green),
      );
    }
  }

  void _showCreateSchemeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateSchemeBottomSheet(
        onSchemeCreated: _loadSchemes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers & Promotions'),
        backgroundColor: _primary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _schemes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.local_offer_rounded, size: 60, color: _primary),
                        ),
                        const SizedBox(height: 24),
                        Text('No Offers Yet',
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text('Create your first offer to boost sales!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _showCreateSchemeDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Offer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _schemes.length,
                  itemBuilder: (_, idx) => _buildSchemeCard(_schemes[idx]),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        onPressed: _showCreateSchemeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSchemeCard(Map<String, dynamic> scheme) {
    final type = scheme['type']?.toString() ?? '';
    final name = scheme['name']?.toString() ?? 'Unnamed';
    final schemeId = scheme['id']?.toString() ?? '';
    final active = scheme['active'] as bool? ?? true;

    String subtitle = '';
    if (type == SchemeEngine.PERCENT_OFF) {
      final percent = (scheme['percent'] as num?)?.toDouble() ?? 0;
      final minOrder = (scheme['min_order'] as num?)?.toDouble() ?? 0;
      subtitle = '$percent% off on orders above ₹${minOrder.toInt()}';
    } else if (type == SchemeEngine.FLAT_OFF) {
      final flatAmount = (scheme['flat_amount'] as num?)?.toDouble() ?? 0;
      final minOrder = (scheme['min_order'] as num?)?.toDouble() ?? 0;
      subtitle = 'Flat ₹${flatAmount.toInt()} off on ₹${minOrder.toInt()}+';
    } else if (type == SchemeEngine.BOGO) {
      final triggerQty = (scheme['trigger_qty'] as num?)?.toInt() ?? 0;
      subtitle = 'Buy $triggerQty Get 1 Free';
    } else if (type == SchemeEngine.MIN_QTY_FREE) {
      final minQty = (scheme['min_qty'] as num?)?.toInt() ?? 0;
      final price = (scheme['price_per_unit'] as num?)?.toDouble() ?? 0;
      subtitle = 'Buy $minQty Get ₹${price.toInt()} off';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? _primary.withValues(alpha: 0.3) : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? _primary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    active ? 'Active' : 'Inactive',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? _primary : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit'),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _deleteScheme(schemeId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreateSchemeBottomSheet extends StatefulWidget {
  final VoidCallback onSchemeCreated;

  const CreateSchemeBottomSheet({super.key, required this.onSchemeCreated});

  @override
  State<CreateSchemeBottomSheet> createState() => _CreateSchemeBottomSheetState();
}

class _CreateSchemeBottomSheetState extends State<CreateSchemeBottomSheet> {
  static const Color _primary = Color(0xFF6366F1);
  
  String _type = SchemeEngine.PERCENT_OFF;
  final _nameCtrl = TextEditingController();
  final _value1Ctrl = TextEditingController();
  final _value2Ctrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _value1Ctrl.dispose();
    _value2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _createScheme() async {
    if (_nameCtrl.text.isEmpty || _value1Ctrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    try {
      Map<String, dynamic> scheme = {
        'type': _type,
        'name': _nameCtrl.text,
        'active': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (_type == SchemeEngine.PERCENT_OFF) {
        scheme['percent'] = double.parse(_value1Ctrl.text);
        scheme['min_order'] = double.parse(_value2Ctrl.text);
      } else if (_type == SchemeEngine.FLAT_OFF) {
        scheme['flat_amount'] = double.parse(_value1Ctrl.text);
        scheme['min_order'] = double.parse(_value2Ctrl.text);
      } else if (_type == SchemeEngine.BOGO) {
        scheme['trigger_qty'] = int.parse(_value1Ctrl.text);
        scheme['free_item_price'] = double.parse(_value2Ctrl.text);
      } else if (_type == SchemeEngine.MIN_QTY_FREE) {
        scheme['min_qty'] = int.parse(_value1Ctrl.text);
        scheme['price_per_unit'] = double.parse(_value2Ctrl.text);
      }

      scheme['valid_from'] = DateTime.now().toIso8601String();
      scheme['valid_upto'] = DateTime.now().add(const Duration(days: 30)).toIso8601String();

      await SchemeEngine.saveScheme(scheme);

      if (mounted) {
        Navigator.pop(context);
        widget.onSchemeCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Scheme created!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 28, color: _primary, margin: const EdgeInsets.only(right: 12)),
                Text('Create New Offer',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Offer Name', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'e.g., Flash Sale, Bulk Discount',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Offer Type', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                DropdownMenuItem(value: SchemeEngine.PERCENT_OFF, child: const Text('% Off on Min Order')),
                DropdownMenuItem(value: SchemeEngine.FLAT_OFF, child: const Text('Flat ₹ Off on Min Order')),
                DropdownMenuItem(value: SchemeEngine.BOGO, child: const Text('Buy X Get 1 Free')),
                DropdownMenuItem(value: SchemeEngine.MIN_QTY_FREE, child: const Text('Buy X Get ₹ Off')),
              ],
              onChanged: (v) => setState(() {
                _type = v ?? SchemeEngine.PERCENT_OFF;
                _value1Ctrl.clear();
                _value2Ctrl.clear();
              }),
            ),
            const SizedBox(height: 16),
            _buildInputFields(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _createScheme,
                child: Text('Create Offer',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFields() {
    if (_type == SchemeEngine.PERCENT_OFF) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Discount %', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _value1Ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g., 10 for 10%'),
          ),
          const SizedBox(height: 16),
          Text('Minimum Order Amount', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _value2Ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g., 500'),
          ),
        ],
      );
    } else if (_type == SchemeEngine.FLAT_OFF) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Flat Discount Amount (₹)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _value1Ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g., 100'),
          ),
          const SizedBox(height: 16),
          Text('Minimum Order Amount', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _value2Ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g., 500'),
          ),
        ],
      );
    } else if (_type == SchemeEngine.BOGO) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trigger Quantity', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _value1Ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Buy how many items to get 1 free?'),
          ),
          const SizedBox(height: 16),
          Text('Free Item Price (₹)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _value2Ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g., 200'),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Minimum Quantity', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _value1Ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g., 10'),
          ),
          const SizedBox(height: 16),
          Text('Discount Per Unit (₹)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _value2Ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'e.g., 50'),
          ),
        ],
      );
    }
  }
}
