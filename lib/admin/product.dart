class Product {
  final String id; // ✅ MongoDB 문서 고유 ID (_id)
  final String name;
  final String category;
  final String description;
  final int quantity;
  final int price;
  final List<String> images;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.quantity,
    required this.price,
    required this.images,
  });

  /// ✅ 서버에서 받아온 JSON → Product 객체 변환
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id']?.toString() ?? "", // 항상 String 변환
      name: json['name'],
      category: json['category'],
      description: json['description'],
      quantity: json['quantity'],
      price: json['price'],
      images: List<String>.from(json['images'] ?? []),
    );
  }

  /// ✅ Product 객체 → 서버로 보낼 JSON
  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "name": name,
      "category": category,
      "description": description,
      "quantity": quantity,
      "price": price,
      "images": images,
    };
  }
}
