class Place {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String category;

  Place({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      // HTML 태그(<b></b>) 제거
      name: json['title']?.toString().replaceAll(RegExp(r'<[^>]*>'), '') ?? '이름없음',
      address: json['roadAddress'] ?? json['address'] ?? '주소없음',
      lat: double.tryParse(json['mapy'] ?? '0') ?? 0.0,
      lng: double.tryParse(json['mapx'] ?? '0') ?? 0.0,
      category: json['category'] ?? '기타',
    );
  }
}
