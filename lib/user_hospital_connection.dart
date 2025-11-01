// user_hospital_connection.dart.
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'user_mainscreen.dart';
import 'user_myhospital_list.dart';

import 'api_config.dart';

/// 내 반려동물 병원 연동하기
class UserHospitalConnectionPage extends StatefulWidget {
  final String? token;
  const UserHospitalConnectionPage({super.key, this.token});

  @override
  State<UserHospitalConnectionPage> createState() =>
      _UserHospitalConnectionPageState();
}

class _UserHospitalConnectionPageState
    extends State<UserHospitalConnectionPage> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final _http = http.Client();
  final _timeout = const Duration(seconds: 8);

  String _regionLabel = '경기도 김포시';
  String _query = '';

  List<_HospitalItem> _allHospitals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  int _statusOrder(String s) {
    switch (s) {
      case 'PENDING':
        return 0;
      case 'APPROVED':
        return 1;
      default:
        return 2;
    }
  }

  // 병원 + 내 상태 가져오기
  Future<void> _fetchHospitals() async {
    setState(() {
      _loading = true;
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-links/available');
      final res = await _http.get(
        uri,
        headers: {
          if (widget.token != null && widget.token!.isNotEmpty)
            'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(_timeout);

      if (res.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('목록 불러오기 실패 (${res.statusCode})')),
        );
        setState(() => _loading = false);
        return;
      }

      final body = jsonDecode(res.body);
      final List list = body is List ? body : (body['data'] as List? ?? []);
      final items = list.map((e) {
        return _HospitalItem(
          id: (e['hospitalId'] ?? e['_id'] ?? '').toString(),
          name: (e['hospitalName'] ?? e['name'] ?? '이름없음').toString(),
          myStatus: (e['myStatus'] ?? 'NONE').toString(), // NONE | PENDING | APPROVED
          imageUrl: (e['imageUrl'] ?? '').toString(),
          createdAt: DateTime.tryParse((e['createdAt'] ?? '').toString()),
        );
      }).toList();

      items.sort((a, b) {
        final so =
        _statusOrder(a.myStatus).compareTo(_statusOrder(b.myStatus));
        if (so != 0) return so;
        final aa = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });

      if (!mounted) return;
      setState(() {
        _allHospitals = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
      setState(() => _loading = false);
    }
  }

  // 검색 필터
  List<_HospitalItem> get _filteredHospitals {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _allHospitals;
    return _allHospitals.where((h) => h.name.toLowerCase().contains(q)).toList();
  }

  // 뒤로가기 → 내 병원 리스트
  void _goBackToMyHospitalList() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            UserMyHospitalListPage(token: widget.token),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // 홈으로 교체 이동
  void _noAnimReplace(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // 연동 신청
  Future<void> _requestConnect(_HospitalItem h) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-links/request');
      final res = await _http
          .post(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'hospitalId': h.id}),
      )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${h.name}" 연동 신청이 접수되었습니다. (승인 대기)')),
        );
        setState(() {
          final idx = _allHospitals.indexWhere((e) => e.id == h.id);
          if (idx >= 0) {
            _allHospitals[idx] = _allHospitals[idx].copyWith(myStatus: 'PENDING');
            _allHospitals.sort((a, b) {
              final so = _statusOrder(a.myStatus).compareTo(_statusOrder(b.myStatus));
              if (so != 0) return so;
              final aa = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bb.compareTo(aa);
            });
          }
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연동 신청 실패: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    }
  }

  // 검색 바텀시트
  void _openSearch() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final ctrl = TextEditingController(text: _query);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('병원명으로 검색',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: '병원명을 입력하세요',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => Navigator.pop(ctx, v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('검색'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) setState(() => _query = result);
  }

  @override
  Widget build(BuildContext context) {
    final divider = Divider(height: 1, thickness: 1, color: Colors.grey.shade300);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFFFF4B8),
          centerTitle: true,
          leadingWidth: 48,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 28),
            onPressed: _goBackToMyHospitalList,
            tooltip: '뒤로',
          ),
          title: const Text(
            '내 반려동물 병원 연동하기',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchHospitals,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 18),

              const Text('현재 체험할 수 있는 병원',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: _loading
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
                    : Column(
                  children: [
                    ..._filteredHospitals.map(
                          (h) => _ConnectableHospitalRow(
                        hospital: h,
                        onConnect: () => _requestConnect(h),
                      ),
                    ),
                    if (!_loading && _filteredHospitals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('표시할 병원이 없습니다.',
                            style: TextStyle(color: Colors.black54)),
                      ),
                  ],
                ),
              ),
              divider,

              const SizedBox(height: 18),

              const Text('병원 검색',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      _regionLabel,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: _openSearch,
                    icon: const Icon(Icons.search, size: 26),
                    tooltip: '병원 검색',
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        onTap: (i) {
          switch (i) {
            case 0:
              if (widget.token != null) {
                _noAnimReplace(PetHomeScreen(token: widget.token!));
              } else {
                Navigator.pop(context);
              }
              break;
            case 1:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('건강관리는 준비 중입니다.')),
              );
              break;
            case 2:
              break;
            case 3:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('마이페이지는 준비 중입니다.')),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined), label: '내 병원'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }
}

/// 모델
class _HospitalItem {
  final String id;
  final String name;
  final String myStatus; // NONE | PENDING | APPROVED
  final String? imageUrl;
  final DateTime? createdAt;

  _HospitalItem({
    required this.id,
    required this.name,
    required this.myStatus,
    this.imageUrl,
    this.createdAt,
  });

  _HospitalItem copyWith({
    String? id,
    String? name,
    String? myStatus,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return _HospitalItem(
      id: id ?? this.id,
      name: name ?? this.name,
      myStatus: myStatus ?? this.myStatus,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 한 줄 UI
class _ConnectableHospitalRow extends StatelessWidget {
  final _HospitalItem hospital;
  final VoidCallback onConnect;

  const _ConnectableHospitalRow({
    super.key,
    required this.hospital,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = Colors.black54;

    Widget action;
    if (hospital.myStatus == 'APPROVED') {
      action = const Text('승인됨', style: TextStyle(fontSize: 13, color: Colors.green));
    } else if (hospital.myStatus == 'PENDING') {
      action = const Text('승인 대기', style: TextStyle(fontSize: 13, color: Colors.orange));
    } else {
      action = SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: onConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black87,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: const Text('연동', style: TextStyle(fontSize: 13)),
        ),
      );
    }

    String? statusLabel;
    switch (hospital.myStatus) {
      case 'APPROVED':
        statusLabel = '승인됨';
        break;
      case 'PENDING':
        statusLabel = '승인 대기';
        break;
      default:
        statusLabel = null;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (statusLabel != null)
                      Text(statusLabel, style: TextStyle(fontSize: 12, color: subtle)),
                    const SizedBox(height: 2),
                    Text(
                      hospital.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              action,
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
      ],
    );
  }
}
