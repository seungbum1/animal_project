import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'user_transit_detail_page.dart';

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

class _RouteFindingPageState extends State<RouteFindingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _routeData;
  String _selectedMode = "transit";

  // ✅ API 키
  final String kakaoApiKey = "bc6ab37a4ae28c4d0d8d2dbf8a3c8378";
  final String tmapApiKey = "Om0qwEOnhl67NmhPKlHTV2IUu8FQrEsG9lHcdU3Y";

  /// ✅ 수정: late 제거하고 null 허용
  NaverMapController? _mapController;
  NPolylineOverlay? _polyline;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchRoute();
  }

  /// ✅ 모드별 경로 요청
  Future<void> _fetchRoute() async {
    setState(() => _isLoading = true);
    Uri url;
    http.Response response;

    try {
      if (_selectedMode == "transit") {
        // 🚍 Tmap 대중교통 API (POST 요청)
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

        response = await http.post(
          url,
          headers: {
            "accept": "application/json",
            "content-type": "application/json",
            "appKey": tmapApiKey,
          },
          body: body,
        );

        print("🚀 요청 URL: $url");
        print("📦 요청 Body: $body");
        print("🧾 응답 코드: ${response.statusCode}");
        print("📄 응답 내용: ${response.body}");
      } else if (_selectedMode == "car") {
        // 🚗 카카오 자동차 길찾기
        url = Uri.parse(
          "https://apis-navi.kakaomobility.com/v1/directions?"
              "origin=${widget.originLng},${widget.originLat}"
              "&destination=${widget.destinationLng},${widget.destinationLat}"
              "&priority=TIME",
        );
        response =
        await http.get(url, headers: {"Authorization": "KakaoAK $kakaoApiKey"});
      } else {
        // 🚶 카카오 도보 길찾기
        url = Uri.parse(
          "https://apis-navi.kakaomobility.com/v1/walks/directions?"
              "origin=${widget.originLng},${widget.originLat}"
              "&destination=${widget.destinationLng},${widget.destinationLat}",
        );
        response =
        await http.get(url, headers: {"Authorization": "KakaoAK $kakaoApiKey"});
      }

      if (response.statusCode == 200) {
        setState(() {
          _routeData = jsonDecode(response.body);
          _isLoading = false;
        });
        if (_selectedMode != "transit") _updateMapPolyline();
      } else {
        print("❌ 요청 실패: ${response.statusCode}");
        print("응답 내용: ${response.body}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("❌ 오류 발생: $e");
      setState(() => _isLoading = false);
    }
  }

  /// ✅ 지도에 경로선 표시 (자동차/도보)
  Future<void> _updateMapPolyline() async {
    if (_mapController == null || _routeData == null) return; // ✅ 안전검사 추가
    final roads = _routeData?["routes"]?[0]?["sections"]?[0]?["roads"] as List?;
    if (roads == null) return;

    List<NLatLng> points = [];
    for (var road in roads) {
      final vertexes = road["vertexes"] as List?;
      if (vertexes != null && vertexes.isNotEmpty) {
        for (int i = 0; i < vertexes.length; i += 2) {
          final x = vertexes[i];
          final y = vertexes[i + 1];
          points.add(NLatLng(y, x));
        }
      }
    }

    _mapController!.clearOverlays();
    final polyline = NPolylineOverlay(
      id: "route_line",
      coords: points,
      color: _selectedMode == "car" ? Colors.blue : Colors.green,
      width: 6,
    );

    _mapController!.addOverlay(polyline);
    _mapController!.addOverlay(NMarker(
      id: "start",
      position: NLatLng(widget.originLat, widget.originLng),
      caption: NOverlayCaption(text: "출발"),
    ));
    _mapController!.addOverlay(NMarker(
      id: "end",
      position: NLatLng(widget.destinationLat, widget.destinationLng),
      caption: NOverlayCaption(text: "도착"),
    ));
  }

  void _changeMode(String mode) {
    setState(() => _selectedMode = mode);
    _fetchRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7CC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("빠른길찾기", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildLocationInputs(),
          _buildModeSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedMode == "transit"
                ? _buildTransitTabs()
                : _buildMapView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInputs() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          const TextField(
            readOnly: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: "출발지: 성수역",
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: "도착지: 목적지",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeIcon(Icons.directions_bus, "transit", "대중교통"),
          _buildModeIcon(Icons.directions_car, "car", "자동차"),
          _buildModeIcon(Icons.directions_walk, "walk", "도보"),
        ],
      ),
    );
  }

  Widget _buildModeIcon(IconData icon, String mode, String label) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: Column(
        children: [
          Icon(icon, size: 35, color: isSelected ? Colors.black : Colors.grey),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }

  Widget _buildTransitTabs() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            indicatorColor: Colors.black,
            tabs: const [
              Tab(text: "전체"),
              Tab(text: "버스"),
              Tab(text: "지하철"),
              Tab(text: "버스+지하철"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTmapTransitInfo("전체"),
              _buildTmapTransitInfo("버스"),
              _buildTmapTransitInfo("지하철"),
              _buildTmapTransitInfo("버스+지하철"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTmapTransitInfo(String type) {
    final plan = _routeData?["metaData"]?["plan"];
    if (plan == null) {
      return const Center(child: Text("🚫 대중교통 경로를 찾을 수 없습니다."));
    }

    final itineraries = plan["itineraries"] as List?;
    if (itineraries == null || itineraries.isEmpty) {
      return const Center(child: Text("🚫 대중교통 정보가 없습니다."));
    }

    final filtered = itineraries.where((itinerary) {
      final legs = itinerary["legs"] as List;
      final modes = legs.map((l) => l["mode"]).toList();
      if (type == "버스") return modes.contains("BUS") && !modes.contains("SUBWAY");
      if (type == "지하철") return modes.contains("SUBWAY") && !modes.contains("BUS");
      if (type == "버스+지하철") return modes.contains("BUS") && modes.contains("SUBWAY");
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(child: Text("$type 경로를 찾을 수 없습니다."));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final itinerary = filtered[index];
        final fare = itinerary["fare"]["regular"]["totalFare"];
        final totalTime = itinerary["totalTime"];
        final legs = itinerary["legs"] as List;

        Widget _buildLegRow(Map<String, dynamic> leg) {
          final mode = leg["mode"];
          final start = leg["start"]["name"];
          final end = leg["end"]["name"];
          final route = leg["route"] ?? "";

          IconData icon;
          Color color;

          switch (mode) {
            case "BUS":
              icon = Icons.directions_bus;
              color = Colors.blueAccent;
              break;
            case "SUBWAY":
              icon = Icons.subway;
              color = Colors.purple;
              break;
            default:
              icon = Icons.directions_walk;
              color = Colors.green;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$start → $end ${route.isNotEmpty ? "($route)" : ""}",
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        return InkWell(
          onTap: () {
            print("✅ UserTransitDetailPage 이동 시도");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserTransitDetailPage(
                  legs: legs,
                  fare: fare,
                  totalTime: totalTime,
                  originLat: widget.originLat,
                  originLng: widget.originLng,
                  destinationLat: widget.destinationLat,
                  destinationLng: widget.destinationLng,
                ),
              ),
            );
          },
          child: Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route, color: Colors.black54, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "요금: ${fare}원 | 소요시간: ${totalTime ~/ 60}분",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12, thickness: 1, color: Colors.grey),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: legs.map((l) => _buildLegRow(l)).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text("👆 이 경로를 클릭하면 상세 화면으로 이동합니다.",
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _drawTransitPathOnMap(List<dynamic> legs) async {
    if (_mapController == null) {
      print("⚠️ 지도 컨트롤러가 아직 초기화되지 않았습니다.");
      return;
    }

    await _mapController!.clearOverlays();
    List<NLatLng> allPoints = [];

    for (var leg in legs) {
      final mode = leg["mode"];
      final color = (mode == "BUS")
          ? Colors.blueAccent
          : (mode == "SUBWAY")
          ? Colors.purple
          : Colors.green;

      final steps = leg["steps"] as List?;
      if (steps == null) continue;

      for (var step in steps) {
        final line = step["linestring"];
        if (line == null) continue;

        final coords = line.split(" ");
        for (var pair in coords) {
          final parts = pair.split(",");
          if (parts.length == 2) {
            final lon = double.tryParse(parts[0]);
            final lat = double.tryParse(parts[1]);
            if (lat != null && lon != null) {
              allPoints.add(NLatLng(lat, lon));
            }
          }
        }

        final segmentLine = NPolylineOverlay(
          id: "${mode}_${DateTime.now().millisecondsSinceEpoch}",
          coords: List<NLatLng>.from(allPoints),
          color: color,
          width: 5,
        );
        _mapController!.addOverlay(segmentLine);
        allPoints.clear();
      }
    }

    _mapController!.addOverlay(NMarker(
      id: "start",
      position: NLatLng(widget.originLat, widget.originLng),
      caption: NOverlayCaption(text: "출발"),
    ));
    _mapController!.addOverlay(NMarker(
      id: "end",
      position: NLatLng(widget.destinationLat, widget.destinationLng),
      caption: NOverlayCaption(text: "도착"),
    ));
  }

  Widget _buildMapView() {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(widget.originLat, widget.originLng),
          zoom: 11.5,
        ),
      ),
      onMapReady: (controller) {
        _mapController = controller;
        _updateMapPolyline();
      },
    );
  }
}
