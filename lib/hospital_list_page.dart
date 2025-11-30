import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'hospital_detail_page.dart';
import 'map_detail_page.dart';
import 'user_saved_places_page.dart'; // ✅ 즐겨찾기 페이지 import
import 'package:geolocator/geolocator.dart';

/// ✅ 정렬 옵션 (3가지)
enum SortOption { distance, longDistance, rating }

class HospitalListPage extends StatefulWidget {
  final String? category; // ✅ 카테고리 전달 받기 (예: 카페, 식당, 숙소, 유치원)
  const HospitalListPage({super.key, this.category});

  @override
  State<HospitalListPage> createState() => _HospitalListPageState();
}

class _HospitalListPageState extends State<HospitalListPage> {
  SortOption _currentSort = SortOption.rating;
  String _selectedCategory = '카페';
  late NaverMapController _mapController;

  // ✅ [수정] null 허용 변수로 선언 (초기값 없음)
  NLatLng? _currentLocation;

  // ✅ API 키
  final String kakaoApiKey = "bc6ab37a4ae28c4d0d8d2dbf8a3c8378";
  final String naverClientId = "pQH6nAMSamieCWngCpdQ";
  final String naverClientSecret = "YkaOM236tc";

  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _savedPlaces = [];
  bool _isLoading = true;

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
    _determinePositionAndFetchPlaces();
  }

  // ✅ [핵심 함수 1] 위치 확인 및 데이터 로드 (안전장치 강화)
  Future<void> _determinePositionAndFetchPlaces() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. 위치 서비스 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _useFallbackLocation(); // 서비스 꺼짐 -> 기본 위치 사용
      return;
    }

    // 2. 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _useFallbackLocation(); // 권한 거부 -> 기본 위치 사용
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _useFallbackLocation(); // 영구 거부 -> 기본 위치 사용
      return;
    }

    // 3. 진짜 내 위치 가져오기
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = NLatLng(position.latitude, position.longitude);
      });

      // 위치 잡은 후 데이터 가져오기
      await fetchPlaces();

    } catch (e) {
      // 위치 가져오다 에러나면 기본 위치
      _useFallbackLocation();
    }
  }

  // ✅ [보조 함수] 위치를 못 찾을 때 기본값(건대입구) 설정
  void _useFallbackLocation() {
    if (!mounted) return;
    setState(() {
      _currentLocation = const NLatLng(37.544583, 127.055897);
    });
    fetchPlaces();
  }

  // ✅ [핵심 함수 2] 장소 데이터 가져오기 (null 체크 추가)
  Future<void> fetchPlaces() async {
    // 위치가 없으면 로딩할 수 없음
    if (!mounted || _currentLocation == null) return;

    setState(() => _isLoading = true);

    final query = _petKeywords[_selectedCategory] ?? _selectedCategory;

    final url = Uri.parse(
      "https://dapi.kakao.com/v2/local/search/keyword.json"
          "?query=$query"
          "&x=${_currentLocation!.longitude}" // ! 붙여서 강제 언래핑 (위에서 null 체크 함)
          "&y=${_currentLocation!.latitude}"
          "&radius=5000"
          "&size=10",
    );

    try {
      final response = await http.get(url, headers: {"Authorization": "KakaoAK $kakaoApiKey"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data["documents"]);

        for (var place in results) {
          final imageUrl = await _fetchPlaceImageFromNaver(place["place_name"]);
          place["thumbnail"] = imageUrl;
          place["isSaved"] = _savedPlaces.any((saved) => saved["place_name"] == place["place_name"]);
        }

        if (mounted) {
          setState(() {
            _places = results;
            _isLoading = false;
          });
          _sortPlaces();
          // 지도가 준비된 상태라면 마커 업데이트 (컨트롤러가 null일 수 있으므로 try-catch 또는 체크 필요)
          try {
            _updateMapMarkers();
          } catch(e) {
            // 지도 컨트롤러가 아직 준비 안 됐으면 무시 (onMapReady에서 다시 불림)
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _fetchPlaceImageFromNaver(String placeName) async {
    try {
      final url = Uri.parse("https://openapi.naver.com/v1/search/image?query=$placeName&display=1&sort=sim");
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
    } catch (e) {
      // 이미지 로딩 실패 시 무시
    }
    return null;
  }

  void _sortPlaces() {
    if (_currentSort == SortOption.distance) {
      _places.sort((a, b) => double.parse(a["distance"] ?? "0").compareTo(double.parse(b["distance"] ?? "0")));
    } else if (_currentSort == SortOption.longDistance) {
      _places.sort((a, b) => double.parse(b["distance"] ?? "0").compareTo(double.parse(a["distance"] ?? "0")));
    }
  }

  void _toggleSave(Map<String, dynamic> place) {
    final exists = _savedPlaces.any((p) => p["place_name"] == place["place_name"]);
    setState(() {
      if (exists) {
        _savedPlaces.removeWhere((p) => p["place_name"] == place["place_name"]);
        place["isSaved"] = false;
      } else {
        place["isSaved"] = true;
        _savedPlaces.add(place);
      }
    });
  }

  void _changeCategory(String category) {
    setState(() => _selectedCategory = category);
    fetchPlaces();
  }

  Color _getMarkerColor(String category) {
    if (category.contains("카페")) return Colors.brown;
    if (category.contains("식당")) return Colors.red;
    if (category.contains("숙소")) return Colors.green;
    if (category.contains("유치원")) return Colors.orange;
    return Colors.purple;
  }

  void _updateMapMarkers() {
    // _currentLocation이 없거나 컨트롤러 초기화 전이면 실행 안 함
    if (_currentLocation == null) return;

    try {
      _mapController.clearOverlays();

      final myMarker = NMarker(
        id: "current_location",
        position: _currentLocation!,
        iconTintColor: Colors.blue,
      );
      _mapController.addOverlay(myMarker);

      for (var place in _places) {
        final lat = double.tryParse(place["y"] ?? "");
        final lng = double.tryParse(place["x"] ?? "");
        if (lat != null && lng != null) {
          final marker = NMarker(
            id: place["id"] ?? place["place_name"],
            position: NLatLng(lat, lng),
            iconTintColor: _getMarkerColor(place["category_name"] ?? ""),
          );
          _mapController.addOverlay(marker);
        }
      }
    } catch (e) {
      // 컨트롤러 관련 에러 방지
    }
  }

  // ✅ [핵심 함수 3] build 메서드 (위치가 없으면 로딩 화면 리턴)
  @override
  Widget build(BuildContext context) {
    // ⚠️ 위치 정보가 아직 없으면 로딩 화면을 보여줘서 에러 방지
    if (_currentLocation == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("현재 위치를 찾고 있습니다..."),
            ],
          ),
        ),
      );
    }

    // 위치 정보가 있을 때만 아래 화면을 그림
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          SizedBox(height: 250, child: _buildMapArea()),
          _buildSortArea(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _places.isEmpty
                ? const Center(child: Text("검색 결과 없음 😥"))
                : ListView.builder(
              itemCount: _places.length,
              itemBuilder: (context, index) {
                final place = _places[index];
                return FacilityCard(
                  name: place["place_name"],
                  category: place["category_name"] ?? "",
                  distance: double.tryParse(place["distance"] ?? "0") ?? 0.0,
                  imageUrl: place["thumbnail"],
                  isSaved: place["isSaved"] ?? false,
                  onSaveToggle: () => _toggleSave(place),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HospitalDetailPage(
                          name: place["place_name"] ?? "이름 없음",
                          category: place["category_name"] ?? "",
                          address: place["road_address_name"] ?? place["address_name"] ?? "주소 없음",
                          rating: 4.8,
                          phone: place["phone"] ?? "전화번호 없음",
                          url: place["place_url"] ?? "",
                          latitude: double.tryParse(place["y"] ?? "0") ?? 0.0,
                          longitude: double.tryParse(place["x"] ?? "0") ?? 0.0,
                          // ✅ null check 통과했으므로 ! 사용 가능
                          currentLat: _currentLocation!.latitude,
                          currentLng: _currentLocation!.longitude,
                          savedPlaces: _savedPlaces,
                          onUpdateSavedPlaces: (updatedList) {
                            setState(() {
                              _savedPlaces = updatedList;
                              for (var p in _places) {
                                p["isSaved"] = _savedPlaces.any((saved) => saved["place_name"] == p["place_name"]);
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // --- 아래는 UI 관련 함수들 (기존과 동일하지만 Context 접근을 위해 클래스 내부에 둠) ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 110,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("큐라펫", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.bookmark_border, color: Colors.black),
                onPressed: () async {
                  final updatedList = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserSavedPlacesPage(savedPlaces: _savedPlaces),
                    ),
                  );
                  if (updatedList != null && mounted) {
                    setState(() {
                      _savedPlaces = List<Map<String, dynamic>>.from(updatedList);
                      for (var place in _places) {
                        place["isSaved"] = _savedPlaces.any((saved) => saved["place_name"] == place["place_name"]);
                      }
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCategoryTabsArea(),
        ],
      ),
    );
  }

  Widget _buildCategoryTabsArea() {
    final List<String> categories = ['카페', '식당', '숙소', '유치원'];
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _changeCategory(category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : Colors.grey[300]!,
                    width: isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMapArea() {
    // build 초입에서 null 체크를 했으므로 여기서는 _currentLocation! 사용 가능
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MapDetailPage(
                hospitalName: "내 주변 지도",
                latitude: _currentLocation!.latitude,
                longitude: _currentLocation!.longitude,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(target: _currentLocation!, zoom: 15),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _updateMapMarkers();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSortArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<SortOption>(
            onSelected: (result) {
              setState(() {
                _currentSort = result;
                _sortPlaces();
              });
              _updateMapMarkers();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: SortOption.rating, child: Text("평점 순")),
              PopupMenuItem(value: SortOption.distance, child: Text("가까운 순")),
              PopupMenuItem(value: SortOption.longDistance, child: Text("긴거리 순")),
            ],
            child: Row(
              children: [
                Text(
                  _currentSort == SortOption.rating ? "평점 순" : _currentSort == SortOption.distance ? "가까운 순" : "긴거리 순",
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.black87, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      currentIndex: 2,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'AI 챗봇'),
        BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined), label: '내 병원'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
      ],
    );
  }
}
/// ✅ 카드 UI (북마크 클릭 기능 포함, 디자인 개선)
class FacilityCard extends StatelessWidget {
  final String name;
  final String category;
  final double distance;
  final String? imageUrl;
  final bool isSaved;
  final VoidCallback onSaveToggle;
  final VoidCallback onTap;

  const FacilityCard({
    super.key,
    required this.name,
    required this.category,
    required this.distance,
    this.imageUrl,
    required this.isSaved,
    required this.onSaveToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: Colors.white,
        shadowColor: Colors.grey.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ✅ 썸네일
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

              /// ✅ 텍스트 + 아이콘 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ✅ 상단 : 병원명 + 북마크
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: onSaveToggle,
                          child: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: isSaved ? Colors.orangeAccent : Colors.grey,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    /// ✅ 평점 라인
                    Row(
                      children: const [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "4.8  ❤️ 재방문의사",
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    /// ✅ 카테고리 + 거리
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
