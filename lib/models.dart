/// Chat message model for the chatbot functionality
class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.timestamp,
  });
}

class Worker {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double salary;
  final String assignedWork;
  final String position;
  final DateTime joinDate;
  final String status;
  final String pin;
  List<String> attendance;

  Worker({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.salary,
    required this.assignedWork,
    required this.position,
    required this.joinDate,
    required this.status,
    this.pin = '',
    List<String>? attendance,
  }) : attendance = attendance ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'salary': salary,
    'assigned_work': assignedWork,  // 🔧 FIXED: Backend column is 'assigned_work'
    'position': position,
    'join_date': joinDate.toIso8601String(),  // 🔧 FIXED: Backend column is 'join_date'
    'status': status,
    'pin': pin,
    // 🔧 REMOVED: 'attendance' field is NOT supported in backend Worker model
  };

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
    id: json['id']?.toString() ?? '',  // 🔧 FIXED: Handle both int and string IDs
    name: json['name'] as String? ?? 'Unknown',
    phone: json['phone'] as String? ?? '',
    address: json['address'] as String? ?? '',
    salary: (json['salary'] as num?)?.toDouble() ?? 0,
    assignedWork: json['assigned_work'] as String? ?? json['assignedWork'] as String? ?? '',  // 🔧 Try backend key first
    position: json['position'] as String? ?? 'Staff',
    joinDate: (json['join_date'] != null ? DateTime.tryParse(json['join_date'] as String) : null) ?? (json['joinDate'] != null ? DateTime.tryParse(json['joinDate'] as String) : null) ?? DateTime.now(),  // 🔧 Try backend key first
    status: json['status'] as String? ?? 'active',
    pin: json['pin'] as String? ?? '',
    attendance: (json['attendance'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],  // 🔧 Keep local only
  );
}

class Supplier {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String category;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    category: json['category'] as String? ?? 'General',
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String) 
        : DateTime.now(),
  );
}

