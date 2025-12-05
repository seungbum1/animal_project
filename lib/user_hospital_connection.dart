// user_hospital_connection.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 햅틱 피드백용
import 'package:http/http.dart' as http;

import 'hospital_list_page.dart';
import 'hospital_detail_page.dart';
import 'api_config.dart';

// 🎨 Design Token Integration
const Color kPrimaryColor = Color(0xFFC06362); // Main Brand Color
const Color kPrimaryLight = Color(0xFFFDECEC);
const Color kBackgroundColor = Color(0xFFF9F9F9);
const Color kSurfaceWhite = Colors.white;
const Color kTextBlack = Color(0xFF222222);
const Color kTextGrey = Color(0xFF888888);

class UserHospitalConnectionPage extends StatefulWidget {
  final String? token;
  // ✅ 외부에서(지도 상세 등) 넘어올 때 자동 검색할 병원 이름
  final String? autoSearchQuery;

  const UserHospitalConnectionPage({
    super.key,
    this.token,
    this.autoSearchQuery,
  });

  @override
  State<UserHospitalConnectionPage> createState() => _UserHospitalConnectionPageState();
}

class _UserHospitalConnectionPageState extends State<UserHospitalConnectionPage> {

  // --- API 관련 ---
  static String get _baseUrl => ApiConfig.baseUrl;
  final _http = http.Client();
  final _timeout = const Duration(seconds: 8);

  final TextEditingController _searchController = TextEditingController();

  List<_HospitalItem> _allHospitals = []; // 서버에서 불러온 전체 병원 목록
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    // ✅ 화면 진입 시 자동 검색어가 있는지 확인
    if (widget.autoSearchQuery != null && widget.autoSearchQuery!.isNotEmpty) {
      _searchController.text = widget.autoSearchQuery!;
      // 화면이 그려진 직후에 필터링된 데이터 로딩
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchHospitals(filterQuery: widget.autoSearchQuery!);
      });
    } else {
      // 검색어 없으면 전체 로딩
      _fetchHospitals();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _http.close();
    super.dispose();
  }

  // 1️⃣ [API] 연동 가능한 병원 목록 가져오기
  Future<void> _fetchHospitals({String? filterQuery}) async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-links/available');
      final res = await _http.get(
        uri,
        headers: {
          if (widget.token != null) 'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);

        List<_HospitalItem> items = list.map((e) {
          return _HospitalItem(
            id: (e['hospitalId'] ?? e['_id'] ?? '').toString(),
            name: (e['hospitalName'] ?? e['name'] ?? '이름없음').toString(),
            myStatus: (e['myStatus'] ?? 'NONE').toString(),
            imageUrl: (e['imageUrl'] ?? '').toString(),
            createdAt: DateTime.tryParse((e['createdAt'] ?? '').toString()),
          );
        }).toList();

        // 🔍 검색어 필터링
        if (filterQuery != null && filterQuery.trim().isNotEmpty) {
          items = items.where((element) =>
          element.name.contains(filterQuery) ||
              element.name.contains(filterQuery.replaceAll(' ', ''))
          ).toList();
        }

        // 정렬
        items.sort((a, b) {
          final so = _statusOrder(a.myStatus).compareTo(_statusOrder(b.myStatus));
          if (so != 0) return so;
          final aa = a.createdAt ?? DateTime(0);
          final bb = b.createdAt ?? DateTime(0);
          return bb.compareTo(aa);
        });

        if (mounted) setState(() { _allHospitals = items; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _statusOrder(String s) {
    if (s == 'PENDING') return 0; // 승인 대기 (최상단)
    if (s == 'NONE') return 1;    // 연동 안됨 (중간)
    return 2;                     // 승인됨 (하단)
  }

  // 2️⃣ [API] 연동 신청
  Future<void> _requestConnect(_HospitalItem h) async {
    HapticFeedback.mediumImpact();
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-links/request');
      final res = await _http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'hospitalId': h.id}),
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${h.name}" 연동 신청 완료! (승인 대기)'),
            backgroundColor: const Color(0xFF6A994E), // Green
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          final idx = _allHospitals.indexWhere((e) => e.id == h.id);
          if (idx >= 0) {
            _allHospitals[idx] = _allHospitals[idx].copyWith(myStatus: 'PENDING');
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연동 신청 실패: 이미 요청했거나 오류가 발생했습니다.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }

  void _goToMapMode() {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => HospitalListPage(
      token: widget.token, category: '병원', searchQuery: null,
    )));
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => HospitalListPage(
      token: widget.token, category: '병원', searchQuery: query,
    )));
  }

  void _onLocalSearch() {
    _fetchHospitals(filterQuery: _searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor, // 배경색 통일
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kBackgroundColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextBlack),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('병원 찾기', style: TextStyle(color: kTextBlack, fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () {
              _searchController.clear();
              _fetchHospitals(); // 전체 목록 새로고침
            },
            icon: const Icon(Icons.refresh_rounded, color: kTextGrey),
          )
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: kPrimaryColor,
          onRefresh: () => _fetchHospitals(filterQuery: _searchController.text),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // 1. 검색 헤더 (검색창 + 지도버튼)
                _buildSearchHeader(),

                const SizedBox(height: 32),

                // 2. 병원 리스트
                _buildSectionHeader("🏥 연동 가능한 병원", "다니시는 병원을 찾아 연동해보세요"),
                const SizedBox(height: 16),

                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: kPrimaryColor)))
                else if (_allHospitals.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("조건에 맞는 병원이 없어요.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _allHospitals.map((h) => _buildHospitalCard(h)).toList(),
                  ),

                const SizedBox(height: 32),
                Divider(thickness: 1, color: Colors.grey[200]),
                const SizedBox(height: 32),

                // 3. 추천 키워드
                _buildSectionHeader("🔍 추천 검색어", null),
                const SizedBox(height: 16),
                _buildKeywordChips(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 위젯 ---

  Widget _buildSearchHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("어떤 병원을\n찾고 계신가요?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kTextBlack, height: 1.3)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                    color: kSurfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: kTextGrey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (val) => _onLocalSearch(), // 엔터 치면 필터링
                        style: const TextStyle(fontSize: 16, color: kTextBlack),
                        decoration: InputDecoration(
                            hintText: "병원명 검색",
                            hintStyle: TextStyle(color: kTextGrey.withOpacity(0.7)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(bottom: 4)
                        ),
                      ),
                    ),
                    // 돋보기 버튼
                    GestureDetector(
                      onTap: _onLocalSearch,
                      child: const Icon(Icons.arrow_forward_rounded, color: kTextBlack),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 지도 버튼 (Brand Color 적용)
            GestureDetector(
              onTap: _goToMapMode,
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                    color: kPrimaryColor, // 메인 컬러
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: const Icon(Icons.map_outlined, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Align(alignment: Alignment.centerRight, child: Text("👆 지도로 내 주변 찾아보기", style: TextStyle(fontSize: 12, color: kTextGrey, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _buildHospitalCard(_HospitalItem h) {
    final bool isApproved = h.myStatus == 'APPROVED';
    final bool isPending = h.myStatus == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: isApproved
            ? Border.all(color: const Color(0xFF6A994E).withOpacity(0.3), width: 1.5)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: isApproved ? const Color(0xFFE8F5E9) : (isPending ? const Color(0xFFFFF3E0) : Colors.grey[100]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
                Icons.local_hospital_rounded,
                color: isApproved ? const Color(0xFF6A994E) : (isPending ? Colors.orange : Colors.grey[400]),
                size: 24
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextBlack)),
                const SizedBox(height: 4),
                if (isApproved)
                  const Text("연동 완료됨", style: TextStyle(fontSize: 12, color: Color(0xFF6A994E), fontWeight: FontWeight.w600))
                else if (isPending)
                  const Text("승인 대기중...", style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600))
                else
                  const Text("간편 연동 지원", style: TextStyle(fontSize: 12, color: kTextGrey)),
              ],
            ),
          ),
          if (!isApproved)
            ElevatedButton(
              onPressed: isPending ? null : () => _requestConnect(h),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPending ? Colors.grey[300] : kPrimaryColor, // 메인 컬러 적용
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                minimumSize: const Size(60, 36),
              ),
              child: Text(isPending ? "대기" : "연동", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          else
            const Icon(Icons.check_circle_rounded, color: Color(0xFF6A994E)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextBlack)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: kTextGrey)),
        ]
      ],
    );
  }

  Widget _buildKeywordChips() {
    final keywords = ["24시 동물병원", "고양이 전문", "슬개골 수술", "건강검진"];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: keywords.map((k) => ActionChip(
        label: Text(k),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        backgroundColor: kSurfaceWhite,
        surfaceTintColor: kSurfaceWhite,
        side: BorderSide(color: Colors.grey.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        labelStyle: const TextStyle(color: kTextBlack, fontSize: 13, fontWeight: FontWeight.w500),
        onPressed: () => _onSearchSubmitted(k), // 지도로 이동 검색
      )).toList(),
    );
  }
}

// --- 데이터 모델 ---
class _HospitalItem {
  final String id;
  final String name;
  final String myStatus; // NONE | PENDING | APPROVED
  final String? imageUrl;
  final DateTime? createdAt;

  _HospitalItem({
    required this.id, required this.name, required this.myStatus, this.imageUrl, this.createdAt,
  });

  _HospitalItem copyWith({String? myStatus}) {
    return _HospitalItem(
      id: id, name: name, myStatus: myStatus ?? this.myStatus,
      imageUrl: imageUrl, createdAt: createdAt,
    );
  }
}