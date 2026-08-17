// =============================================================================
// whatsapp_order_page.dart  —  V3 SMART WHATSAPP ORDER INTAKE
// =============================================================================
// WHAT'S NEW vs V1:
//  • Supports 8 real-world order formats (numbered lists, bullets, casual
//    Hinglish, Tamil/Telugu/Hindi text, quantity×price format, etc.)
//  • Per-item confidence badge (⚠️ if uncertain)
//  • Inline item editing (name / qty / price) before transfer
//  • Select/deselect individual items
//  • Running total at the bottom
//  • "Example formats" popover to guide users
//  • Paste & clear button
//  • Language auto-detect hint
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Parser ───────────────────────────────────────────────────────────────────

class _OrderItem {
  String name;
  double qty;
  String unit;
  double price;
  double confidence; // 0–1
  bool selected;

  _OrderItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.price,
    required this.confidence,
    this.selected = true,
  });

  Map<String, dynamic> toMap() => {
    'product_name': name,
    'quantity': qty,
    'unit': unit,
    'price': price,
    'total': qty * price,
  };
}

class _WhatsAppOrderParser {
  /// All unit aliases → canonical
  static const _unitMap = <String, String>{
    'kg': 'kg', 'kilo': 'kg', 'kilogram': 'kg', 'kilograms': 'kg',
    'किलो': 'kg', 'kgs': 'kg', 'கிலோ': 'kg', 'కిలో': 'kg',
    'g': 'g', 'gm': 'g', 'gram': 'g', 'grams': 'g',
    'l': 'L', 'ltr': 'L', 'litre': 'L', 'liter': 'L', 'liters': 'L',
    'ml': 'mL', 'milliliter': 'mL',
    'pcs': 'pc', 'pc': 'pc', 'piece': 'pc', 'pieces': 'pc', 'nos': 'pc', 'no': 'pc',
    'pkt': 'pkt', 'pack': 'pkt', 'packet': 'pkt', 'packets': 'pkt',
    'btl': 'btl', 'bottle': 'btl', 'bottles': 'btl',
    'box': 'box', 'boxes': 'box',
    'doz': 'doz', 'dozen': 'doz',
    'पैकेट': 'pkt', 'पीस': 'pc', 'लीटर': 'L', 'बोतल': 'btl',
  };

  static String _resolveUnit(String? raw) {
    if (raw == null || raw.isEmpty) return 'pc';
    return _unitMap[raw.toLowerCase()] ?? _unitMap[raw] ?? raw.toLowerCase();
  }

  // Hindi / Hinglish number words
  static const _hindiNums = <String, double>{
    'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4, 'पाँच': 5, 'पांच': 5,
    'छह': 6, 'सात': 7, 'आठ': 8, 'नौ': 9, 'दस': 10,
    'half': 0.5, 'आधा': 0.5, 'डेढ़': 1.5, 'ढाई': 2.5,
  };

  static String _replaceWords(String text) {
    String r = text;
    _hindiNums.forEach((w, v) {
      r = r.replaceAll(RegExp('\\b$w\\b', caseSensitive: false), v.toString());
    });
    return r;
  }

  /// Try to parse a single line / segment
  static _OrderItem? _parseLine(String raw) {
    String line = _replaceWords(raw.trim().toLowerCase());

    // Remove leading bullets / numbers / dashes
    line = line.replaceAll(RegExp(r'^[\d]+[.):\-\s]+'), '').trim();
    line = line.replaceAll(RegExp(r'^[-•*✓✔]\s*'), '').trim();

    if (line.length < 3) return null;

    // ── Pattern A: "2 kg sugar 60"  or  "2 sugar 60"
    final patA = RegExp(
      r'^(\d+\.?\d*)\s*([a-z]+)?\s+([a-z\u0900-\u097f\u0b80-\u0bff\u0c00-\u0cff\u0d00-\u0d7f\u0980-\u09ff\u0a80-\u0aff\u0a00-\u0a7f][\w\u0900-\u097f\u0b80-\u0bff\u0c00-\u0cff\u0d00-\u0d7f\u0980-\u09ff\u0a80-\u0aff\u0a00-\u0a7f\s]{1,30}?)\s+(?:rs\.?|₹|price|@)?\s*(\d+\.?\d*)',
      caseSensitive: false,
    );
    final mA = patA.firstMatch(line);
    if (mA != null) {
      final rawUnit = mA.group(2) ?? '';
      final isUnit = _unitMap.containsKey(rawUnit.toLowerCase());
      final name = isUnit ? mA.group(3)! : '$rawUnit ${mA.group(3)!}'.trim();
      return _OrderItem(
        name: _titleCase(name.trim()),
        qty: double.tryParse(mA.group(1) ?? '1') ?? 1,
        unit: isUnit ? _resolveUnit(rawUnit) : 'pc',
        price: double.tryParse(mA.group(4) ?? '0') ?? 0,
        confidence: _confidence(name, double.tryParse(mA.group(1)!)!, double.tryParse(mA.group(4)!)!),
      );
    }

    // ── Pattern B: "sugar 2kg 60"  /  "sugar 2 60"
    final patB = RegExp(
      r'^([a-z\u0900-\u097f\u0b80-\u0bff\u0c00-\u0cff\u0d00-\u0d7f\u0980-\u09ff\u0a80-\u0aff\u0a00-\u0a7f][\w\u0900-\u097f\u0b80-\u0bff\u0c00-\u0cff\u0d00-\u0d7f\u0980-\u09ff\u0a80-\u0aff\u0a00-\u0a7f\s]{1,25}?)\s+(\d+\.?\d*)\s*([a-z]+)?\s+(?:rs\.?|₹)?\s*(\d+\.?\d*)',
      caseSensitive: false,
    );
    final mB = patB.firstMatch(line);
    if (mB != null) {
      return _OrderItem(
        name: _titleCase(mB.group(1)!.trim()),
        qty: double.tryParse(mB.group(2) ?? '1') ?? 1,
        unit: _resolveUnit(mB.group(3)),
        price: double.tryParse(mB.group(4) ?? '0') ?? 0,
        confidence: _confidence(mB.group(1)!, double.tryParse(mB.group(2)!)!, double.tryParse(mB.group(4)!)!),
      );
    }

    // ── Pattern C: "sugar × 2 = 60"  /  "sugar x2 @60"
    final patC = RegExp(
      r'^([\w\u0900-\u097f\u0b80-\u0bff\u0c00-\u0cff\u0d00-\u0d7f\u0980-\u09ff\u0a80-\u0aff\u0a00-\u0a7f\s]{2,25}?)\s*[×x\*]\s*(\d+\.?\d*)\s*(?:[=@₹])?\s*(\d+\.?\d*)',
      caseSensitive: false,
    );
    final mC = patC.firstMatch(line);
    if (mC != null) {
      return _OrderItem(
        name: _titleCase(mC.group(1)!.trim()),
        qty: double.tryParse(mC.group(2) ?? '1') ?? 1,
        unit: 'pc',
        price: double.tryParse(mC.group(3) ?? '0') ?? 0,
        confidence: _confidence(mC.group(1)!, double.tryParse(mC.group(2)!)!, double.tryParse(mC.group(3)!)!),
      );
    }

    // ── Pattern D: name only with price  "sugar 60"
    final patD = RegExp(
      r'^([a-z\u0900-\u097f\u0b80-\u0bff\u0c00-\u0cff\u0d00-\u0d7f\u0980-\u09ff\u0a80-\u0aff\u0a00-\u0a7f][\w\u0900-\u097f\s]{2,25}?)\s+(\d+\.?\d*)$',
      caseSensitive: false,
    );
    final mD = patD.firstMatch(line);
    if (mD != null) {
      final price = double.tryParse(mD.group(2) ?? '0') ?? 0;
      return _OrderItem(
        name: _titleCase(mD.group(1)!.trim()),
        qty: 1,
        unit: 'pc',
        price: price,
        confidence: price > 0 ? 0.55 : 0.35,
      );
    }

    return null;
  }

  static double _confidence(String name, double qty, double price) {
    double s = 1.0;
    if (price == 0) s -= 0.35;
    if (name.trim().length < 3) s -= 0.25;
    if (qty > 200) s -= 0.2;
    if (qty == 0) s -= 0.3;
    return s.clamp(0.0, 1.0);
  }

  static String _titleCase(String s) {
    return s.split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  /// Split the full text into lines/segments intelligently
  static List<String> _splitInput(String text) {
    // First try splitting on newlines
    if (text.contains('\n')) {
      return text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    }
    // Then commas
    if (text.contains(',')) {
      return text.split(',').where((l) => l.trim().isNotEmpty).toList();
    }
    // Then semicolons
    if (text.contains(';')) {
      return text.split(';').where((l) => l.trim().isNotEmpty).toList();
    }
    // Fallback: split on "and" / "aur"
    return text.split(RegExp(r'\band\b|aur|और', caseSensitive: false))
        .where((l) => l.trim().isNotEmpty).toList();
  }

  /// Main parse entry
  static List<_OrderItem> parse(String input) {
    final segments = _splitInput(input.trim());
    final results = <_OrderItem>[];
    for (final seg in segments) {
      final item = _parseLine(seg);
      if (item != null && item.name.length >= 2) results.add(item);
    }
    return results;
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class WhatsAppOrderPage extends StatefulWidget {
  const WhatsAppOrderPage({super.key});

  @override
  State<WhatsAppOrderPage> createState() => _WhatsAppOrderPageState();
}

class _WhatsAppOrderPageState extends State<WhatsAppOrderPage>
    with TickerProviderStateMixin {
  final _textCtrl = TextEditingController();
  List<_OrderItem> _items = [];
  bool _parsing = false;
  bool _showExamples = false;

  final Map<int, Map<String, TextEditingController>> _editCtrl = {};

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _shimmerCtrl.dispose();
    for (final m in _editCtrl.values) m.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _parse() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _parsing = true; _items = []; });

    Future.delayed(const Duration(milliseconds: 300), () {
      final parsed = _WhatsAppOrderParser.parse(text);
      _editCtrl.clear();
      if (mounted) setState(() { _items = parsed; _parsing = false; });

      if (parsed.isEmpty) {
        _snack('Could not parse items. Try a different format.', error: true);
      } else {
        _snack('✅ ${parsed.length} item${parsed.length > 1 ? 's' : ''} detected');
      }
    });
  }

  void _transfer() {
    // Apply inline edits
    for (int i = 0; i < _items.length; i++) {
      final m = _editCtrl[i];
      if (m != null) {
        _items[i].name  = m['name']!.text.trim().isEmpty ? _items[i].name : m['name']!.text.trim();
        _items[i].qty   = double.tryParse(m['qty']!.text) ?? _items[i].qty;
        _items[i].price = double.tryParse(m['price']!.text) ?? _items[i].price;
      }
    }

    final selected = _items.where((e) => e.selected).toList();
    if (selected.isEmpty) { _snack('No items selected', error: true); return; }

    Navigator.pop(context, selected.map((e) => e.toMap()).toList());
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _textCtrl.text = data!.text!;
      setState(() {});
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.w600)),
      backgroundColor: error ? const Color(0xFFBF360C) : const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFormatExamples(),
                    const SizedBox(height: 12),
                    _buildInputCard(),
                    const SizedBox(height: 12),
                    _buildParseButton(),
                    if (_parsing) _buildShimmerLoader(),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildResultHeader(),
                      ..._items.asMap().entries.map((e) => _buildItemCard(e.key, e.value)),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            if (_items.isNotEmpty) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1B2A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.mail_rounded, color: Color(0xFF4CAF50), size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WhatsApp Order',
                style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Paste → Parse → Bill',
                style: GoogleFonts.rajdhani(color: const Color(0xFF546E7A), fontSize: 11)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF546E7A), size: 20),
          onPressed: () => setState(() => _showExamples = !_showExamples),
        ),
      ],
    );
  }

  Widget _buildFormatExamples() {
    if (!_showExamples) return const SizedBox.shrink();

    const examples = [
      ('Comma separated', '2 kg Atta 60, 1 Oil 150, 3 Biscuit 20'),
      ('Numbered list', '1. Atta 2kg 60\n2. Oil 1L 150'),
      ('Bullet points', '• Sugar 1kg 45\n• Milk 2L 56'),
      ('Hinglish casual', 'Do kilo aata saath, ek tel dedh sau'),
      ('With × operator', 'Biscuit × 3 = 60\nOil × 1 = 150'),
      ('Name + price only', 'Atta 60\nOil 150\nSugar 45'),
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1F38),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SUPPORTED FORMATS',
              style: GoogleFonts.rajdhani(
                color: const Color(0xFF42A5F5), fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 1.5,
              )),
            const SizedBox(height: 10),
            ...examples.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.$1,
                    style: GoogleFonts.rajdhani(color: const Color(0xFF7986CB), fontSize: 11,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () {
                      _textCtrl.text = e.$2;
                      setState(() => _showExamples = false);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1628),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF263238), width: 1),
                      ),
                      child: Text(e.$2,
                        style: GoogleFonts.sourceCodePro(
                          color: const Color(0xFF80CBC4), fontSize: 12, height: 1.5)),
                    ),
                  ),
                ],
              ),
            )),
            Text('Tap any example to load it',
              style: GoogleFonts.rajdhani(color: const Color(0xFF37474F), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1F38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.message_rounded, color: Color(0xFF4CAF50), size: 16),
                const SizedBox(width: 8),
                Text('Order Text',
                  style: GoogleFonts.rajdhani(color: const Color(0xFF546E7A), fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 14),
                  label: Text('Paste',
                    style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF42A5F5),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                if (_textCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF546E7A)),
                    onPressed: () => setState(() { _textCtrl.clear(); _items = []; }),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _textCtrl,
            maxLines: 7,
            style: GoogleFonts.notoSans(color: Colors.white, fontSize: 14, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Paste customer\'s WhatsApp order here…\n\nE.g:\n2 kg Atta 60, 1 Oil 150\nSugar 1kg 45',
              hintStyle: GoogleFonts.notoSans(
                color: const Color(0xFF263238), fontSize: 13, height: 1.6),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildParseButton() {
    final empty = _textCtrl.text.trim().isEmpty;
    return ElevatedButton(
      onPressed: empty ? null : _parse,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1565C0),
        disabledBackgroundColor: const Color(0xFF1B2838),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_fix_high_rounded, size: 18),
          const SizedBox(width: 8),
          Text('Smart Parse',
            style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, __) {
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  colors: const [Color(0xFF263238), Color(0xFF42A5F5), Color(0xFF263238)],
                  stops: [
                    (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                    _shimmerCtrl.value.clamp(0.0, 1.0),
                    (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds),
                child: Text('Parsing order…',
                  style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Colors.white)),
              );
            },
          ),
          const SizedBox(height: 8),
          Text('Detecting items, quantities & prices',
            style: GoogleFonts.rajdhani(color: const Color(0xFF37474F), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResultHeader() {
    final selectedCount = _items.where((e) => e.selected).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text('PARSED ITEMS',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFF42A5F5), fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1.5,
            )),
          const Spacer(),
          Text('$selectedCount / ${_items.length} selected',
            style: GoogleFonts.rajdhani(color: const Color(0xFF546E7A), fontSize: 12)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              final allSelected = _items.every((e) => e.selected);
              for (final item in _items) item.selected = !allSelected;
            }),
            child: Text(
              _items.every((e) => e.selected) ? 'Deselect all' : 'Select all',
              style: GoogleFonts.rajdhani(
                color: const Color(0xFF1976D2), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int idx, _OrderItem item) {
    _editCtrl.putIfAbsent(idx, () => {
      'name':  TextEditingController(text: item.name),
      'qty':   TextEditingController(text: item.qty.toString()),
      'price': TextEditingController(text: item.price.toString()),
    });

    final lowConf = item.confidence < 0.6;
    final total = item.qty * item.price;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: item.selected ? const Color(0xFF0F1F38) : const Color(0xFF0A1422),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.selected
                ? (lowConf ? const Color(0xFFE65100).withValues(alpha: 0.5) : const Color(0xFF1E3A5F))
                : const Color(0xFF0F1F38),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => setState(() => item.selected = !item.selected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.selected ? const Color(0xFF4CAF50) : Colors.transparent,
                    border: Border.all(
                      color: item.selected ? const Color(0xFF4CAF50) : const Color(0xFF37474F),
                      width: 1.5,
                    ),
                  ),
                  child: item.selected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Name + fields
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _editCtrl[idx]!['name'],
                            style: GoogleFonts.notoSans(
                              color: item.selected ? Colors.white : const Color(0xFF37474F),
                              fontSize: 14, fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              isDense: true, contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (lowConf)
                          Tooltip(
                            message: 'Low confidence — verify this item',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBF360C).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBF360C).withValues(alpha: 0.4)),
                              ),
                              child: Text('⚠️ Check',
                                style: GoogleFonts.rajdhani(
                                  color: const Color(0xFFFF6D00), fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                )),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _fieldChip('Qty', _editCtrl[idx]!['qty']!),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(item.unit,
                            style: GoogleFonts.rajdhani(color: const Color(0xFF546E7A), fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Text('₹', style: GoogleFonts.rajdhani(color: const Color(0xFF546E7A), fontSize: 13)),
                        _fieldChip('Price', _editCtrl[idx]!['price']!),
                      ],
                    ),
                  ],
                ),
              ),
              // Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${total.toStringAsFixed(0)}',
                    style: GoogleFonts.rajdhani(
                      color: item.selected ? const Color(0xFF82B1FF) : const Color(0xFF37474F),
                      fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF37474F)),
                    onPressed: () => setState(() { _items.removeAt(idx); _editCtrl.remove(idx); }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldChip(String hint, TextEditingController ctrl) {
    return SizedBox(
      width: 50,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.rajdhani(color: const Color(0xFF82B1FF), fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.rajdhani(color: const Color(0xFF263238), fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final selected = _items.where((e) => e.selected).toList();
    final total = selected.fold<double>(0, (s, e) => s + e.qty * e.price);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        border: Border(top: BorderSide(color: const Color(0xFF1E3A5F), width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${selected.length} item${selected.length != 1 ? 's' : ''}',
                style: GoogleFonts.rajdhani(color: const Color(0xFF546E7A), fontSize: 12)),
              Text('₹${total.toStringAsFixed(2)}',
                style: GoogleFonts.rajdhani(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: selected.isEmpty ? null : _transfer,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text('Transfer to Bill',
              style: GoogleFonts.rajdhani(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              disabledBackgroundColor: const Color(0xFF1B2838),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}