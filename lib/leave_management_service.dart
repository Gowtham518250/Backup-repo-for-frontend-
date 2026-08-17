import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'api_client.dart';

/// 👥 Leave Management Service
/// Handles employee leave requests, approvals, and tracking
class LeaveManagementService {
  /// Request leave
  static Future<bool> requestLeave({
    required int workerId,
    required String leaveType,  // 'sick', 'casual', 'personal', 'unpaid'
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    try {
      final body = {
        'worker_id': workerId,
        'leave_type': leaveType,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        if (reason != null) 'reason': reason,
      };

      final response = await ApiClient.postJson('/api/attendance/leave-request', body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) debugPrint('✅ Leave request submitted');
        return true;
      }
      
      if (kDebugMode) debugPrint('❌ Leave request failed: ${response.statusCode}');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Leave request error: $e');
      return false;
    }
  }

  /// Get all leave requests
  static Future<List<LeaveRequest>> getLeaveRequests({
    String? status,  // 'pending', 'approved', 'rejected'
    int limit = 100,
  }) async {
    try {
      final query = status != null 
          ? '/api/attendance/leave-requests?status=$status&limit=$limit'
          : '/api/attendance/leave-requests?limit=$limit';
      
      final response = await ApiClient.getJson(query);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['leave_requests'] ?? data['items'] ?? [];
        
        return items.map((item) => LeaveRequest.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Get leave requests error: $e');
      return [];
    }
  }

  /// Approve leave request
  static Future<bool> approveLeave(int leaveId) async {
    try {
      final response = await ApiClient.putJson(
        '/api/attendance/leave-request/$leaveId/approve',
        {},
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) debugPrint('✅ Leave approved');
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Approve leave error: $e');
      return false;
    }
  }

  /// Reject leave request
  static Future<bool> rejectLeave(int leaveId, {String? reason}) async {
    try {
      final body = {
        if (reason != null) 'reason': reason,
      };

      final response = await ApiClient.putJson(
        '/api/attendance/leave-request/$leaveId/reject',
        body,
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) debugPrint('✅ Leave rejected');
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Reject leave error: $e');
      return false;
    }
  }

  /// Get attendance summary for employee
  static Future<AttendanceSummary?> getAttendanceSummary(int employeeId) async {
    try {
      final response = await ApiClient.getJson(
        '/api/attendance/analytics/employee/$employeeId',
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AttendanceSummary.fromJson(data);
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Get attendance summary error: $e');
      return null;
    }
  }

  /// Get attendance by date
  static Future<List<AttendanceRecord>> getAttendanceByDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await ApiClient.getJson(
        '/api/attendance/date/$dateStr',
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['attendance'] ?? data['items'] ?? [];
        
        return items.map((item) => AttendanceRecord.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Get attendance by date error: $e');
      return [];
    }
  }
}

/// Leave Request Model
class LeaveRequest {
  final int id;
  final int workerId;
  final String workerName;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;  // 'pending', 'approved', 'rejected'
  final String? reason;
  final String? approverComment;
  final DateTime createdAt;

  LeaveRequest({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
    this.approverComment,
    required this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] ?? 0,
      workerId: json['worker_id'] ?? 0,
      workerName: json['worker_name'] ?? json['name'] ?? '',
      leaveType: json['leave_type'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      status: json['status'] ?? 'pending',
      reason: json['reason'],
      approverComment: json['approver_comment'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
    );
  }

  int get durationDays => endDate.difference(startDate).inDays + 1;

  String get statusLabel {
    switch (status) {
      case 'approved': return '✅ Approved';
      case 'rejected': return '❌ Rejected';
      default: return '⏳ Pending';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'approved': return const Color(0xFF16A34A);
      case 'rejected': return const Color(0xFFDC2626);
      default: return const Color(0xFFFBBF24);
    }
  }
}

/// Attendance Summary
class AttendanceSummary {
  final int employeeId;
  final String employeeName;
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final double attendancePercentage;
  final DateTime? lastCheckin;
  final DateTime? lastCheckout;

  AttendanceSummary({
    required this.employeeId,
    required this.employeeName,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.attendancePercentage,
    this.lastCheckin,
    this.lastCheckout,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      employeeId: json['employee_id'] ?? json['worker_id'] ?? 0,
      employeeName: json['employee_name'] ?? json['name'] ?? '',
      presentDays: json['present_days'] ?? 0,
      absentDays: json['absent_days'] ?? 0,
      leaveDays: json['leave_days'] ?? 0,
      attendancePercentage: (json['attendance_percentage'] ?? 0).toDouble(),
      lastCheckin: json['last_checkin'] != null
          ? DateTime.parse(json['last_checkin'])
          : null,
      lastCheckout: json['last_checkout'] != null
          ? DateTime.parse(json['last_checkout'])
          : null,
    );
  }
}

/// Attendance Record
class AttendanceRecord {
  final int id;
  final int workerId;
  final String workerName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? status;  // 'present', 'absent', 'on_leave'

  AttendanceRecord({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.checkInTime,
    this.checkOutTime,
    this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      workerId: json['worker_id'] ?? 0,
      workerName: json['worker_name'] ?? json['name'] ?? '',
      checkInTime: DateTime.parse(json['check_in_time'] ?? json['checkin_time'] ?? DateTime.now().toString()),
      checkOutTime: json['check_out_time'] != null || json['checkout_time'] != null
          ? DateTime.parse(json['check_out_time'] ?? json['checkout_time'])
          : null,
      status: json['status'],
    );
  }

  Duration get workDuration {
    if (checkOutTime == null) return Duration.zero;
    return checkOutTime!.difference(checkInTime);
  }

  String get workHours {
    final duration = workDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}h';
  }
}

extension ColorParse on String? {
  Color toColor() {
    return const Color(0xFF000000);
  }
}

extension ColorToString on Color {
  String toHex() {
    return '#${value.toRadixString(16)}';
  }
}
