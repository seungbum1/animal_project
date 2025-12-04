// hospital_list_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import 'map_detail_page.dart';
import 'hospital_detail_page.dart';
import 'user_saved_places_page.dart';
import 'place.dart';

// ... (색상 상수 및 Place 클래스 등은 기존 유지) ...
const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);
const Color kBlueColor = Color(0xFF547AA5);
const Color kGreenColor = Color(0xFF6A994E);
const Color kYellowColor = Color(0xFFE9C46A);

enum SortOption { distance, longDistance, rating }

class HospitalListPage extends StatefulWidget {
  final String? category;
  final String? token; // ✅ 1. 토큰 변수 추가

  // ✅ 2. 생성자 수정
  const HospitalListPage({
    super.key,
    this.category,
    required this.token // 필수 인자로 받거나 optional로 설정
  });

  @override
  State<HospitalListPage> createState() => _HospitalListPageState();
}

class _HospitalListPageState extends State<HospitalListPage> with SingleTickerProviderStateMixin {
  SortOption _currentSort = SortOption.rating;
  String _selectedCategory = '카페';
  late NaverMapController _mapController;
  NLatLng? _currentLocation;
  bool _isMapMoved = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  Map<String, dynamic>? _selectedPlace;

  final String kakaoApiKey = "bc6ab37a4ae28c4d0d8d2dbf8a3c8378";
  final String naverClientId = "pQH6nAMSamieCWngCpdQ";
  final String naverClientSecret = "YkaOM236tc";

  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _savedPlaces = []; // 화면 표시용
  bool _isLoading = true;

  final Map<String, String> _petKeywords = {
    "카페": "애견카페", "식당": "애견식당", "숙소": "펫호텔", "유치원": "애견유치원", "병원": "동물병원",
  };

  @override
  void initState() {
    super.initState();
    if (widget.category != null && widget.category!.isNotEmpty) {
      _selectedCategory = widget.category!;
    }
    _loadAllData();
  }

  // ... (위치 권한 및 초기 로딩 코드는 기존과 동일) ...

  Future<void> _loadAllData() async {
    print("🔄 데이터 로딩 시작...");

    // ✅ 3. 매니저에게 토큰 전달 (place.dart 수정 필요, 아래 참고)
    // 토큰이 없으면 빈 문자열 '' 전달하여 에러 방지
    await SavedPlacesManager.loadFromServer(widget.token ?? '');

    if (mounted) {
      setState(() {
        _savedPlaces = List.from(SavedPlacesManager.places);
      });
      print("✅ 보관함 동기화 완료: ${_savedPlaces.length}개");
    }

    await _determinePositionAndFetchPlaces();
  }

  Future<void> _determinePositionAndFetchPlaces() async {
    // ... (위치 권한 확인 로직은 기존과 동일) ...
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { _useFallbackLocation(); return; }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) { _useFallbackLocation(); return; }
    }
    if (permission == LocationPermission.deniedForever) { _useFallbackLocation(); return; }

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _currentLocation = NLatLng(position.latitude, position.longitude));

      // 위치 찾았으니 장소 검색
      await fetchPlaces();
    } catch (e) {
      _useFallbackLocation();
    }
  }

  void _useFallbackLocation() {
    if (!mounted) return;
    setState(() => _currentLocation = const NLatLng(37.544583, 127.055897));
    fetchPlaces();
  }

  /// ✅ 장소 데이터 가져오기 (지도 중심 좌표 기준)
  Future<void> fetchPlaces() async {
    if (!mounted || _currentLocation == null) return;
    setState(() {
      _isLoading = true;
      _isMapMoved = false;
    });

    final query = _petKeywords[_selectedCategory] ?? _selectedCategory;
    final url = Uri.parse(
      "https://dapi.kakao.com/v2/local/search/keyword.json?query=$query&x=${_currentLocation!.longitude}&y=${_currentLocation!.latitude}&radius=5000&size=15",
    );

    try {
      final response = await http.get(url, headers: {"Authorization": "KakaoAK $kakaoApiKey"});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data["documents"]);

        // (네이버 이미지 등 추가 정보 로딩)
        await Future.wait(results.map((place) async {
          place["thumbnail"] = await _fetchPlaceImageFromNaver(place["place_name"]);

          // ✨ [핵심 수정] 가져온 장소가 '매니저(서버데이터)'에 있는지 확인해서 isSaved 세팅
          place["isSaved"] = SavedPlacesManager.isSaved(place["place_name"]);
        }));

        if (mounted) {
          setState(() {
            _places = results;
            _isLoading = false;
            _selectedPlace = null;
          });
          _sortPlaces();
          _updateMapMarkers();
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
        "X-Naver-Client-Id": naverClientId, "X-Naver-Client-Secret": naverClientSecret,
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["items"] != null && data["items"].isNotEmpty) return data["items"][0]["link"];
      }
    } catch (e) {}
    return null;
  }

  void _sortPlaces() {
    if (_currentSort == SortOption.distance) {
      _places.sort((a, b) => double.parse(a["distance"] ?? "0").compareTo(double.parse(b["distance"] ?? "0")));
    } else if (_currentSort == SortOption.longDistance) {
      _places.sort((a, b) => double.parse(b["distance"] ?? "0").compareTo(double.parse(a["distance"] ?? "0")));
    }
  }

  void _toggleSave(Map<String, dynamic> place) async {
    HapticFeedback.mediumImpact();

    // ✅ 4. 저장/삭제 요청 시에도 토큰 전달
    bool isNowSaved = await SavedPlacesManager.toggleServer(place, widget.token ?? '');

    if (mounted) {
      setState(() {
        place["isSaved"] = isNowSaved;
        _savedPlaces = List.from(SavedPlacesManager.places);
      });
    }
  }

  void _changeCategory(String category) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
    fetchPlaces(); // 카테고리 바꾸면 현재 위치에서 재검색
  }

  Color _getMarkerColor(String category) {
    if (category.contains("카페") || category.contains("식당")) return kYellowColor;
    if (category.contains("숙소")) return kPrimaryColor;
    if (category.contains("유치원")) return kGreenColor;
    return kBlueColor;
  }

  /// ✅ [UX Upgrade] 마커 클릭 시 카메라 이동 + 카드 표시
  void _onMarkerTapped(Map<String, dynamic> place) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedPlace = place;
    });

    final lat = double.tryParse(place["y"] ?? "");
    final lng = double.tryParse(place["x"] ?? "");

    if (lat != null && lng != null) {
      // ✨ 마커가 카드에 가리지 않게 살짝 위로 이동 (센터 조정)
      final targetLat = lat - 0.002; // 위도 조정값 (상황에 따라 조절)

      _mapController.updateCamera(NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(lat, lng), // 마커 위치로 이동
        zoom: 16,
      ));
    }
  }

  void _onMapTapped() {
    if (_selectedPlace != null) {
      setState(() {
        _selectedPlace = null;
      });
    }
  }

  void _updateMapMarkers() {
    if (_currentLocation == null) return;
    try {
      _mapController.clearOverlays();
      // (내 위치 마커 등 기존 로직 유지)

      for (var place in _places) {
        final lat = double.tryParse(place["y"] ?? "");
        final lng = double.tryParse(place["x"] ?? "");
        if (lat != null && lng != null) {
          final id = place["id"] ?? place["place_name"];
          final marker = NMarker(
            id: id,
            position: NLatLng(lat, lng),
            iconTintColor: _getMarkerColor(place["category_name"] ?? ""),
            caption: NOverlayCaption(text: place["place_name"], textSize: 10, color: kOnSurfaceColor),
          );
          marker.setOnTapListener((overlay) => _onMarkerTapped(place));
          _mapController.addOverlay(marker);
        }
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1️⃣ [지하 1층] 지도 레이어
          _buildMapLayer(),

          // 2️⃣ [지상 1층] 카테고리 바 (리스트 아래에 깔림)
          // 리스트를 올리면 자연스럽게 가려집니다.
          if (_selectedPlace == null)
            _buildFloatingCategoryBar(),

          // 3️⃣ [지상 2층] 리스트 시트 OR 장소 카드
          // 카테고리 바 위를 덮습니다.
          if (_selectedPlace != null)
            _buildSelectedPlaceCard()
          else
            _buildDraggableSheet(),

          // 4️⃣ [지상 3층] 재검색 버튼 (리스트 위에 뜸)
          // 이제 리스트가 있어도 버튼은 그 위에 둥둥 떠있게 됩니다.
          if (_isMapMoved && _selectedPlace == null)
            _buildReSearchButton(),

          // 5️⃣ [옥상] 상단 네비게이션 바 (무조건 최상단)
          if (_selectedPlace == null) ...[
            _buildFloatingTopBar(),
          ],
        ],
      ),
    );
  }

  /// ✅ 지도 레이어 + 카메라 움직임 감지
  Widget _buildMapLayer() {
    if (_currentLocation == null) {
      return Container(color: kBackgroundColor, child: const Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    }
    return Positioned.fill(
      child: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(target: _currentLocation!, zoom: 15),
          contentPadding: const EdgeInsets.only(bottom: 150),
          locationButtonEnable: true,
          logoClickEnable: false,
        ),
        onMapReady: (controller) => _mapController = controller,
        onMapTapped: (point, latLng) => _onMapTapped(),

        // ✨ [핵심 기능] 카메라가 움직이면 재검색 버튼 활성화
        onCameraChange: (reason, animated) {
          // 제스처(손가락)로 움직였을 때만 버튼 표시
          if (reason == NCameraUpdateReason.gesture) {
            if (!_isMapMoved) setState(() => _isMapMoved = true);

            // 현재 보고 있는 중심 좌표 업데이트
            final target = _mapController.nowCameraPosition.target;
            _currentLocation = target;
          }
        },
      ),
    );
  }

  /// ✨ [NEW] 재검색 버튼 위젯 (애니메이션 포함)
  Widget _buildReSearchButton() {
    return Positioned(
      // 💡 베테랑의 디테일:
      // 하단 DraggableSheet의 최소 높이(minChildSize)가 있으므로,
      // 그 위로 살짝 올라오게 bottom 값을 110 정도로 설정합니다.
      bottom: 110,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut, // 쫀득한 등장 효과
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              fetchPlaces(); // 현재 중심 좌표로 검색 다시 실행
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: kPrimaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "이 지역에서 재검색",
                    style: TextStyle(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w800, // 폰트 두께 살짝 강화
                        fontSize: 14
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ... (나머지 _buildFloatingTopBar, _buildFloatingCategoryBar, _buildSelectedPlaceCard, _buildDraggableSheet 코드는 기존과 동일하므로 유지) ...

  Widget _buildFloatingTopBar() {
    // (기존 코드 그대로)
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16, right: 16,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            if (Navigator.canPop(context))
              IconButton(icon: const Icon(Icons.arrow_back, color: kOnSurfaceColor), onPressed: () => Navigator.pop(context))
            else const SizedBox(width: 20),
            Expanded(
              child: Text(_selectedCategory, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kOnSurfaceColor), textAlign: TextAlign.center),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, color: kOnSurfaceColor),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MapDetailPage(
                  hospitalName: "$_selectedCategory 지도",
                  latitude: _currentLocation?.latitude ?? 37.544583,
                  longitude: _currentLocation?.longitude ?? 127.055897,
                  token: widget.token,
                )));
              },
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_rounded, color: kPrimaryColor),
              onPressed: () async {
                final updatedList = await Navigator.push(context, MaterialPageRoute(builder: (_) => UserSavedPlacesPage(savedPlaces: _savedPlaces,token: widget.token,)));
                if (updatedList != null && mounted) {
                  setState(() { _savedPlaces = List<Map<String, dynamic>>.from(updatedList); _updateMapMarkers(); });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCategoryBar() {
    // (기존 코드 그대로)
    final categories = ['카페', '식당', '숙소', '유치원', '병원'];
    return Positioned(
      top: MediaQuery.of(context).padding.top + 75,
      left: 0, right: 0,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () => _changeCategory(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? kPrimaryColor : Colors.white),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Center(
                  child: Text(category, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ 선택된 장소 카드 (기존 코드 유지)
  Widget _buildSelectedPlaceCard() {
    if (_selectedPlace == null) return const SizedBox.shrink();
    final place = _selectedPlace!;

    return Positioned(
      bottom: 30, left: 0, right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          children: [
            FacilityCard(
              name: place["place_name"],
              category: place["category_name"] ?? "",
              distance: double.tryParse(place["distance"] ?? "0") ?? 0.0,
              imageUrl: place["thumbnail"],
              isSaved: place["isSaved"] ?? false,
              address: place["road_address_name"] ?? place["address_name"] ?? "",
              onSaveToggle: () => _toggleSave(place),
              onTap: () => _navigateToDetail(place),
            ),
            Positioned(
              top: 0, right: 0,
              child: GestureDetector(
                onTap: () => setState(() => _selectedPlace = null),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 드래거블 시트 (기존 코드 유지)
  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.9,
      snap: true, snapSizes: const [0.4],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: kBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: CustomScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverAppBar(
                  pinned: true, elevation: 0, backgroundColor: kBackgroundColor, toolbarHeight: 70, automaticallyImplyLeading: false, titleSpacing: 0,
                  title: Column(
                    children: [
                      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("주변 ${_places.length}곳 발견", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kOnSurfaceColor)),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<SortOption>(
                                value: _currentSort,
                                icon: const Icon(Icons.sort, size: 18, color: Colors.grey),
                                style: const TextStyle(fontSize: 13, color: kOnSurfaceColor),
                                isDense: true, dropdownColor: Colors.white,
                                onChanged: (newValue) { if (newValue != null) setState(() { _currentSort = newValue; _sortPlaces(); }); },
                                items: const [DropdownMenuItem(value: SortOption.rating, child: Text("평점순")), DropdownMenuItem(value: SortOption.distance, child: Text("거리순"))],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: kSecondaryColor, height: 1)),
                ),
                _isLoading
                    ? SliverList(delegate: SliverChildBuilderDelegate((context, index) => const SkeletonFacilityCard(), childCount: 5))
                    : _places.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final place = _places[index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FacilityCard(
                          name: place["place_name"],
                          category: place["category_name"] ?? "",
                          distance: double.tryParse(place["distance"] ?? "0") ?? 0.0,
                          imageUrl: place["thumbnail"],
                          isSaved: place["isSaved"] ?? false,
                          address: place["road_address_name"] ?? place["address_name"] ?? "",
                          onSaveToggle: () => _toggleSave(place),
                          onTap: () => _navigateToDetail(place),
                        ),
                      );
                    },
                    childCount: _places.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    // (기존 코드 그대로)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text("이 근처에는 장소가 없네요.", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> place) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HospitalDetailPage(
          // ✅ 5. 상세 페이지로 이동할 때 토큰 넘겨주기
          token: widget.token,

          name: place["place_name"] ?? "",
          category: place["category_name"] ?? "",
          address: place["road_address_name"] ?? place["address_name"] ?? "",
          rating: 4.8,
          phone: place["phone"] ?? "",
          url: place["place_url"] ?? "",
          latitude: double.tryParse(place["y"] ?? "0") ?? 0.0,
          longitude: double.tryParse(place["x"] ?? "0") ?? 0.0,
          currentLat: _currentLocation!.latitude,
          currentLng: _currentLocation!.longitude,
        ),
      ),
    );

    // ✨ [수정] 상세페이지에서 돌아오면 다시 최신 상태로 갱신
    if (mounted) {
      setState(() {
        _savedPlaces = List.from(SavedPlacesManager.places);
        // 리스트에 있는 장소들의 하트 상태 다시 체크
        for (var p in _places) {
          p["isSaved"] = SavedPlacesManager.isSaved(p["place_name"]);
        }
      });
    }
  }
}

class FacilityCard extends StatelessWidget {
  final String name;
  final String category;
  final String address;
  final double distance;
  final String? imageUrl;
  final bool isSaved;
  final VoidCallback onSaveToggle;
  final VoidCallback onTap;

  const FacilityCard({
    super.key, required this.name, required this.category, required this.address, required this.distance,
    this.imageUrl, required this.isSaved, required this.onSaveToggle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✨ [핵심 수정] 거리 텍스트 포맷팅 (1km 미만은 m, 이상은 km)
    String distanceText;
    if (distance <= 0) {
      distanceText = "-";
    } else if (distance < 1000) {
      distanceText = "${distance.toInt()}m"; // 예: 164m
    } else {
      distanceText = "${(distance / 1000).toStringAsFixed(1)}km"; // 예: 1.2km
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Hero(
              tag: name,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80, height: 80, color: Colors.grey[100],
                  child: imageUrl != null
                      ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => _fallbackIcon())
                      : _fallbackIcon(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kOnSurfaceColor))),
                      GestureDetector(onTap: onSaveToggle, child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border_rounded, color: isSaved ? kPrimaryColor : Colors.grey[300], size: 24)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(category, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: kYellowColor, size: 16),
                      const SizedBox(width: 2),
                      const Text("4.8", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: kBlueColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        // ✨ 수정된 변수(distanceText) 사용
                        child: Text(distanceText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kBlueColor)),
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
  Widget _fallbackIcon() => Center(child: Icon(Icons.storefront_rounded, color: Colors.grey[300], size: 30));
}

class SkeletonFacilityCard extends StatefulWidget {
  // (기존 코드 그대로)
  const SkeletonFacilityCard({super.key});
  @override
  State<SkeletonFacilityCard> createState() => _SkeletonFacilityCardState();
}

class _SkeletonFacilityCardState extends State<SkeletonFacilityCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _colorAnimation = ColorTween(begin: Colors.grey[200], end: Colors.grey[50]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), // 간격 조정
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: _colorAnimation.value, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 16, decoration: BoxDecoration(color: _colorAnimation.value, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 12, decoration: BoxDecoration(color: _colorAnimation.value, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 200, height: 12, decoration: BoxDecoration(color: _colorAnimation.value, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}