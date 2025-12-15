import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'hospital_detail_page.dart';
import 'route_finding_page.dart';

// 🎨 Pro Color Palette (HospitalDetail과 통일)
const Color kPrimaryColor = Color(0xFFC06362);
const Color kPrimaryLight = Color(0xFFFDECEC);
const Color kTextBlack = Color(0xFF222222);
const Color kTextGrey = Color(0xFF888888);
const Color kSurfaceWhite = Colors.white;
const Color kBackgroundColor = Color(0xFFF9F9F9);

class MapDetailPage extends StatefulWidget {
  final String hospitalName;
  final double latitude;
  final double longitude;
  final String? token;

  const MapDetailPage({
    super.key,
    required this.hospitalName,
    required this.latitude,
    required this.longitude,
    required this.token,
  });

  @override
  State<MapDetailPage> createState() => _MapDetailPageState();
}

class _MapDetailPageState extends State<MapDetailPage> with TickerProviderStateMixin {
  late NaverMapController _mapController;
  final TextEditingController _searchController = TextEditingController();

  // ⚡ 베테랑의 기술: 디바운싱 타이머
  Timer? _debounce;

  // 상태 관리
  String _selectedCategory = "카페";
  bool _isCustomSearch = false;

  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _suggestions = [];

  Map<String, dynamic>? _selectedPlace;
  bool _isLoading = false;
  bool _showSuggestions = false;

  final String kakaoApiKey = "bc6ab37a4ae28c4d0d8d2dbf8a3c8378";
  final String naverClientId = "pQH6nAMSamieCWngCpdQ";
  final String naverClientSecret = "YkaOM236tc";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch("애견카페", updateMap: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final url = Uri.parse(
      "https://dapi.kakao.com/v2/local/search/keyword.json?query=$query&x=${widget.longitude}&y=${widget.latitude}&radius=10000&size=10",
    );
    try {
      final response = await http.get(url, headers: {"Authorization": "KakaoAK $kakaoApiKey"});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _suggestions = List<Map<String, dynamic>>.from(data["documents"]);
            _showSuggestions = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _performSearch(String query, {bool updateMap = false, bool openList = false, int radius = 5000}) async {
    if (!mounted) return;
    if (updateMap) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isLoading = true;
        _showSuggestions = false;
      });
    }

    String finalQuery = query;
    if (!_isCustomSearch) {
      finalQuery = {
        "카페": "애견카페", "식당": "애견식당", "숙소": "펫호텔", "유치원": "애견유치원",
      }[query] ?? query;
    }

    final url = Uri.parse(
      "https://dapi.kakao.com/v2/local/search/keyword.json?query=$finalQuery&x=${widget.longitude}&y=${widget.latitude}&radius=$radius&size=15",
    );

    try {
      final response = await http.get(url, headers: {"Authorization": "KakaoAK $kakaoApiKey"});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data["documents"]);

        await Future.wait(results.map((place) async {
          try {
            place["thumbnail"] = await _fetchPlaceImageFromNaver(place["place_name"]);
          } catch (_) {
            place["thumbnail"] = null;
          }
        }));

        if (mounted) {
          setState(() {
            _places = results;
            if (updateMap) _selectedPlace = null;
            _isLoading = false;
          });

          if (updateMap) _updateMarkers();

          if (openList) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _showPlaceList(context);
            });
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
        if (data["items"] != null && data["items"].isNotEmpty) return data["items"][0]["link"];
      }
    } catch (_) {}
    return null;
  }

  void _updateMarkers() {
    _mapController.clearOverlays();
    // 중심 마커 (내 위치)
    final centerMarker = NMarker(
      id: "center_marker",
      position: NLatLng(widget.latitude, widget.longitude),
      iconTintColor: kPrimaryColor,
      size: const Size(35, 45),
    );
    _mapController.addOverlay(centerMarker);

    for (var place in _places) {
      final lat = double.tryParse(place["y"] ?? "");
      final lng = double.tryParse(place["x"] ?? "");
      if (lat != null && lng != null) {
        final isSelected = _selectedPlace == place;
        final marker = NMarker(
          id: place["id"] ?? place["place_name"],
          position: NLatLng(lat, lng),
          iconTintColor: isSelected ? kPrimaryColor : const Color(0xFF5A96FA),
          caption: NOverlayCaption(text: place["place_name"], textSize: 12, minZoom: 14),
        );
        marker.setOnTapListener((overlay) => _onMarkerTapped(place, lat, lng));
        _mapController.addOverlay(marker);
      }
    }
  }

  void _onSuggestionSelected(Map<String, dynamic> place) async {
    FocusScope.of(context).unfocus();
    _searchController.text = place["place_name"];
    place["thumbnail"] = await _fetchPlaceImageFromNaver(place["place_name"]);

    setState(() {
      _showSuggestions = false;
      _places = [place];
      _selectedPlace = place;
    });
    _updateMarkers();

    final lat = double.parse(place["y"]);
    final lng = double.parse(place["x"]);
    _moveCamera(lat, lng);
  }

  void _onMarkerTapped(Map<String, dynamic> place, double lat, double lng) {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() => _selectedPlace = place);
    _moveCamera(lat, lng);
  }

  void _moveCamera(double lat, double lng) {
    final cameraUpdate = NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lng), zoom: 16);
    cameraUpdate.setPivot(const NPoint(0.5, 0.65)); // 하단 카드 공간 확보
    cameraUpdate.setAnimation(animation: NCameraAnimation.fly, duration: const Duration(milliseconds: 600));
    _mapController.updateCamera(cameraUpdate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Map Layer
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(target: NLatLng(widget.latitude, widget.longitude), zoom: 14),
              locationButtonEnable: false,
              logoClickEnable: false,
              consumeSymbolTapEvents: false,
              contentPadding: const EdgeInsets.only(bottom: 20),
            ),
            onMapReady: (c) => _mapController = c,
            onMapTapped: (p, l) {
              FocusScope.of(context).unfocus();
              setState(() => _showSuggestions = false);
              if (_selectedPlace != null) setState(() => _selectedPlace = null);
            },
          ),

          // 2. Immersive Search Bar (Glassmorphism)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16, right: 16,
            child: Column(
              children: [
                _buildGlassSearchBar(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  child: _showSuggestions && _suggestions.isNotEmpty
                      ? _buildSuggestionList()
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // 3. Category Chips
          if (!_showSuggestions)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0, right: 0,
              child: _buildCategoryBar(),
            ),

          // 4. Loading
          if (_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 140,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2.5)),
                ),
              ),
            ),

          // 5. Bottom Place Card (Floating Island Style)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            left: 16, right: 16,
            bottom: _selectedPlace != null ? 34 : -350,
            child: _selectedPlace != null ? _buildSelectedPlaceCard() : const SizedBox.shrink(),
          ),

          // 6. Bottom Controls (List & Location)
          if (_selectedPlace == null && !_showSuggestions)
            Positioned(
              bottom: 34, left: 0, right: 0,
              child: _buildFloatingControls(),
            ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildGlassSearchBar() {
    return ClipRRect(
      borderRadius: _showSuggestions && _suggestions.isNotEmpty
          ? const BorderRadius.vertical(top: Radius.circular(20))
          : BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9), // 살짝 투명
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextBlack, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kTextBlack),
                  decoration: const InputDecoration(
                    hintText: "장소, 주소 검색 (예: 스타벅스)",
                    hintStyle: TextStyle(color: kTextGrey, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      setState(() { _isCustomSearch = true; _selectedCategory = ""; });
                      _performSearch(value, updateMap: true, openList: true);
                    }
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: kTextGrey, size: 20),
                  onPressed: () { _searchController.clear(); _onSearchChanged(""); },
                )
              else
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: kPrimaryColor, size: 24),
                  onPressed: () {
                    if (_searchController.text.trim().isNotEmpty) {
                      setState(() { _isCustomSearch = true; _selectedCategory = ""; });
                      _performSearch(_searchController.text, updateMap: true, openList: true);
                    }
                  },
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
        itemBuilder: (context, index) {
          final place = _suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined, size: 20, color: kTextGrey),
            title: Text(place["place_name"], style: const TextStyle(fontWeight: FontWeight.w600, color: kTextBlack)),
            subtitle: Text(place["road_address_name"] ?? place["address_name"] ?? "", style: const TextStyle(fontSize: 12, color: kTextGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _onSuggestionSelected(place),
          );
        },
      ),
    );
  }

  Widget _buildCategoryBar() {
    final categories = ["카페", "식당", "숙소", "유치원"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((category) {
          final isSelected = !_isCustomSearch && _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
                setState(() { _isCustomSearch = false; _selectedCategory = category; });
                _performSearch(category, updateMap: true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isSelected ? Colors.transparent : Colors.black.withOpacity(0.05)),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                    else
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_getCategoryIcon(category), size: 16, color: isSelected ? Colors.white : kTextGrey),
                    const SizedBox(width: 6),
                    Text(category, style: TextStyle(color: isSelected ? Colors.white : kTextBlack, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedPlaceCard() {
    final place = _selectedPlace!;
    final distance = double.tryParse(place["distance"] ?? "0") ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          InkWell(
            onTap: () => _navigateToDetail(place),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Hero(
                    tag: place["place_name"],
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[100],
                        image: place["thumbnail"] != null ? DecorationImage(image: NetworkImage(place["thumbnail"]), fit: BoxFit.cover) : null,
                      ),
                      child: place["thumbnail"] == null ? const Icon(Icons.storefront_rounded, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place["place_name"], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextBlack), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(place["category_name"] ?? "", style: const TextStyle(fontSize: 13, color: kTextGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 2),
                            const Text("4.9", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                              child: Text(distance > 0 ? "${(distance / 1000).toStringAsFixed(1)}km" : "근처", style: const TextStyle(fontSize: 11, color: kPrimaryColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: kTextGrey),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 22),
                label: const Text("길찾기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTextBlack,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RouteFindingPage(
                    destinationName: place["place_name"],
                    destinationLat: double.parse(place["y"] ?? "0"),
                    destinationLng: double.parse(place["x"] ?? "0"),
                    originLat: widget.latitude,
                    originLng: widget.longitude,
                  )));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 16),
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: kTextBlack,
              elevation: 4,
              onPressed: () {
                final cameraUpdate = NCameraUpdate.withParams(target: NLatLng(widget.latitude, widget.longitude), zoom: 15);
                _mapController.updateCamera(cameraUpdate);
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () => _showPlaceList(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_list_bulleted_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text("목록 보기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "카페": return Icons.coffee_rounded;
      case "식당": return Icons.restaurant_rounded;
      case "숙소": return Icons.bed_rounded;
      case "유치원": return Icons.pets_rounded;
      default: return Icons.place_rounded;
    }
  }

  void _navigateToDetail(Map<String, dynamic> place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalDetailPage(
          token: widget.token,
          name: place["place_name"],
          category: place["category_name"] ?? "",
          address: place["road_address_name"] ?? place["address_name"] ?? "주소 없음",
          rating: 4.9,
          phone: place["phone"] ?? "전화번호 없음",
          url: place["place_url"] ?? "",
          latitude: double.tryParse(place["y"] ?? "0") ?? 0,
          longitude: double.tryParse(place["x"] ?? "0") ?? 0,
          currentLat: widget.latitude,
          currentLng: widget.longitude,
        ),
      ),
    );
  }

  void _showPlaceList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DraggableListSheet(
        places: _places,
        category: _isCustomSearch ? "검색 결과" : _selectedCategory,
        onTapPlace: _navigateToDetail,
        onRetry: () {
          Navigator.pop(context);
          _performSearch(_isCustomSearch ? _searchController.text : _selectedCategory, updateMap: true, radius: 10000);
        },
      ),
    );
  }
}

// 📜 List Sheet Component
class _DraggableListSheet extends StatelessWidget {
  final List<Map<String, dynamic>> places;
  final String category;
  final Function(Map<String, dynamic>) onTapPlace;
  final VoidCallback onRetry;

  const _DraggableListSheet({required this.places, required this.category, required this.onTapPlace, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("주변 $category", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: kTextBlack)),
                    Text("${places.length}곳", style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: places.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: places.length,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return _PlaceListItem(place: place, onTap: () => onTapPlace(place));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: const Icon(Icons.pets_rounded, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Text("이 근처에는 결과가 없어요 😢", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextBlack)),
            const SizedBox(height: 8),
            const Text("검색 범위를 조금 더 넓혀보거나\n다른 검색어로 찾아볼까요?", textAlign: TextAlign.center, style: TextStyle(color: kTextGrey, fontSize: 14, height: 1.5)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text("검색 범위 넓혀서 다시 찾기 (+10km)"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kPrimaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onRetry,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("장소 제보하기"),
                    content: const Text("알고 계신 반려동물 동반 장소가 있나요?\n다음에 업데이트 해드릴게요!"),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기"))],
                  ),
                );
              },
              child: const Text("내가 아는 장소 제보하기 >", style: TextStyle(color: kTextGrey, fontSize: 13, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceListItem extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback onTap;

  const _PlaceListItem({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final distance = double.tryParse(place["distance"] ?? "0") ?? 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Hero(
              tag: place["place_name"],
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 72, height: 72,
                  color: Colors.grey[100],
                  child: place["thumbnail"] != null
                      ? Image.network(place["thumbnail"], fit: BoxFit.cover)
                      : const Icon(Icons.storefront_rounded, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place["place_name"], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextBlack), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(place["category_name"] ?? "", style: const TextStyle(fontSize: 13, color: kTextGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: kPrimaryColor),
                      const SizedBox(width: 2),
                      Text(distance > 0 ? "${(distance / 1000).toStringAsFixed(1)}km" : "가까움", style: const TextStyle(fontSize: 12, color: kTextBlack, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFE0E0E0)),
          ],
        ),
      ),
    );
  }
}