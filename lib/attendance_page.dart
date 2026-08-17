import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scoped_shared_preferences.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';
import 'app_localizations.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'models.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'worker_local_storage.dart';
import 'worker_attendance_detail_page.dart';
import 'attendance_offline_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Color _primary = Color(0xFF6366F1);
  static const Color _present = Color(0xFF10B981);
  static const Color _absent = Color(0xFFEF4444);
  static const Color _half = Color(0xFFF59E0B);

  // Shift window used to flag late check-ins / early check-outs.
  static const TimeOfDay _shiftStart = TimeOfDay(hour: 9, minute: 30);
  static const int _lateGraceMinutes = 15;

  final DateFormat _df = DateFormat('yyyy-MM-dd');
  bool _loading = true;
  bool _marking = false;
  List<dynamic> _records = [];
  Map<String, dynamic>? _todaySummary;
  int? _userId;
  late TabController _tab;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timer;
  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  String _liveHours = '0.0';
  List<Worker> _staff = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tab = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _init();
    _startTimer();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _tab.dispose();
    _pulseController.dispose();
    _timer?.cancel();
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id') ?? prefs.getInt('userId');

    if (_userId == null) {
      if (kDebugMode) debugPrint('⚠️ No user_id found in preferences');
      // Delay snack message until widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSnack('⚠️ Please login to use attendance', _absent);
      });
    }

    await _loadStaff();
    // Backend is authoritative after login/data-clear; reconcile before the
    // first UI fetch so a stale local state cannot force a false Check In.
    try {
      await OfflineAttendanceService.reconcileFromBackend();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Attendance reconciliation deferred: $e');
    }
    await _fetch();
  }

  Future<void> _loadStaff() async {
    // Load staff from local storage first (immediate response)
    try {
      final workers = await WorkerLocalStorage.fetchWorkers(_userId ?? 0);
      
      if (workers.isNotEmpty && mounted) {
        setState(() {
          _staff = workers;
        });
        if (kDebugMode) debugPrint('📦 Loaded ${_staff.length} workers from local storage');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading staff from local storage: $e');
    }
    
    // Then sync with backend in background
    try {
      final url = (_userId != null && _userId! > 0)
          ? '${ApiClient.attendanceWorkers}?user_id=$_userId'
          : ApiClient.attendanceWorkers;
      final res = await ApiClient.getJson(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          final syncedWorkers = data is List
              ? data.map((w) => Worker.fromJson(w)).toList()
              : (data is Map && data['workers'] is List)
                  ? (data['workers'] as List)
                      .whereType<Map>()
                      .map((w) => Worker.fromJson(Map<String, dynamic>.from(w)))
                      .toList()
                  : <Worker>[];

          // Backend success becomes the durable offline roster.
          await WorkerLocalStorage.saveWorkers(_userId ?? 0, syncedWorkers);

          setState(() {
            _staff = syncedWorkers;
          });
          if (kDebugMode) {
            debugPrint('✅ Synced and cached ${_staff.length} workers from backend');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Backend staff sync failed: $e, using local data');
    }
  }

  Future<void> _saveStaff() async {
    // Staff is now synced with backend - no local save needed
    // Refresh from backend to ensure consistency
    await _loadStaff();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      // Local-first: render persisted attendance immediately, even offline.
      final localRecords = await OfflineAttendanceService.loadLocalRecords();
      if (mounted && localRecords.isNotEmpty) {
        setState(() => _records = localRecords);
      }

      final today = _df.format(DateTime.now());
      
      // Fetch shopkeeper's attendance
      String url = '${ApiClient.attendancePrefix}/date/$today';
      if (_userId != null) {
        url += '?employee_id=$_userId';
      }
      final res = await ApiClient.getJson(url);
      
      List<dynamic> allRecords = [];
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          allRecords = List<dynamic>.from(data);
        } else if (data is Map) {
          allRecords = List<dynamic>.from((data['records'] ?? []) as List);
          _todaySummary = Map<String, dynamic>.from(data);
        }
      }
      
      // Fetch worker attendance in parallel so payroll/attendance stays responsive.
      final workerResults = await Future.wait<List<dynamic>>(_staff.map((worker) async {
        try {
          final workerUrl = '${ApiClient.attendancePrefix}/employee/${worker.id}';
          final workerRes = await ApiClient.getJson(workerUrl);
          if (workerRes.statusCode == 200) {
            final workerData = json.decode(workerRes.body);
            if (workerData is Map && workerData['records'] is List) return List<dynamic>.from(workerData['records'] as List);
            if (workerData is List) return List<dynamic>.from(workerData);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error fetching attendance for worker ${worker.id}: $e');
        }
        return <dynamic>[];
      }));
      for (final workerRecords in workerResults) { allRecords.addAll(workerRecords); }

      // Persist the complete remote history so payroll does not fall to zero
      // on cold start when the network/auth refresh is temporarily unavailable.
      if (allRecords.isNotEmpty) {
        await OfflineAttendanceService.mergeRemoteRecords(
          allRecords.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList(),
        );
      }
      
      // IMPORTANT: never replace durable local attendance with a stale/empty
      // cloud response. Immediately after CHECK IN/CHECK OUT the local record
      // is marked local_pending=true; a cloud response can legitimately lag
      // behind it. Merge by employee/worker + business date and prefer the
      // local pending record until sync confirms it.
      final mergedByKey = <String, Map<String, dynamic>>{};
      String attendanceKey(Map<String, dynamic> r) {
        final employee = (r['worker_id'] ?? r['employee_id'] ?? '').toString();
        final date = (r['attendance_date'] ?? '').toString().split('T').first;
        return '$employee:$date';
      }

      for (final raw in [...localRecords, ...allRecords]) {
        if (raw is! Map) continue;
        final record = Map<String, dynamic>.from(raw);
        final key = attendanceKey(record);
        if (key == ':') continue;
        final existing = mergedByKey[key];
        if (existing == null) {
          mergedByKey[key] = record;
        } else if (record['local_pending'] == true && existing['local_pending'] != true) {
          mergedByKey[key] = record;
        } else if (existing['local_pending'] == true) {
          // Preserve the local pending state and its timestamps. Remote data
          // must not make the UI flip back to CHECK IN while sync is pending.
          mergedByKey[key] = {...record, ...existing, 'local_pending': true};
        } else {
          mergedByKey[key] = {...existing, ...record};
        }
      }

      if (mounted) {
        setState(() {
          _records = mergedByKey.values.toList();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching attendance: $e');
      }
      if (mounted) {
        _showSnack('Failed to load attendance data', _absent);
      }
    }
    setState(() => _loading = false);
    _updateLiveHours();
  }

  Future<void> _refreshAttendanceData() async {
    if (!mounted || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      await _loadStaff();
      try { await OfflineAttendanceService.reconcileFromBackend(); } catch (e) { if (kDebugMode) debugPrint('⚠️ Attendance reconcile refresh failed: $e'); }
      await _fetch();
    } finally {
      _refreshInFlight = false;
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _refreshAttendanceData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAttendanceData();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _updateLiveHours();
    });
  }

  void _updateLiveHours() {
    final today = _df.format(DateTime.now());
    final myRecord = _records.where((r) {
      // Backend returns attendance_date as "2026-07-21" string — normalize both sides
      final recDate = (r['attendance_date'] ?? '').toString().split('T').first.trim();
      final empId = r['employee_id'];
      // Handle both int and string employee_id from backend JSON
      final empIdMatch = empId == _userId || empId.toString() == _userId.toString();
      return empIdMatch && recDate == today;
    }).firstOrNull;

    if (myRecord != null && myRecord['check_in_time'] != null && myRecord['check_out_time'] == null) {
      // Backend stores UTC; normalize to local time for a correct live diff.
      final cin = _parseServerTime(myRecord['check_in_time']);
      if (cin != null) {
        final diff = DateTime.now().difference(cin);
        setState(() {
          _liveHours = (diff.inMinutes / 60.0).toStringAsFixed(2);
        });
      }
    } else if (myRecord != null && myRecord['working_hours'] != null) {
      setState(() {
        _liveHours = (myRecord['working_hours'] as num).toDouble().toStringAsFixed(2);
      });
    } else {
      setState(() {
        _liveHours = '0.00';
      });
    }
  }

  /// Backend sends naive timestamps with no timezone suffix (e.g.
  /// "2026-07-28T04:15:00"), which are actually UTC. DateTime.parse would
  /// otherwise treat that string as *local* time, which is wrong by our
  /// UTC offset. This normalizes any server timestamp to local time
  /// consistently, whether or not it carries a timezone suffix already.
  DateTime? _parseServerTime(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString();
    DateTime? t = DateTime.tryParse(str);
    if (t == null) return null;
    if (!str.contains('+') && !str.endsWith('Z')) {
      t = DateTime.parse('${str}Z');
    }
    return t.toLocal();
  }

  bool _isLateCheckIn(Map r) {
    final cin = _parseServerTime(r['check_in_time']);
    if (cin == null) return false;
    final threshold = DateTime(
        cin.year, cin.month, cin.day, _shiftStart.hour, _shiftStart.minute + _lateGraceMinutes);
    return cin.isAfter(threshold);
  }

  double _calculateWorkerMonthlyHours(int workerId) {
    double totalHours = 0;
    final now = DateTime.now();
    
    // Filter records for this worker in current month using worker_id field
    for (var r in _records) {
      // Use worker_id if available, otherwise fall back to employee_id for backward compatibility
      final recordWorkerId = r['worker_id'] ?? r['employee_id'];
      if (recordWorkerId == null) continue;
      if (recordWorkerId.toString() != workerId.toString()) continue;
      
      final attDateStr = (r['attendance_date'] ?? '').toString().split('T').first.trim();
      final attDate = DateTime.tryParse(attDateStr);
      if (attDate == null) continue;
      if (attDate.year != now.year || attDate.month != now.month) continue;
      
      // Use working_hours from backend if available
      if (r['working_hours'] != null) {
        totalHours += (r['working_hours'] as num).toDouble();
      } else if (r['check_in_time'] != null && r['check_out_time'] != null) {
        final cin = _parseServerTime(r['check_in_time']);
        final cout = _parseServerTime(r['check_out_time']);
        if (cin != null && cout != null) {
          totalHours += cout.difference(cin).inMinutes / 60.0;
        }
      }
    }
    return totalHours;
  }

  Future<void> _checkInOut() async {
    if (_userId == null) {
      _showSnack('⚠️ User ID not found. Please login again.', _absent);
      return;
    }
    setState(() => _marking = true);

    try {
      final today = _df.format(DateTime.now());
      Map<String, dynamic>? myRecord;
      for (final r in _records) {
        final recDate = (r['attendance_date'] ?? '').toString().split('T').first.trim();
        final empId = r['employee_id'];
        if ((empId == _userId || empId.toString() == _userId.toString()) && recDate == today) {
          myRecord = Map<String, dynamic>.from(r as Map);
          break;
        }
      }

      if (myRecord == null || myRecord['check_in_time'] == null) {
        await OfflineAttendanceService.checkIn(employeeId: _userId!);
        _showSnack('✅ Checked In — saved offline and queued for sync', _present);
      } else if (myRecord['check_out_time'] == null) {
        await OfflineAttendanceService.checkOut(employeeId: _userId!);
        _showSnack('👋 Checked Out — saved offline and queued for sync', _primary);
      } else {
        _showSnack('✅ Already checked in and out today', Colors.orange);
      }

      await _fetch();
    } catch (e) {
      _showSnack('❌ Attendance could not be saved safely: $e', _absent);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final today = _df.format(DateTime.now());
    // ✅ FIX: Normalize date and employee_id comparison (backend may return string ID)
    final myRecord = _records.where((r) {
      final recDate = (r['attendance_date'] ?? '').toString().split('T').first.trim();
      final empId = r['employee_id'];
      final empIdMatch = empId == _userId || empId.toString() == _userId.toString();
      return empIdMatch && recDate == today;
    }).firstOrNull;

    final checkedIn = myRecord != null && myRecord['check_in_time'] != null;
    final checkedOut = checkedIn && myRecord['check_out_time'] != null;

    String btnLabel = AppLocalizations.of(context).checkIn;
    Color btnColor = _present;
    IconData btnIcon = Icons.login;
    if (checkedIn && !checkedOut) {
      btnLabel = AppLocalizations.of(context).checkOut;
      btnColor = _primary;
      btnIcon = Icons.logout;
    } else if (checkedOut) {
      btnLabel = AppLocalizations.of(context).gotIt;
      btnColor = Colors.grey;
      btnIcon = Icons.check_circle;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).attendance, style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _buildLanguageSwitcher(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: AppLocalizations.of(context).today),
            Tab(text: AppLocalizations.of(context).history),
            const Tab(text: 'Payroll'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _todayTab(myRecord, checkedIn, checkedOut),
          _historyTab(),
          _payrollTab(),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _pulseAnimation,
        child: FloatingActionButton.extended(
          onPressed: checkedOut ? null : (_marking ? null : _checkInOut),
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: _marking
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(btnIcon),
          label: Text(btnLabel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _todayTab(Map<String, dynamic>? rec, bool ci, bool co) {
    final today = DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Date banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(Icons.calendar_today, color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Text(today, style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 20),
        
        // --- STAFF ATTENDANCE (Moved to top for visibility) ---
        if (_staff.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Staff Management', style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF1F2937))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${_staff.length} Active', style: GoogleFonts.poppins(
                      fontSize: 11, color: _primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._staff.map((worker) => _workerAttendanceTile(worker)),
          const SizedBox(height: 24),
          const Divider(thickness: 1, height: 1),
          const SizedBox(height: 24),
        ],

        // --- SHOPKEEPER (OWN) STATUS ---
        Text('My Daily Status', style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        if (rec == null) ...[
          _emptyAttendance(),
        ] else ...[
          // Status card
          _statusCard(rec, ci, co),
          const SizedBox(height: 16),
          // Time cards
          Row(children: [
            Expanded(child: _timeCard('Check-In', rec['check_in_time'],
                Icons.login, _present)),
            const SizedBox(width: 12),
            Expanded(child: _timeCard('Check-Out', rec['check_out_time'],
                Icons.logout, _primary)),
          ]),
          if (ci) ...[
            const SizedBox(height: 12),
            _hoursCard(_liveHours, isLive: !co),
          ],
        ],

        const SizedBox(height: 32),

        // Guide
        Text('Attendance Guide', style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        _guide('Tap "CHECK IN" for workers when they arrive', Icons.login, _present),
        _guide('Tap "CHECK OUT" when they leave for the day', Icons.logout, _primary),
        _guide('View full track record in the History tab', Icons.history, Colors.orange),
      ]),
    );
  }

  Widget _workerAttendanceTile(Worker worker) {
    // Check today's attendance from backend records using worker_id
    final today = _df.format(DateTime.now());
    final workerRecord = _records.where((r) {
      // Use worker_id if available, otherwise fall back to employee_id for backward compatibility.
      // Compare as strings: worker.id is a String, but the API returns
      // worker_id/employee_id as a raw JSON int, so a bare `==` here always
      // failed and this tile never detected "already checked in".
      final recordWorkerId = r['worker_id'] ?? r['employee_id'];
      
      // Explicit null check to prevent null pointer exception
      if (recordWorkerId == null) return false;
      
      final recDate = (r['attendance_date'] ?? '').toString().split('T').first.trim();
      return recordWorkerId.toString() == worker.id.toString() && recDate == today;
    }).firstOrNull;
    
    bool isIn = workerRecord != null && 
               workerRecord['check_in_time'] != null && 
               workerRecord['check_out_time'] == null;
    
    // Calculate monthly hours from backend records
    final workerId = int.tryParse(worker.id) ?? 0;
    final monthlyHours = _calculateWorkerMonthlyHours(workerId);
    final predictedSalary = worker.salary > 0 ? (monthlyHours / 200.0) * worker.salary : 0.0;
    final isLateToday = workerRecord != null && _isLateCheckIn(workerRecord);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WorkerAttendanceDetailPage(worker: worker)),
            ),
            leading: CircleAvatar(
              backgroundColor: _primary.withValues(alpha: 0.1),
              child: Text(worker.name[0], style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(worker.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Row(children: [
              Flexible(
                child: Text('${worker.position} • $monthlyHours hrs this month',
                    style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (isLateToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('LATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                ),
              ],
            ]),
            trailing: SizedBox(
              width: 100,
              child: ElevatedButton(
                onPressed: () async {
                  final verified = await _showVerifyPinDialog(worker);
                  if (verified) {
                    await _markWorkerAttendance(worker, isIn);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isIn ? _absent : _present,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(80, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  isIn ? 'CHECK OUT' : 'CHECK IN',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          if (worker.salary > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Predicted Salary:', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                  Text('₹${predictedSalary.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyAttendance() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10)]),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.fingerprint, size: 44, color: Color(0xFF6366F1)),
        ),
        const SizedBox(height: 16),
        Text("Not checked in yet", style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, fontSize: 16)),
        Text("Tap the Check In button below to mark attendance",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
      ]),
    );
  }

  Widget _statusCard(Map<String, dynamic> rec, bool ci, bool co) {
    final status = co
        ? 'PRESENT'
        : (ci ? 'IN PROGRESS' : rec['status'] ?? 'PENDING');
    final color = status == 'PRESENT'
        ? _present
        : (status == 'IN PROGRESS' ? Colors.orange : Colors.grey);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        CircleAvatar(backgroundColor: color, radius: 24,
            child: Icon(
                status == 'PRESENT' ? Icons.check : Icons.access_time,
                color: Colors.white)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppLocalizations.of(context).todayStatus, style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade600)),
          Text(status, style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ]),
      ]),
    );
  }

  Widget _timeCard(String label, dynamic time, IconData icon, Color color) {
    String t = '--:--';
    final parsed = _parseServerTime(time);
    if (time != null) {
      t = parsed != null ? DateFormat.jm().format(parsed) : 'N/A';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.poppins(
            fontSize: 11, color: Colors.grey.shade500)),
        Text(t, style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _hoursCard(String hours, {bool isLive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: isLive 
                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                  : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isLive ? const Color(0xFF10B981) : const Color(0xFF6366F1)).withValues(alpha: 0.3),
              blurRadius: 8, offset: const Offset(0, 4)
            )
          ]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              if (isLive) ...[
                const SizedBox(
                  width: 8, height: 8,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                ),
                const SizedBox(width: 10),
              ],
              Text(isLive ? 'Live Working Hours' : 'Working Hours', style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 13)),
            ]),
            Text('$hours hrs', style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w700)),
          ]),
    );
  }

  Widget _guide(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.grey.shade700))),
      ]),
    );
  }

  Widget _historyTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_records.isEmpty) return Center(
        child: Text('No attendance records', style: GoogleFonts.poppins()));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (_, i) {
        final r = _records[i];
        final st = r['status'] as String? ?? 'N/A';
        final color = st == 'PRESENT' ? _present
            : (st == 'HALF_DAY' ? Colors.orange : _absent);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
          child: Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(
                    st == 'PRESENT' ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['attendance_date'] ?? '', style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13)),
              if (r['check_in_time'] != null)
                Text('In: ${DateFormat.jm().format(DateTime.tryParse(r['check_in_time']) ?? DateTime.now())}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(st, style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              ),
              if (_isLateCheckIn(r))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('LATE', style: GoogleFonts.poppins(
                      fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _payrollTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_staff.isEmpty) {
      return Center(
          child: Text('Add staff to see payroll summaries', style: GoogleFonts.poppins(color: Colors.grey.shade600)));
    }

    double totalPayroll = 0;
    final rows = _staff.map((w) {
      final workerId = int.tryParse(w.id) ?? 0;
      final hours = _calculateWorkerMonthlyHours(workerId);
      final rate = w.salary > 0 ? w.salary / 200.0 : 0.0;
      final amount = hours * rate;
      totalPayroll += amount;
      return (worker: w, hours: hours, rate: rate, amount: amount);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Payroll · ${DateFormat('MMMM').format(DateTime.now())}',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
            Text('₹${totalPayroll.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 16),
        ...rows.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
              ),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WorkerAttendanceDetailPage(worker: r.worker)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: _primary.withValues(alpha: 0.1),
                    child: Text(r.worker.name[0], style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.worker.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('${r.hours.toStringAsFixed(1)} hrs × ₹${r.rate.toStringAsFixed(2)}/hr',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
                  Text('₹${r.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15, color: _primary)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ]),
              ),
            )),
      ],
    );
  }

  Widget _buildLanguageSwitcher() {
    final langProvider = Provider.of<LanguageProvider>(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: Colors.white, size: 24),
      tooltip: 'Change Language',
      onSelected: (code) => langProvider.setLanguage(code),
      itemBuilder: (context) => LanguageProvider.languages.map((l) {
        return PopupMenuItem<String>(
          value: l['code'],
          child: Text('${l['nativeName']} (${l['name']})'),
        );
      }).toList(),
    );
  }

  Future<void> _markWorkerAttendance(Worker worker, bool isCurrentlyIn) async {
    try {
      if (isCurrentlyIn) {
        final workerId = int.tryParse(worker.id.toString());
        if (workerId == null || workerId <= 0) {
          throw StateError('Invalid worker ID: ${worker.id}');
        }
        await OfflineAttendanceService.checkOut(
          employeeId: workerId,
          workerId: workerId,
        );
        _showSnack('✅ ${worker.name} checked out — saved offline and queued', _primary);
      } else {
        final workerId = int.tryParse(worker.id.toString());
        if (workerId == null || workerId <= 0) {
          throw StateError('Invalid worker ID: ${worker.id}');
        }
        await OfflineAttendanceService.checkIn(
          employeeId: workerId,
          workerId: workerId,
        );
        _showSnack('✅ ${worker.name} checked in — saved offline and queued', _present);
      }
      await _fetch();
    } catch (e) {
      _showSnack('❌ Attendance could not be saved: $e', _absent);
    }
  }

  Future<bool> _showVerifyPinDialog(Worker worker) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter PIN for ${worker.name}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your 4-digit attendance PIN to verify identity.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _primary.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (controller.text == worker.pin) {
                Navigator.pop(ctx, true);
              } else {
                _showSnack('❌ Invalid PIN. Please try again.', _absent);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            child: const Text('VERIFY'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}