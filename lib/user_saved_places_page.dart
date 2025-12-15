import 'package:flutter/material.dart';
import 'hospital_detail_page.dart';
import 'place.dart'; // SavedPlacesManager 사용을 위해 import

/// ✅ 유저 즐겨찾기(저장된 장소) 페이지 (데이터 자동 로드 추가)
class UserSavedPlacesPage extends StatefulWidget {
  final List<Map<String, dynamic>> savedPlaces; // 초기값으로만 사용
  final String? token;

  const UserSavedPlacesPage({
    super.key,
    required this.savedPlaces,
    required this.token,
  });

  @override
  State<UserSavedPlacesPage> createState() => _UserSavedPlacesPageState();
}

class _UserSavedPlacesPageState extends State<UserSavedPlacesPage> {
  late List<Map<String, dynamic>> _savedPlaces;
  bool _isLoading = true; // 로딩 상태 추가

  @override
  void initState() {
    super.initState();
    // 일단 넘겨받은 데이터로 초기화
    _savedPlaces = List<Map<String, dynamic>>.from(widget.savedPlaces);

    // ✨ [핵심] 화면 들어오자마자 서버에서 최신 목록 다시 당겨오기
    _fetchLatestData();
  }

  Future<void> _fetchLatestData() async {
    await SavedPlacesManager.loadFromServer(widget.token);
    if (mounted) {
      setState(() {
        _savedPlaces = List.from(SavedPlacesManager.places);
        _isLoading = false;
      });
    }
  }

  void _toggleSave(Map<String, dynamic> place) async {
    // 1. UI에서 즉시 반영 (낙관적 업데이트)
    setState(() {
      final exists = _savedPlaces.any((p) => p["place_name"] == place["place_name"]);
      if (exists) {
        _savedPlaces.removeWhere((p) => p["place_name"] == place["place_name"]);
      } else {
        _savedPlaces.add(place);
      }
    });

    // 2. 서버 통신
    bool isSaved = await SavedPlacesManager.toggleServer(place, widget.token);

    // 3. 서버 결과에 따라 동기화 (혹시 실패했을 경우를 대비)
    if (mounted) {
      setState(() {
        // 서버에 실제 저장된 목록으로 다시 맞춤
        _savedPlaces = List.from(SavedPlacesManager.places);
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSaved ? "저장 목록에 추가되었습니다 ❤️" : "저장 목록에서 제거되었습니다 🗑️")),
      );
    }
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
            style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context, _savedPlaces),
          ),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black45,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "카페"),
              Tab(text: "식당"),
              Tab(text: "숙소"),
              Tab(text: "유치원"),
            ],
          ),
        ),
        body: _isLoading && _savedPlaces.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Colors.orange)) // 로딩 중 표시
            : TabBarView(
          children: ['카페', '식당', '숙소', '유치원'].map((category) {
            final filtered = _savedPlaces.where((p) {
              final name = (p["place_name"] ?? "").toLowerCase();
              final categoryName = (p["category_name"] ?? "").toLowerCase();

              // 검색 키워드 매칭 로직
              if (category == "카페") {
                return categoryName.contains("카페") || name.contains("카페") || categoryName.contains("coffee");
              }
              if (category == "식당") {
                return categoryName.contains("식당") || categoryName.contains("음식점") || name.contains("식당");
              }
              if (category == "숙소") {
                return categoryName.contains("숙소") || categoryName.contains("호텔") || categoryName.contains("펜션") || name.contains("호텔");
              }
              if (category == "유치원") {
                return categoryName.contains("유치원") || categoryName.contains("훈련") || name.contains("유치원");
              }
              return false;
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmark_border, size: 48, color: Colors.black26),
                    const SizedBox(height: 12),
                    Text(
                      "$category 저장 내역이 없습니다.",
                      style: const TextStyle(color: Colors.black54, fontSize: 15),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: filtered.length,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemBuilder: (_, index) {
                final place = filtered[index];
                final isSaved = _savedPlaces.any((p) => p["place_name"] == place["place_name"]);
                final distance = double.tryParse(place["distance"] ?? "0") ?? 0.0;

                // 📏 거리 텍스트 포맷팅
                String distanceText;
                if (distance <= 0) {
                  distanceText = "-";
                } else if (distance < 1000) {
                  distanceText = "${distance.toInt()}m";
                } else {
                  distanceText = "${(distance / 1000).toStringAsFixed(1)}km";
                }
                return GestureDetector(
                  onTap: () async {
                    // 상세 페이지로 이동 후 돌아올 때 데이터 갱신
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HospitalDetailPage(
                          token: widget.token,
                          name: place["place_name"] ?? "이름 없음",
                          category: place["category_name"] ?? "",
                          address: place["road_address_name"] ?? place["address_name"] ?? "주소 없음",
                          rating: 4.8,
                          phone: place["phone"] ?? "전화번호 없음",
                          url: place["place_url"] ?? "",
                          latitude: double.tryParse(place["y"] ?? "0") ?? 0.0,
                          longitude: double.tryParse(place["x"] ?? "0") ?? 0.0,
                          currentLat: 37.544583, // 필요시 현위치 받아오도록 수정 가능
                          currentLng: 127.055897,
                        ),
                      ),
                    );
                    // 상세에서 저장 취소했을 수도 있으므로 다시 로드
                    _fetchLatestData();
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    color: Colors.white,
                    shadowColor: Colors.black.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// ✅ 썸네일
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: place["thumbnail"] != null
                                ? Image.network(
                              place["thumbnail"],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fallbackImage(),
                            )
                                : _fallbackImage(),
                          ),
                          const SizedBox(width: 16),

                          /// ✅ 정보 + 북마크
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        place["place_name"] ?? "이름 없음",
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _toggleSave(place),
                                      child: const Icon(Icons.bookmark, color: Color(0xFFC06362), size: 24),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  place["category_name"] ?? "",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 2),
                                    const Text("4.8", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),

                                    // ✨ 수정된 거리 텍스트 적용
                                    Text(
                                      distanceText,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
      width: 80, height: 80,
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.storefront_rounded, color: Colors.grey, size: 28),
    );
  }
}