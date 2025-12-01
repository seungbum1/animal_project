import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'hospital_detail_page.dart';

/// ✅ 정렬 옵션
enum SortOption { distance, longDistance, rating }

class HospitalListPage extends StatefulWidget {
  final String? category;
  const HospitalListPage({super.key, this.category});

  @override
  State<HospitalListPage> createState() => _HospitalListPageState();
}

class _HospitalListPageState extends State<HospitalListPage> {
  SortOption _currentSort = SortOption.rating;
  String _selectedCategory = '카페';
  NaverMapController? _mapController;

  NLatLng? _currentLocation;
  bool _isLoading = true;
  String _searchKeyword = '';

  final String kakaoApiKey = "bc6ab37a4ae28c4d0d8d2dbf8a3c8378";
  final String naverClientId = "pQH6nAMSamieCWngCpdQ";
  final String naverClientSecret = "YkaOM236tc";

  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _savedPlaces = []; // ✅ 즐겨찾기 리스트 추가

  final Map<String, String> _petKeywords = {
    "카페": "애견카페",
    "식당": "애견식당",
    "숙소": "펫호텔",
    "유치원": "애견유치원",
  };

  @override
  void initState() {
    super.initState();
    if (widget.category != null && widget.category!.isNotEmpty) {
      _selectedCategory = widget.category!;
    }
    _initLocationAndFetchPlaces();
  }

  /// ✅ 위치 권한 요청 + 현재 위치 불러오기
  Future<void> _initLocationAndFetchPlaces() async {
    setState(() => _isLoading = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("위치 서비스가 비활성화되어 있습니다.")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("위치 권한이 거부되었습니다.")),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentLocation = NLatLng(position.latitude, position.longitude);
    });

    await fetchPlaces();
  }

  /// ✅ 장소 검색
  Future<void> fetchPlaces({String? keyword}) async {
    if (_currentLocation == null) return;

    setState(() => _isLoading = true);
    final query = keyword != null && keyword.isNotEmpty
        ? keyword
        : _petKeywords[_selectedCategory] ?? _selectedCategory;

    final url = Uri.parse(
      "https://dapi.kakao.com/v2/local/search/keyword.json"
          "?query=$query"
          "&x=${_currentLocation!.longitude}"
          "&y=${_currentLocation!.latitude}"
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
        _isLoading = false;
      });

      _sortPlaces();
      _updateMapMarkers();
    } else {
      setState(() {
        _places = [];
        _isLoading = false;
      });
    }
  }

  /// ✅ 네이버 이미지 검색
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
    }
    return null;
  }

  /// ✅ 정렬
  void _sortPlaces() {
    if (_currentSort == SortOption.distance) {
      _places.sort((a, b) => double.parse(a["distance"] ?? "0")
          .compareTo(double.parse(b["distance"] ?? "0")));
    } else if (_currentSort == SortOption.longDistance) {
      _places.sort((a, b) => double.parse(b["distance"] ?? "0")
          .compareTo(double.parse(a["distance"] ?? "0")));
    }
  }

  /// ✅ 지도 마커 표시
  void _updateMapMarkers() {
    if (_mapController == null || _currentLocation == null) return;

    _mapController!.clearOverlays();

    final myMarker = NMarker(
      id: "current_location",
      position: _currentLocation!,
      iconTintColor: Colors.blue,
    );
    _mapController!.addOverlay(myMarker);

    for (var place in _places) {
      final lat = double.tryParse(place["y"] ?? "");
      final lng = double.tryParse(place["x"] ?? "");
      if (lat != null && lng != null) {
        final marker = NMarker(
          id: place["id"] ?? place["place_name"],
          position: NLatLng(lat, lng),
          iconTintColor: Colors.orange,
        );
        _mapController!.addOverlay(marker);
      }
    }
  }

  /// ✅ 검색창
  Future<void> _showSearchDialog() async {
    final controller = TextEditingController(text: _searchKeyword);
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("장소 검색"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "예: 카페, 식당, 숙소, 유치원...",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchKeyword = controller.text.trim();
                });
                fetchPlaces(keyword: _searchKeyword);
                Navigator.pop(context);
              },
              child: const Text("검색"),
            ),
          ],
        );
      },
    );
  }

  /// ✅ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          color: const Color(0xFFFFF5C0),
          padding:
          const EdgeInsets.only(top: 45, left: 16, right: 16, bottom: 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child:
                const Icon(Icons.arrow_back, color: Colors.black, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildCategoryTabsArea()),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showSearchDialog,
                child:
                const Icon(Icons.search, color: Colors.black, size: 26),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildMapArea(),
          _buildSortDropdown(),
          Expanded(
            child: ListView.builder(
              itemCount: _places.length,
              itemBuilder: (context, index) {
                final place = _places[index];
                return _buildPlaceCard(place);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabsArea() {
    final List<String> categories = ['카페', '식당', '숙소', '유치원'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: categories.map((category) {
        final isSelected = _selectedCategory == category;
        return GestureDetector(
          onTap: () {
            _selectedCategory = category;
            fetchPlaces();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : Colors.black54)),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMapArea() {
    if (_currentLocation == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        child: const Center(child: Text("현재 위치를 불러오는 중...")),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition:
            NCameraPosition(target: _currentLocation!, zoom: 14),
            locationButtonEnable: true,
          ),
          onMapReady: (controller) {
            _mapController = controller;
            _updateMapMarkers();
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<SortOption>(
          onSelected: (result) {
            setState(() {
              _currentSort = result;
              _sortPlaces();
            });
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: SortOption.rating, child: Text("평점 순")),
            PopupMenuItem(value: SortOption.distance, child: Text("가까운 순")),
            PopupMenuItem(
                value: SortOption.longDistance, child: Text("긴거리 순")),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentSort == SortOption.rating
                    ? "평점 순"
                    : _currentSort == SortOption.distance
                    ? "가까운 순"
                    : "긴거리 순",
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const Icon(Icons.keyboard_arrow_down,
                  color: Colors.black87, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ 리스트 카드 + HospitalDetailPage 이동 (수정됨)
  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final distance = double.tryParse(place["distance"] ?? "0") ?? 0.0;
    final imageUrl = place["thumbnail"];

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
              latitude: double.tryParse(place["y"] ?? "0") ?? 0.0,
              longitude: double.tryParse(place["x"] ?? "0") ?? 0.0,
              currentLat: _currentLocation?.latitude ?? 0.0,
              currentLng: _currentLocation?.longitude ?? 0.0,

              /// ✅ 추가된 부분
              savedPlaces: _savedPlaces,
              onUpdateSavedPlaces: (updatedList) {
                setState(() {
                  _savedPlaces = updatedList;
                });
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? Image.network(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackImage(),
            )
                : _fallbackImage(),
          ),
          title: Text(
            place["place_name"] ?? "이름 없음",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              const Text("⭐ 4.9   ❤️ 재방문의사",
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                "${place["category_name"] ?? "카테고리"}  •  ${(distance / 1000).toStringAsFixed(1)} km",
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          trailing: const Icon(Icons.bookmark_border, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[300],
      child:
      const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}