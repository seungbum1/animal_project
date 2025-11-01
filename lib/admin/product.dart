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
    this.count = 1, // ✅ 기본값 추가
    this.averageRating = 0.0, // ⭐ 기본값 설정
  });

  /// ✅ 서버에서 받아온 JSON → Product 객체 변환
  factory Product.fromJson(Map<String, dynamic> json) {
    // 서버에서 받은 이미지 경로를 자동으로 URL로 바꿔줌
    List<String> rawImages = List<String>.from(json['images'] ?? []);

    // "/uploads/abc.jpg" → "http://127.0.0.1:5000/uploads/abc.jpg"
    List<String> fullUrls = rawImages.map((path) {
      if (path.startsWith("http")) {
        return path; // 이미 완전한 URL이면 그대로 사용
      } else {
        return "http://127.0.0.1:5000$path";
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
      // ✅ 서버에서 count를 함께 받으면 반영, 없으면 1로 기본값
      count: json['count'] != null
          ? (json['count'] is int
          ? json['count']
          : (json['count'] as num).toInt())
          : 1,
      averageRating:
      (json['averageRating'] != null) // ⭐ 서버 응답에서 평점 불러오기
          ? (json['averageRating'] as num).toDouble()
          : 0.0,
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
      "count": count, // ✅ 추가
      "averageRating": averageRating, // ⭐ JSON에도 포함
    };
  }
}
