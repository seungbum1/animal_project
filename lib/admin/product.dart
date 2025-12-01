import 'package:animal_project/api_config.dart';  // ⭐ 서버 주소 적용을 위해 필수

class Product {
  String id;
  String name;
  String category;
  String description;
  int quantity;
  int price;
  List<String> images;
  int count;
  double averageRating; // ⭐ 평균 평점 추가

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.quantity,
    required this.price,
    required this.images,
    this.count = 1, // 기본값
    this.averageRating = 0.0, // 기본값
  });

  /// ==========================================================
  /// ✅ 서버 JSON → Product 객체 변환
  /// ==========================================================
  factory Product.fromJson(Map<String, dynamic> json) {
    // 서버에서 받은 이미지 경로 리스트
    List<String> rawImages = List<String>.from(json['images'] ?? []);

    // "/uploads/abc.jpg" → "${ApiConfig.baseUrl}/uploads/abc.jpg"
    List<String> fullUrls = rawImages.map((path) {
      if (path.startsWith("http")) {
        return path; // URL 완성된 경우 그대로 사용
      } else {
        // 자동으로 서버 baseUrl 붙이기
        return "${ApiConfig.baseUrl}$path";
      }
    }).toList();

    return Product(
      id: json['_id']?.toString() ?? "",
      name: json['name'] ?? "",
      category: json['category'] ?? "",
      description: json['description'] ?? "",
      quantity: json['quantity'] ?? 0,
      price: json['price'] ?? 0,
      images: fullUrls,
      count: json['count'] != null
          ? (json['count'] is int
          ? json['count']
          : (json['count'] as num).toInt())
          : 1,
      averageRating: json['averageRating'] != null
          ? (json['averageRating'] as num).toDouble()
          : 0.0,
    );
  }

  /// ==========================================================
  /// ✅ Product 객체 → 서버로 보낼 JSON 변환
  /// ==========================================================
  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "name": name,
      "category": category,
      "description": description,
      "quantity": quantity,
      "price": price,
      "images": images, // 서버에서는 상대경로로 저장됨
      "count": count,
      "averageRating": averageRating,
    };
  }
}