// FIX-7: Worker State Management — Track multi-staff billing

import 'package:flutter/foundation.dart';

/// Represents a worker in the system
class WorkerState {
  final String id;
  final String name;
  final String phone;
  final String assignedWork;
  final DateTime joinDate;
  final String status; // ACTIVE, INACTIVE, ON_LEAVE
  final String? pin;
  final DateTime? lastActive;

  WorkerState({
    required this.id,
    required this.name,
    required this.phone,
    required this.assignedWork,
    required this.joinDate,
    required this.status,
    this.pin,
    this.lastActive,
  });

  WorkerState copyWith({
    String? status,
    DateTime? lastActive,
  }) => WorkerState(
    id: id,
    name: name,
    phone: phone,
    assignedWork: assignedWork,
    joinDate: joinDate,
    status: status ?? this.status,
    pin: pin,
    lastActive: lastActive ?? this.lastActive,
  );
}

/// Manages worker state — prevents raw setState rebuilds across counter pages
class WorkerStateNotifier extends ChangeNotifier {
  final Map<String, WorkerState> _workers = {};

  List<WorkerState> get workers => _workers.values.toList();
  
  WorkerState? getWorker(String id) => _workers[id];

  /// Add new worker
  void addWorker(WorkerState worker) {
    _workers[worker.id] = worker;
    notifyListeners();
  }

  /// Update worker status
  void updateWorkerStatus(String workerId, String newStatus) {
    final worker = _workers[workerId];
    if (worker == null) return;
    _workers[workerId] = worker.copyWith(
      status: newStatus,
      lastActive: DateTime.now(),
    );
    notifyListeners();
  }

  /// Mark worker as active (for last-active tracking)
  void recordActivity(String workerId) {
    final worker = _workers[workerId];
    if (worker == null) return;
    _workers[workerId] = worker.copyWith(
      lastActive: DateTime.now(),
    );
    notifyListeners();
  }

  /// Get active workers only
  List<WorkerState> get activeWorkers => _workers.values
      .where((w) => w.status == 'ACTIVE' || w.status == 'on_leave')
      .toList();

  int get activeCount => activeWorkers.length;
  int get totalCount => _workers.length;

  void clear() {
    _workers.clear();
    notifyListeners();
  }
}
