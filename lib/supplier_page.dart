import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'local_storage_service.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  static const Color _primary = Color(0xFF6366F1);

  List<Supplier> _suppliers = [];
  bool _loading = true;
  final _search = TextEditingController();
  List<Supplier> _filtered = [];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_filterSuppliers);
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('suppliers_list') ?? '[]';
      final list = json.decode(raw) as List;
      
      setState(() {
        _suppliers = list.map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
        _filtered = List.from(_suppliers);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _filterSuppliers() {
    final query = _search.text.toLowerCase();
    setState(() {
      _filtered = _suppliers.where((s) => s.name.toLowerCase().contains(query) || s.phone.contains(query)).toList();
    });
  }

  Future<void> _saveSuppliers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('suppliers_list', json.encode(_suppliers.map((e) => e.toJson()).toList()));
  }

  void _showAddDialog() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _categoryCtrl.text = 'General';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Supplier Name')),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              DropdownButton<String>(
                value: _categoryCtrl.text.isEmpty ? 'General' : _categoryCtrl.text,
                items: ['General', 'Grocery', 'Clothes', 'Electronics', 'Other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _categoryCtrl.text = val ?? 'General'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and phone required')));
                return;
              }

              final supplier = Supplier(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameCtrl.text,
                phone: _phoneCtrl.text,
                email: _emailCtrl.text,
                category: _categoryCtrl.text,
                createdAt: DateTime.now(),
              );

              setState(() => _suppliers.add(supplier));
              _filterSuppliers();
              _saveSuppliers();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier added')));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Search supplier',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(child: Text('No suppliers. Tap + to add.'))
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, idx) {
                            final s = _filtered[idx];
                            return ListTile(
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${s.phone} • ${s.category}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.call),
                                onPressed: () async {
                                  final uri = Uri(scheme: 'tel', path: s.phone);
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
                              ),
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                      FilledButton(
                                        onPressed: () {
                                          setState(() => _suppliers.removeWhere((x) => x.id == s.id));
                                          _filterSuppliers();
                                          _saveSuppliers();
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }
}
