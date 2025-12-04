import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui'; // UI 필터용
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'user_transit_detail_page.dart';

// 🎨 Pro Color Palette
const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kSurfaceWhite = Colors.white;
const Color kTextBlack = Color(0xFF222222);
const Color kTextGrey = Color(0xFF888888);
const Color kSecondaryColor = Color(0xFFE0E0E0);

// 길찾기 전용 컬러
const Color kBusBlue = Color(0xFF547AA5);
const Color kSubwayGreen = Color(0xFF6A994E);
const Color kWalkGreen = Color(0xFF4CAF50);
const Color kCarTeal = Color(0xFF2A9D8F);

class RouteFindingPage extends StatefulWidget {
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final double originLat;
  final double originLng;

  const RouteFindingPage({
    super.key,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.originLat,
    required this.originLng,
  });

  @override
  State<RouteFindingPage> createState() => _RouteFindingPageState();
}

class _RouteFindingPageState extends State<RouteFindingPage> with SingleTickerProviderStateMixin {
  late TabController _transitTabController;
  bool _isLoading = true;
  bool _isTooCloseForTransit = false;
  double _directDistance = 0.0;

  Map<String, dynamic>? _routeData;
  String _selectedMode = "transit"; // transit, car, walk

  final String kakaoApiKey = "bc6ab37a4ae28c4d0d8d2dbf8a3c8378";
  final String tmapApiKey = "Om0qwEOnhl67NmhPKlHTV2IUu8FQrEsG9lHcdU3Y";

  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _transitTabController = TabController(length: 4, vsync: this);
    _calculateDirectDistance();
    _fetchRoute();
  }

  void _calculateDirectDistance() {
    const R = 6371e3;
    final lat1 = widget.originLat * math.pi / 180;
    final lat2 = widget.destinationLat * math.pi / 180;
    final dLat = (widget.destinationLat - widget.originLat) * math.pi / 180;
    final dLon = (widget.destinationLng - widget.originLng) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    _directDistance = R * c;
  }

  /// ✨ [NEW] 대중교통 실패 시 도보로 자동 전환하는 함수
  void _switchToWalkFallback() {
    if (!mounted) return;

    // 안내 메시지
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("대중교통 경로가 없어 도보 경로로 안내합니다. 🚶"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kTextBlack,
        duration: Duration(seconds: 2),
      ),
    );

    // 모드 변경 및 재검색
    setState(() {
      _selectedMode = "walk";
      _routeData = null;
    });
    _fetchRoute(); // 도보 모드로 다시 호출
  }

  /// 🚀 Data Fetching Logic
  Future<void> _fetchRoute() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isTooCloseForTransit = false;
    });

    if (_selectedMode == "transit" && _directDistance < 300) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isTooCloseForTransit = true;
        });
      }
      return;
    }

    Uri url;
    http.Response response;

    try {
      if (_selectedMode == "transit") {
        url = Uri.parse("https://apis.openapi.sk.com/transit/routes");
        final body = jsonEncode({
          "startX": widget.originLng,
          "startY": widget.originLat,
          "endX": widget.destinationLng,
          "endY": widget.destinationLat,
          "count": 5,
          "lang": 0,
          "format": "json"
        });

        response = await http.post(url, headers: {
          "accept": "application/json",
          "content-type": "application/json",
          "appKey": tmapApiKey,
        }, body: body);

        // ✨ [핵심 로직] 대중교통 응답 확인
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // 경로가 비어있거나 에러인 경우 체크
          if (data['metaData']?['plan']?['itineraries'] == null) {
            _switchToWalkFallback(); // 도보로 전환!
            return; // 여기서 종료
          }
        } else {
          // API 호출 실패 시에도 도보로 전환
          _switchToWalkFallback();
          return;
        }

      } else if (_selectedMode == "car") {
        url = Uri.parse(
          "https://apis-navi.kakaomobility.com/v1/directions?origin=${widget.originLng},${widget.originLat}&destination=${widget.destinationLng},${widget.destinationLat}&priority=TIME",
        );
        response = await http.get(url, headers: {"Authorization": "KakaoAK $kakaoApiKey"});

      } else {
        url = Uri.parse("https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json");
        final body = {
          "startX": widget.originLng.toString(),
          "startY": widget.originLat.toString(),
          "endX": widget.destinationLng.toString(),
          "endY": widget.destinationLat.toString(),
          "startName": "출발지",
          "endName": "도착지",
          "searchOption": "0",
        };

        response = await http.post(url,
            headers: {
              "appKey": tmapApiKey,
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body: body
        );
      }

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _routeData = jsonDecode(response.body);
          _isLoading = false;
        });

        if (_selectedMode != "transit" && _mapController != null) {
          _updateMapPolyline();
        }
      } else {
        // 대중교통 외의 모드에서 에러가 나면 그냥 로딩 해제
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      // 에러 발생 시 대중교통이었다면 도보로 전환 시도
      if (_selectedMode == "transit") {
        _switchToWalkFallback();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// 🗺️ Map Polyline Drawing
  Future<void> _updateMapPolyline() async {
    if (_mapController == null || _routeData == null) return;
    if (!mounted) return;

    try {
      List<NLatLng> points = [];

      if (_selectedMode == "car") {
        final routes = _routeData?["routes"] as List?;
        if (routes != null && routes.isNotEmpty) {
          final sections = routes[0]["sections"] as List?;
          if (sections != null && sections.isNotEmpty) {
            final roads = sections[0]["roads"] as List?;
            if (roads != null) {
              for (var road in roads) {
                final vertexes = road["vertexes"] as List?;
                if (vertexes != null) {
                  for (int i = 0; i < vertexes.length; i += 2) {
                    points.add(NLatLng(vertexes[i + 1], vertexes[i]));
                  }
                }
              }
            }
          }
        }
      } else if (_selectedMode == "walk") {
        final features = _routeData?["features"] as List?;
        if (features != null) {
          for (var feature in features) {
            final geometry = feature["geometry"];
            if (geometry != null) {
              final type = geometry["type"];
              final coordinates = geometry["coordinates"];

              if (type == "LineString") {
                for (var coord in coordinates) {
                  points.add(NLatLng(coord[1].toDouble(), coord[0].toDouble()));
                }
              }
            }
          }
        }
      }

      await _mapController!.clearOverlays();

      if (points.isEmpty) return;

      final polyline = NPolylineOverlay(
        id: "route_line",
        coords: points,
        color: _selectedMode == "car" ? kCarTeal : kWalkGreen,
        width: 8,
      );

      final startMarker = NMarker(
        id: "start",
        position: NLatLng(widget.originLat, widget.originLng),
        caption: const NOverlayCaption(text: "출발", color: kPrimaryColor),
        iconTintColor: kPrimaryColor,
        size: const Size(35, 45),
      );

      final endMarker = NMarker(
        id: "end",
        position: NLatLng(widget.destinationLat, widget.destinationLng),
        caption: const NOverlayCaption(text: "도착", color: kBusBlue),
        iconTintColor: kBusBlue,
        size: const Size(35, 45),
      );

      await _mapController!.addOverlay(polyline);
      await _mapController!.addOverlay(startMarker);
      await _mapController!.addOverlay(endMarker);

      final bounds = NLatLngBounds.from(points);
      await _mapController!.updateCamera(
          NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(100))
      );

    } catch (e) {
      debugPrint("Map draw error: $e");
    }
  }

  void _changeMode(String mode) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedMode = mode;
      _routeData = null;
    });
    _fetchRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildModeSelector(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                    : _selectedMode == "transit"
                    ? _buildTransitView()
                    : _buildMapView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(color: kBackgroundColor),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: kTextBlack),
                ),
              ),
              const SizedBox(width: 16),
              const Text("경로 상세", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextBlack)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.my_location_rounded, size: 18, color: kPrimaryColor),
                    Container(height: 24, width: 2, color: kSecondaryColor, margin: const EdgeInsets.symmetric(vertical: 4)),
                    const Icon(Icons.location_on_rounded, size: 18, color: kBusBlue),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLocationText("내 위치", isStart: true),
                      const SizedBox(height: 20),
                      _buildLocationText(widget.destinationName, isStart: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationText(String text, {required bool isStart}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: isStart ? FontWeight.w500 : FontWeight.w700,
        color: isStart ? kTextGrey : kTextBlack,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildModeSelector() {
    return Container(
      color: kBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildModeButton("transit", "대중교통", Icons.directions_bus_rounded),
            _buildModeButton("car", "자동차", Icons.directions_car_rounded),
            _buildModeButton("walk", "도보", Icons.directions_walk_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : kTextGrey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : kTextGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransitView() {
    if (_isTooCloseForTransit) {
      return _buildTooCloseState();
    }

    return Column(
      children: [
        Container(
          color: kBackgroundColor,
          child: TabBar(
            controller: _transitTabController,
            labelColor: kTextBlack,
            unselectedLabelColor: kTextGrey,
            indicatorColor: kTextBlack,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: "전체"),
              Tab(text: "버스"),
              Tab(text: "지하철"),
              Tab(text: "복합"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _transitTabController,
            children: [
              _buildTransitList("전체"),
              _buildTransitList("버스"),
              _buildTransitList("지하철"),
              _buildTransitList("버스+지하철"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTooCloseState() {
    final dist = _directDistance.round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: kWalkGreen.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.directions_walk_rounded, size: 48, color: kWalkGreen),
            ),
            const SizedBox(height: 24),
            const Text("거리가 아주 가까워요! 🐾", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextBlack)),
            const SizedBox(height: 12),
            Text("직선거리 약 ${dist}m 입니다.\n대중교통보다 산책 삼아 걷는 건 어때요?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: kTextGrey, height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text("도보 경로 확인하기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  shadowColor: kPrimaryColor.withOpacity(0.4),
                ),
                onPressed: () => _changeMode("walk"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransitList(String type) {
    final plan = _routeData?["metaData"]?["plan"];
    if (plan == null) return _buildErrorState("경로를 찾을 수 없습니다.");

    final itineraries = plan["itineraries"] as List?;
    if (itineraries == null || itineraries.isEmpty) return _buildErrorState("이동 경로가 없습니다.");

    final filtered = itineraries.where((itinerary) {
      final legs = itinerary["legs"] as List;
      final modes = legs.map((l) => l["mode"]).toList();
      if (type == "버스") return modes.contains("BUS") && !modes.contains("SUBWAY");
      if (type == "지하철") return modes.contains("SUBWAY") && !modes.contains("BUS");
      if (type == "버스+지하철") return modes.contains("BUS") && modes.contains("SUBWAY");
      return true;
    }).toList();

    if (filtered.isEmpty) return _buildErrorState("$type 경로가 없습니다.");

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildTransitCard(filtered[index]),
    );
  }

  Widget _buildTransitCard(Map<String, dynamic> itinerary) {
    final fare = itinerary["fare"]["regular"]["totalFare"];
    final totalTime = (itinerary["totalTime"] / 60).round();
    final legs = itinerary["legs"] as List;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserTransitDetailPage(
              legs: legs,
              fare: fare,
              totalTime: itinerary["totalTime"],
              originLat: widget.originLat,
              originLng: widget.originLng,
              destinationLat: widget.destinationLat,
              destinationLng: widget.destinationLng,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text("$totalTime", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kTextBlack)),
                    const Text("분", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextBlack)),
                  ],
                ),
                Text("$fare원", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextGrey)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: legs.map<Widget>((leg) {
                final mode = leg["mode"];
                final sectionTime = (leg["sectionTime"] ?? 0) / 60;
                if (mode == "WALK" && sectionTime < 2) return const SizedBox.shrink();

                Color color;
                if (mode == "BUS") { color = kBusBlue; }
                else if (mode == "SUBWAY") { color = kSubwayGreen; }
                else { color = Colors.grey[300]!; }

                return Expanded(
                  flex: sectionTime > 0 ? sectionTime.toInt() : 1,
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: legs.map<Widget>((leg) {
                if (leg["mode"] == "WALK") return const SizedBox.shrink();
                final routeName = leg["route"] ?? "";
                final color = leg["mode"] == "BUS" ? kBusBlue : kSubwayGreen;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(routeName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    String summaryText = "";
    String detailText = "";

    if (_routeData != null) {
      num distance = 0;
      num duration = 0;

      if (_selectedMode == "car") {
        final routes = _routeData!["routes"] as List?;
        if (routes != null && routes.isNotEmpty) {
          final summary = routes[0]["summary"];
          if (summary != null) {
            distance = summary["distance"] ?? 0;
            duration = summary["duration"] ?? 0;
          }
        }
      } else if (_selectedMode == "walk") {
        final features = _routeData!["features"] as List?;
        if (features != null && features.isNotEmpty) {
          final properties = features[0]["properties"];
          if (properties != null) {
            duration = properties["totalTime"] ?? 0;
            distance = properties["totalDistance"] ?? 0;
          }
        }
      }

      if (distance > 0) {
        final min = (duration / 60).round();
        summaryText = "$min분";

        // 1km 미만은 'm' 단위, 이상은 'km' 단위
        if (distance < 1000) {
          detailText = "${distance.toInt()} m";
        } else {
          detailText = "${(distance / 1000).toStringAsFixed(1)} km";
        }
      }
    }

    return Stack(
      children: [
        NaverMap(
          key: const ValueKey("route_map"),
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(widget.originLat, widget.originLng),
              zoom: 12,
            ),
            locationButtonEnable: true,
            logoClickEnable: false,
          ),
          onMapReady: (controller) {
            _mapController = controller;
            if (_routeData != null) {
              _updateMapPolyline();
            }
          },
        ),

        // 하단 요약 플로팅 카드
        if (summaryText.isNotEmpty)
          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ 수정됨: AppTheme.textGrey -> kTextGrey (const 제거)
                      Text(
                        _selectedMode == "car" ? "예상 소요시간" : "도보 소요시간",
                        style: const TextStyle(fontSize: 12, color: kTextGrey),
                      ),
                      const SizedBox(height: 2),
                      // ✅ 수정됨: AppTheme.textBlack -> kTextBlack
                      Text(
                        summaryText,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: kTextBlack
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      // ✅ 수정됨: AppTheme.primary -> kPrimaryColor
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      detailText,
                      // ✅ 수정됨: AppTheme.primary -> kPrimaryColor
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_off_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}