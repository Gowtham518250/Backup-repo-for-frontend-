import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';
import 'worker_detail_page.dart';
import 'worker_local_storage.dart';
import 'models.dart';

class WorkerManagementPage extends StatefulWidget {
  const WorkerManagementPage({super.key});

  @override
  State<WorkerManagementPage> createState() => _WorkerManagementPageState();
}

class _WorkerManagementPageState extends State<WorkerManagementPage> {
  bool _isLoading = true;
  List<dynamic> _workers = [];
  String _errorMessage = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  List<dynamic> get _filteredWorkers {
    if (_query.trim().isEmpty) return _workers;
    final q = _query.trim().toLowerCase();
    return _workers.where((w) {
      final name = (w['name'] ?? '').toString().toLowerCase();
      final phone = (w['phone'] ?? '').toString().toLowerCase();
      final position = (w['position'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || position.contains(q);
    }).toList();
  }

  // ---- Analytics (derived client-side from the roster we already have) ----

  double get _totalMonthlyBudget =>
      _workers.fold<double>(0, (sum, w) => sum + (double.tryParse('${w['salary']}') ?? 0));

  double get _avgSalary => _workers.isEmpty ? 0 : _totalMonthlyBudget / _workers.length;

  /// Position -> headcount, sorted by size, largest group first.
  List<MapEntry<String, int>> get _positionBreakdown {
    final counts = <String, int>{};
    for (final w in _workers) {
      final pos = (w['position']?.toString().trim().isNotEmpty ?? false)
          ? w['position'].toString().trim()
          : 'Staff';
      counts[pos] = (counts[pos] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  static const List<Color> _avatarPalette = [
    Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFF3B82F6),
  ];

  Color _colorForName(String name) {
    if (name.isEmpty) return _avatarPalette.first;
    return _avatarPalette[name.codeUnitAt(0) % _avatarPalette.length];
  }

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWorkerDetail(dynamic worker) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerDetailPage(worker: Map<String, dynamic>.from(worker as Map)),
      ),
    );
    if (changed == true) {
      _fetchWorkers();
    }
  }

  Future<void> _fetchWorkers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;

    if (userId == 0) {
      if (mounted) {
        setState(() {
          _errorMessage = 'User ID not found. Please login again.';
          _isLoading = false;
        });
      }
      return;
    }

    // LOCAL-FIRST: always restore the roster before attempting the network.
    try {
      final cachedWorkers = await WorkerLocalStorage.fetchWorkers(userId);
      if (cachedWorkers.isNotEmpty && mounted) {
        setState(() {
          _workers = cachedWorkers.map((w) => w.toJson()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Worker local cache read failed: $e');
    }

    // BACKEND REFRESH: a failure must never replace an existing cache with [].
    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      final response = await ApiClient.getJson(
        '/api/attendance/workers?user_id=$userId',
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final List<dynamic> rawWorkers = data is List
            ? data
            : (data is Map && data['workers'] is List)
                ? List<dynamic>.from(data['workers'] as List)
                : (data is Map ? [data] : []);

        final workers = rawWorkers
            .whereType<Map>()
            .map((w) => Worker.fromJson(Map<String, dynamic>.from(w)))
            .whereType<Worker>()
            .toList();

        await WorkerLocalStorage.saveWorkers(userId, workers);

        if (mounted) {
          setState(() {
            _workers = workers.map((w) => w.toJson()).toList();
            _errorMessage = '';
          });
        }
      } else if (mounted && _workers.isEmpty) {
        setState(() {
          _errorMessage = 'Failed to load workers (${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted && _workers.isEmpty) {
        setState(() {
          _errorMessage = 'Workers unavailable offline. Retry when online.';
        });
      }
      debugPrint('⚠️ Worker backend refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteWorker(int workerId) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to remove this worker?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final token = await SecureTokenStorage.getToken() ?? '';
      final response = await ApiClient.deleteJson(
        '/api/attendance/workers/$workerId',
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _fetchWorkers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Worker removed successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Failed to delete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddWorkerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final positionCtrl = TextEditingController(text: 'Staff');
    final salaryCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Add New Worker', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number (Optional)', prefixIcon: Icon(Icons.phone)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: positionCtrl,
                    decoration: const InputDecoration(labelText: 'Position / Role', prefixIcon: Icon(Icons.work)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: salaryCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Salary', prefixIcon: Icon(Icons.attach_money)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(labelText: '4-Digit Attendance PIN', prefixIcon: Icon(Icons.lock)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
                    return;
                  }

                  setModalState(() => isSubmitting = true);

                  try {
                    final token = await SecureTokenStorage.getToken() ?? '';
                    final prefs = await SharedPreferences.getInstance();
                    // 🔧 FIXED: Get user_id as int
                    final userId = prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0;

                    if (userId == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User ID not found. Please login again.'), backgroundColor: Colors.red),
                      );
                      setModalState(() => isSubmitting = false);
                      return;
                    }

                    // 🔧 FIXED: Pass user_id as query parameter
                    final response = await ApiClient.postJson(
                      '/api/attendance/workers?user_id=$userId',
                      {
                        'name': nameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'position': positionCtrl.text.trim(),
                        'salary': double.tryParse(salaryCtrl.text.trim()) ?? 0.0,
                        'pin': pinCtrl.text.trim(),
                      },
                      headers: {'Authorization': 'Bearer $token'},
                    );

                    if (response.statusCode == 200 || response.statusCode == 201) {
                      Navigator.pop(ctx);
                      _fetchWorkers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Worker added successfully!'), backgroundColor: Colors.green),
                      );
                    } else {
                      throw Exception('Failed to create worker');
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                    setModalState(() => isSubmitting = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                child: isSubmitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Add Worker'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 96,
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text('Worker Management',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchWorkers),
              const SizedBox(width: 4),
            ],
          ),
          if (!_isLoading && _errorMessage.isEmpty && _workers.isNotEmpty)
            SliverToBoxAdapter(child: _analyticsHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, or role',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage.isNotEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _fetchWorkers, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (_workers.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No workers found', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Text('Add your staff to manage attendance', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              ),
            )
          else if (_filteredWorkers.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No workers match "$_query"', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverList.builder(
                itemCount: _filteredWorkers.length,
                itemBuilder: (context, index) => _workerCard(_filteredWorkers[index]),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkerDialog,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Worker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// Roster-level analytics: headcount, budgeted payroll, average salary,
  /// and a role-distribution breakdown — everything derivable from the
  /// worker list we already fetched, no extra API calls needed.
  Widget _analyticsHeader() {
    final breakdown = _positionBreakdown;
    final maxCount = breakdown.isEmpty ? 1 : breakdown.first.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _statBlock('${_workers.length}', 'Total Staff', Icons.groups_rounded)),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(child: _statBlock('₹${_compact(_totalMonthlyBudget)}', 'Monthly Budget', Icons.account_balance_wallet_rounded)),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(child: _statBlock('₹${_compact(_avgSalary)}', 'Avg Salary', Icons.bar_chart_rounded)),
              ],
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('TEAM BY ROLE', style: GoogleFonts.poppins(
                  fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700, color: Colors.white60)),
              const SizedBox(height: 10),
              ...breakdown.take(4).map((e) => _breakdownRow(e.key, e.value, maxCount)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBlock(String value, String label, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        Text(label, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _breakdownRow(String position, int count, int maxCount) {
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(position, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _workerCard(dynamic worker) {
    final name = (worker['name'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _colorForName(name);
    final salary = double.tryParse('${worker['salary']}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openWorkerDetail(worker),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withValues(alpha: 0.15),
                  foregroundColor: color,
                  child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'Unnamed' : name,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _tag(worker['position']?.toString().isNotEmpty == true ? worker['position'].toString() : 'Staff', color),
                        if (worker['phone'] != null && worker['phone'].toString().isNotEmpty)
                          _tag(worker['phone'].toString(), Colors.grey.shade600, icon: Icons.phone_outlined),
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${salary.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.indigo)),
                    Text('/mo', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteWorker(worker['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
        Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}