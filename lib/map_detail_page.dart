import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'hospital_detail_page.dart';
import 'route_finding_page.dart';

class MapDetailPage extends StatefulWidget {
  final String hospitalName;
  final double latitude;
  final double longitude;

  const MapDetailPage({
    super.key,
    required this.hospitalName,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<MapDetailPage> createState() => _MapDetailPageState();
}

class _MapDetailPageState extends State<MapDetailPage> {
  late NaverMapController _mapController;
  String _selectedCategory = "카페";
  List<Map<String, dynamic>> _places = [];
  Map<String, dynamic>? _selectedPlace;

  final String kakaoApiKey = "bc6ab37a4ae28c4d0d8d2dbf8a3c8378";
  final String naverClientId = "pQH6nAMSamieCWngCpdQ";
  final String naverClientSecret = "YkaOM236tc";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPlaces("카페");
    });
  }

  /// ✅ 카카오 + 네이버 이미지 썸네일 가져오기
  Future<void> _fetchPlaces(String category) async {
    final query = {
      "카페": "애견카페",
      "식당": "애견식당",
      "숙소": "펫호텔",
      "유치원": "애견유치원",
    }[category] ?? category;

    final url = Uri.parse(
      "https://dapi.kakao.com/v2/local/search/keyword.json"
          "?query=$query"
          "&x=${widget.longitude}"
          "&y=${widget.latitude}"
          "&radius=5000"
          "&size=10",
    );

    final response =
    await http.get(url, headers: {"Authorization": "KakaoAK $kakaoApiKey"});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<Map<String, dynamic>> results =
      List<Map<String, dynamic>>.from(data["documents"]);

      for (var place in results) {
        final imageUrl = await _fetchPlaceImageFromNaver(place["place_name"]);
        place["thumbnail"] = imageUrl;
      }

      setState(() {
        _places = results;
        _selectedPlace = null;
      });
      _updateMarkers();
    } else {
      print("❌ Kakao API 호출 실패: ${response.statusCode}");
    }
  }

  /// ✅ 네이버 이미지 검색 API로 대표 썸네일 가져오기
  Future<String?> _fetchPlaceImageFromNaver(String placeName) async {
    final url = Uri.parse(
        "https://openapi.naver.com/v1/search/image?query=$placeName&display=1&sort=sim");

    final response = await http.get(url, headers: {
      "X-Naver-Client-Id": naverClientId,
      "X-Naver-Client-Secret": naverClientSecret,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["items"] != null && data["items"].isNotEmpty) {
        return data["items"][0]["link"];
      }
    } else {
      print("❌ 네이버 이미지 검색 실패: ${response.statusCode}");
    }
    return null;
  }

  /// ✅ 마커 업데이트
  void _updateMarkers() {
    _mapController.clearOverlays();

    final hospitalMarker = NMarker(
      id: "hospital_marker",
      position: NLatLng(widget.latitude, widget.longitude),
      caption: NOverlayCaption(text: widget.hospitalName),
    );
    _mapController.addOverlay(hospitalMarker);

    for (var place in _places) {
      final lat = double.tryParse(place["y"] ?? "");
      final lng = double.tryParse(place["x"] ?? "");
      if (lat != null && lng != null) {
        final marker = NMarker(
          id: place["id"] ?? place["place_name"],
          position: NLatLng(lat, lng),
          caption: NOverlayCaption(text: place["place_name"]),
        );
        marker.setOnTapListener((overlay) {
          setState(() {
            _selectedPlace = place;
          });
        });
        _mapController.addOverlay(marker);
      }
    }

    _mapController.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(widget.latitude, widget.longitude),
        zoom: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NLatLng hospitalLocation = NLatLng(widget.latitude, widget.longitude);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.hospitalName,
            style: const TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: hospitalLocation,
                zoom: 15,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _updateMarkers();
            },
          ),
          Positioned(top: 16, left: 0, right: 0, child: Center(child: _buildCategoryBar())),
          if (_selectedPlace != null) _buildBottomInfoCard(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showPlaceList(context),
                child: const Text("목록 ▤",
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 하단 인포 카드
  Widget _buildBottomInfoCard() {
    final place = _selectedPlace!;
    final distance = double.tryParse(place["distance"] ?? "0") ?? 0.0;
    final distanceText =
    distance > 0 ? "${(distance / 1000).toStringAsFixed(1)} km" : "- km";

    return Positioned(
      left: 16,
      right: 16,
      bottom: 90,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place["place_name"],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                place["road_address_name"] ??
                    place["address_name"] ??
                    "주소 정보 없음",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text("거리: $distanceText",
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteFindingPage(
                          destinationName: place["place_name"],
                          destinationLat: double.parse(place["y"] ?? "0"),
                          destinationLng: double.parse(place["x"] ?? "0"),
                          originLat: 37.544583,
                          originLng: 127.055897,
                        ),
                      ),
                    );
                  },
                  child: const Text("길 찾기",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ 카테고리 버튼
  Widget _buildCategoryBar() {
    final List<String> categories = ["카페", "식당", "숙소", "유치원"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: categories.map((category) {
        final bool isSelected = _selectedCategory == category;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
              _fetchPlaces(category);
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFF7CC) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Text(category,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w500)),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// ✅ 목록창 (HospitalDetailPage 호출 수정됨)
  void _showPlaceList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text("주변 ${_selectedCategory}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: _places.isEmpty
                    ? const Center(child: Text("주변 장소가 없습니다 😥"))
                    : ListView.builder(
                  itemCount: _places.length,
                  itemBuilder: (context, index) {
                    final place = _places[index];
                    final distance =
                        double.tryParse(place["distance"] ?? "0") ?? 0.0;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HospitalDetailPage(
                              name: place["place_name"],
                              category: place["category_name"] ?? "",
                              address: place["road_address_name"] ??
                                  place["address_name"] ??
                                  "주소 없음",
                              rating: 4.9,
                              phone:
                              place["phone"] ?? "전화번호 없음",
                              url: place["place_url"] ?? "",
                              latitude:
                              double.tryParse(place["y"] ?? "0") ??
                                  0,
                              longitude:
                              double.tryParse(place["x"] ?? "0") ??
                                  0,
                              currentLat: 37.544583,
                              currentLng: 127.055897,

                              // ✅ 추가된 인자 (에러 해결용)
                              savedPlaces: const [],
                              onUpdateSavedPlaces: (_) {},
                            ),
                          ),
                        );
                      },
                      child: FacilityCard(
                        name: place["place_name"],
                        category: place["category_name"] ?? "",
                        distance: distance,
                        imageUrl: place["thumbnail"],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ✅ 큐라펫 스타일 카드
class FacilityCard extends StatelessWidget {
  final String name;
  final String category;
  final double distance;
  final String? imageUrl;

  const FacilityCard({
    super.key,
    required this.name,
    required this.category,
    required this.distance,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: Colors.white,
      shadowColor: Colors.grey.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? Image.network(
                imageUrl!,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackImage(),
              )
                  : _fallbackImage(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.bookmark_border,
                          color: Colors.grey, size: 22),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "4.8 ❤️ 재방문의사",
                        style:
                        TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          category,
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
                            fontSize: 13, color: Colors.black45),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
      child: const Icon(Icons.image_not_supported,
          color: Colors.grey, size: 28),
    );
  }
}
