class SalesItem {
  final String id;
  final String itemName;
  final double quantity;
  final double price;
  final double gst;
  final double discount;

  const SalesItem({
    required this.id,
    this.itemName = '',
    this.quantity = 1.0,
    this.price = 0.0,
    this.gst = 0.0,
    this.discount = 0.0,
  });

  SalesItem copyWith({
    String? itemName,
    double? quantity,
    double? price,
    double? gst,
    double? discount,
  }) {
    return SalesItem(
      id: id,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      gst: gst ?? this.gst,
      discount: discount ?? this.discount,
    );
  }

  double get subtotal => quantity * price;
  double get totalGstAmount => subtotal * (gst / 100);
  double get finalAmount => subtotal + totalGstAmount - discount;
}
