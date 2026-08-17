import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/sales_entry_provider.dart';
import '../models/sales_item.dart';

class PremiumProductEntryList extends StatelessWidget {
  const PremiumProductEntryList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesEntryProvider>(
      builder: (context, provider, child) {
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.entries.length,
          separatorBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: const Color(0xFFE5E7EB)),
          ),
          itemBuilder: (context, index) {
            final item = provider.entries[index];
            return _ProductEntryCard(
              key: ValueKey('entry_'),
              index: index,
              item: item,
              showDelete: provider.entries.length > 1,
              onDelete: () => provider.removeEntry(index),
              onChanged: (updatedItem) =>
                  provider.updateEntry(index, updatedItem),
            );
          },
        );
      },
    );
  }
}

class _ProductEntryCard extends StatefulWidget {
  final int index;
  final SalesItem item;
  final bool showDelete;
  final VoidCallback onDelete;
  final Function(SalesItem) onChanged;

  const _ProductEntryCard({
    Key? key,
    required this.index,
    required this.item,
    required this.showDelete,
    required this.onDelete,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<_ProductEntryCard> createState() => _ProductEntryCardState();
}

class _ProductEntryCardState extends State<_ProductEntryCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _discCtrl;

  late FocusNode _nameNode;
  late FocusNode _qtyNode;
  late FocusNode _priceNode;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController(text: widget.item.itemName);
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _priceCtrl = TextEditingController(text: widget.item.price.toString());
    _gstCtrl = TextEditingController(text: widget.item.gst.toString());
    _discCtrl = TextEditingController(text: widget.item.discount.toString());

    _nameNode = FocusNode();
    _qtyNode = FocusNode();
    _priceNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _ProductEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external changes (e.g., from Voice command or Provider) into text fields
    if (widget.item.itemName != oldWidget.item.itemName &&
        _nameCtrl.text != widget.item.itemName) {
      _nameCtrl.text = widget.item.itemName;
    }
    if (widget.item.quantity != oldWidget.item.quantity &&
        _qtyCtrl.text != widget.item.quantity.toString()) {
      _qtyCtrl.text = widget.item.quantity.toString();
    }
    if (widget.item.price != oldWidget.item.price &&
        _priceCtrl.text != widget.item.price.toString()) {
      _priceCtrl.text = widget.item.price.toString();
    }
    if (widget.item.gst != oldWidget.item.gst &&
        _gstCtrl.text != widget.item.gst.toString()) {
      _gstCtrl.text = widget.item.gst.toString();
    }
    if (widget.item.discount != oldWidget.item.discount &&
        _discCtrl.text != widget.item.discount.toString()) {
      _discCtrl.text = widget.item.discount.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _gstCtrl.dispose();
    _discCtrl.dispose();
    _nameNode.dispose();
    _qtyNode.dispose();
    _priceNode.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final updated = widget.item.copyWith(
      itemName: _nameCtrl.text,
      quantity: double.tryParse(_qtyCtrl.text) ?? 0.0,
      price: double.tryParse(_priceCtrl.text) ?? 0.0,
      gst: double.tryParse(_gstCtrl.text) ?? 0.0,
      discount: double.tryParse(_discCtrl.text) ?? 0.0,
    );
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ITEM ',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 20,
                    color: Color(0xFF4F46E5),
                  ),
                  onPressed: () {}, // Optional scan logic
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                if (widget.showDelete)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFFEF4444),
                    ),
                    onPressed: widget.onDelete,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Fields Row 1 (Name & Qty)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: PremiumProductEntry(
                controller: _nameCtrl,
                focusNode: _nameNode,
                label: 'Product Name',
                icon: Icons.inventory_2_rounded,
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: PremiumProductEntry(
                controller: _qtyCtrl,
                focusNode: _qtyNode,
                label: 'Qty',
                icon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
                onChanged: (_) => _notifyChange(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fields Row 2 (Price & Disc)
        Row(
          children: [
            Expanded(
              child: PremiumProductEntry(
                controller: _priceCtrl,
                focusNode: _priceNode,
                label: 'Price',
                icon: Icons.currency_rupee_rounded,
                keyboardType: TextInputType.number,
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PremiumProductEntry(
                controller: _discCtrl,
                label: 'Disc (₹)',
                icon: Icons.percent_rounded,
                keyboardType: TextInputType.number,
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PremiumProductEntry(
                controller: _gstCtrl,
                label: 'GST %',
                icon: Icons.receipt_long_rounded,
                keyboardType: TextInputType.number,
                onChanged: (_) => _notifyChange(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Item Subtotal indicator
        if (widget.item.subtotal > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Item Total: ₹',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );

    return cardContent;
  }
}

class PremiumProductEntry extends StatelessWidget {
  const PremiumProductEntry({
    Key? key,
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
    this.suffixIcon,
  }) : super(key: key);

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final Function(String)? onChanged;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        style: GoogleFonts.poppins(
          color: const Color(0xFF111827),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: const Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
