import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class UserTransitDetailPage extends StatefulWidget {
  final List<dynamic> legs; // 경로 구간 데이터
  final int fare; // 요금
  final int totalTime; // 전체 소요시간 (초 단위)
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;

  const UserTransitDetailPage({
    super.key,
    required this.legs,
    required this.fare,
    required this.totalTime,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  State<UserTransitDetailPage> createState() => _UserTransitDetailPageState();
}

class _UserTransitDetailPageState extends State<UserTransitDetailPage> {
  NaverMapController? _mapController;
  bool _isMapReady = false;
  bool _isPanelOpen = false;

  /// ✅ 지도에 대중교통 경로 표시 (색상 + 아이콘 구분 + 카메라 자동 맞춤)
  Future<void> _drawTransitPath() async {
    if (_mapController == null) return;

    await _mapController!.clearOverlays();
    List<NLatLng> allPoints = [];

    for (var leg in widget.legs) {
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
        if (line == null || line.isEmpty) continue;

        final coords = line.trim().split(" ");
        List<NLatLng> segmentPoints = [];

        for (var pair in coords) {
          final parts = pair.split(",");
          if (parts.length == 2) {
            final lon = double.tryParse(parts[0]);
            final lat = double.tryParse(parts[1]);
            if (lat != null && lon != null) {
              segmentPoints.add(NLatLng(lat, lon));
              allPoints.add(NLatLng(lat, lon));
            }
          }
        }

        if (segmentPoints.isNotEmpty) {
          _mapController!.addOverlay(NPolylineOverlay(
            id: "${mode}_${DateTime.now().millisecondsSinceEpoch}",
            coords: segmentPoints,
            color: color,
            width: 6,
          ));
        }
      }

      // ✅ 각 구간 시작 위치 마커
      final start = leg["start"];
      if (start != null &&
          start["lat"] != null &&
          start["lon"] != null &&
          start["name"] != null) {
        _mapController!.addOverlay(
          NMarker(
            id: "start_${mode}_${DateTime.now().millisecondsSinceEpoch}",
            position: NLatLng(start["lat"], start["lon"]),
            caption: NOverlayCaption(
              text: mode == "BUS"
                  ? "🚌 버스 (${start["name"]})"
                  : (mode == "SUBWAY"
                  ? "🚇 지하철 (${start["name"]})"
                  : "🚶 도보 (${start["name"]})"),
              textSize: 11,
            ),
            iconTintColor: color,
          ),
        );
      }
    }

    // ✅ 카메라 자동 이동 (경로 전체 보기)
    if (allPoints.isNotEmpty) {
      double minLat = allPoints.first.latitude;
      double maxLat = allPoints.first.latitude;
      double minLng = allPoints.first.longitude;
      double maxLng = allPoints.first.longitude;

      for (var point in allPoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      final bounds = NLatLngBounds(
        southWest: NLatLng(minLat, minLng),
        northEast: NLatLng(maxLat, maxLng),
      );

      await _mapController!.updateCamera(
        NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(60)),
      );
    }

    // ✅ 출발 / 도착 마커
    _mapController!.addOverlay(NMarker(
      id: "start",
      position: NLatLng(widget.originLat, widget.originLng),
      caption: const NOverlayCaption(text: "출발"),
    ));
    _mapController!.addOverlay(NMarker(
      id: "end",
      position: NLatLng(widget.destinationLat, widget.destinationLng),
      caption: const NOverlayCaption(text: "도착"),
    ));

    print("✅ 지도에 ${allPoints.length}개의 경로 좌표 표시 완료");
  }


  /// ✅ 구간 텍스트
  Widget _buildLegSummary(Map<String, dynamic> leg) {
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7CC),
      appBar: AppBar(
        title: const Text("대중교통 경로 상세", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFFFF7CC),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          /// ✅ 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(widget.originLat, widget.originLng),
                zoom: 11.5,
              ),
            ),
            onMapReady: (controller) {
              _mapController = controller;
              setState(() => _isMapReady = true);
              _drawTransitPath();
            },
          ),

          if (!_isMapReady)
            const Center(child: CircularProgressIndicator()),

          /// ✅ 상단 요금/시간 카드
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("💰 ${widget.fare}원",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("⏱ ${widget.totalTime ~/ 60}분 소요",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),

          /// ✅ 왼쪽 슬라이드 패널
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            top: 80,
            bottom: 0,
            left: _isPanelOpen ? 0 : -260,
            width: 260,
            child: Material(
              elevation: 6,
              borderRadius:
              const BorderRadius.horizontal(right: Radius.circular(16)),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF7CC),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "📍 이동 경로 요약",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.legs
                            .map((leg) => _buildLegSummary(leg))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// ✅ 열기/닫기 버튼
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: _isPanelOpen ? 260 : 0,
            child: GestureDetector(
              onTap: () => setState(() => _isPanelOpen = !_isPanelOpen),
              child: Container(
                height: 80,
                width: 30,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(10),
                  ),
                ),
                child: Icon(
                  _isPanelOpen ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
