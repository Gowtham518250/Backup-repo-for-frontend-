class StoredSale {
  StoredSale({
    required this.saleId,
    required this.status,
    required this.createdAt,
    required this.rawData,
  });

  final String saleId;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> rawData;

  Map<String, dynamic> toJson() => {
        'sale_id': saleId,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        ...rawData,
      };

  factory StoredSale.fromJson(Map<String, dynamic> json) {
    final saleId = json['sale_id']?.toString() ?? json['invoice_number']?.toString() ?? json['id']?.toString() ?? '';
    return StoredSale(
      saleId: saleId,
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      rawData: Map<String, dynamic>.from(json),
    );
  }
}
