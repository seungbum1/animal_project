import 'package:flutter/material.dart';
import 'hospital_detail_page.dart';

/// ✅ 유저 즐겨찾기(저장된 장소) 페이지 (디자인 개선)
class UserSavedPlacesPage extends StatefulWidget {
  final List<Map<String, dynamic>> savedPlaces;

  const UserSavedPlacesPage({super.key, required this.savedPlaces});

  @override
  State<UserSavedPlacesPage> createState() => _UserSavedPlacesPageState();
}

class _UserSavedPlacesPageState extends State<UserSavedPlacesPage> {
  late List<Map<String, dynamic>> _savedPlaces;

  @override
  void initState() {
    super.initState();
    _savedPlaces = List<Map<String, dynamic>>.from(widget.savedPlaces);
  }

  void _toggleSave(Map<String, dynamic> place) {
    setState(() {
      final exists =
      _savedPlaces.any((p) => p["place_name"] == place["place_name"]);
      if (exists) {
        _savedPlaces.removeWhere(
                (p) => p["place_name"] == place["place_name"]);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("저장 목록에서 제거되었습니다 🗑️")),
        );
      } else {
        _savedPlaces.add(place);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("저장 목록에 추가되었습니다 ❤️")),
        );
      }
    });

    /// ✅ 부모 페이지(HospitalListPage)에 즉시 반영
    Navigator.pop(context, _savedPlaces);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7CC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF7CC),
          elevation: 0,
          title: const Text(
            "저장된 장소",
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context, _savedPlaces),
          ),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black45,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "카페"),
              Tab(text: "식당"),
              Tab(text: "숙소"),
              Tab(text: "유치원"),
            ],
          ),
        ),
        body: TabBarView(
          children: ['카페', '식당', '숙소', '유치원'].map((category) {
            final filtered = _savedPlaces.where((p) {
              final name = (p["place_name"] ?? "").toLowerCase();
              final categoryName = (p["category_name"] ?? "").toLowerCase();

              if (category == "카페") {
                return categoryName.contains("카페") ||
                    name.contains("카페") ||
                    categoryName.contains("coffee") ||
                    name.contains("coffee");
              }
              if (category == "식당") {
                return categoryName.contains("식당") ||
                    categoryName.contains("음식점") ||
                    name.contains("식당") ||
                    name.contains("restaurant");
              }
              if (category == "숙소") {
                return categoryName.contains("숙소") ||
                    categoryName.contains("호텔") ||
                    categoryName.contains("모텔") ||
                    categoryName.contains("게스트하우스") ||
                    name.contains("호텔") ||
                    name.contains("모텔") ||
                    name.contains("숙박") ||
                    name.contains("펫호텔");
              }
              if (category == "유치원") {
                return categoryName.contains("유치원") ||
                    categoryName.contains("훈련") ||
                    categoryName.contains("교육") ||
                    categoryName.contains("반려동물") ||
                    categoryName.contains("펫") ||
                    name.contains("유치원") ||
                    name.contains("훈련") ||
                    name.contains("교육");
              }
              return false;
            }).toList();

            if (filtered.isEmpty) {
              return const Center(
                child: Text(
                  "저장된 장소가 없습니다 😥",
                  style: TextStyle(color: Colors.black54, fontSize: 15),
                ),
              );
            }

            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, index) {
                final place = filtered[index];
                final isSaved = _savedPlaces
                    .any((p) => p["place_name"] == place["place_name"]);

                final distance =
                    double.tryParse(place["distance"] ?? "0") ?? 0.0;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HospitalDetailPage(
                          name: place["place_name"] ?? "이름 없음",
                          category: place["category_name"] ?? "",
                          address: place["road_address_name"] ??
                              place["address_name"] ??
                              "주소 없음",
                          rating: 4.8,
                          phone: place["phone"] ?? "전화번호 없음",
                          url: place["place_url"] ?? "",
                          latitude:
                          double.tryParse(place["y"] ?? "0") ?? 0.0,
                          longitude:
                          double.tryParse(place["x"] ?? "0") ?? 0.0,
                          currentLat: 37.544583,
                          currentLng: 127.055897,

                          /// ✅ 추가된 인자 (에러 해결용)
                          savedPlaces: const [],
                          onUpdateSavedPlaces: (_) {},
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    color: Colors.white,
                    shadowColor: Colors.grey.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// ✅ 썸네일
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: place["thumbnail"] != null
                                ? Image.network(
                              place["thumbnail"],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fallbackImage(),
                            )
                                : _fallbackImage(),
                          ),
                          const SizedBox(width: 12),

                          /// ✅ 정보 + 북마크
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        place["place_name"] ?? "이름 없음",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isSaved
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: isSaved
                                            ? Colors.orangeAccent
                                            : Colors.grey,
                                        size: 24,
                                      ),
                                      onPressed: () => _toggleSave(place),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                Row(
                                  children: const [
                                    Icon(Icons.star,
                                        color: Colors.amber, size: 16),
                                    SizedBox(width: 4),
                                    Text("4.8 ❤️ 재방문의사",
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87)),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        place["category_name"] ?? "",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      distance > 0
                                          ? "${(distance / 1000).toStringAsFixed(1)} km"
                                          : "- km",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
        size: 28,
      ),
    );
  }
}