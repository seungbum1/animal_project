// user_myhospital_list.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_mypage.dart';
import 'api_config.dart';

import 'user_health_main.dart';
import 'user_mainscreen.dart'; // 홈으로 이동 시 사용 (PetHomeScreen)
import 'user_hospital_connection.dart'; // 병원 연동하기 화면
import 'user_myhospital_mainscreen.dart'; // "내 병원 메인" 화면

class UserMyHospitalListPage extends StatefulWidget {
  final String? token;

  /// MainTabs(IndexedStack) 안에서 쓸 땐 false로 내려서 하단 네비를 숨긴다.
  final bool showBottomNav;

  const UserMyHospitalListPage({
    super.key,
    this.token,
    this.showBottomNav = true,
  });

  @override
  State<UserMyHospitalListPage> createState() => _UserMyHospitalListPageState();
}

class _UserMyHospitalListPageState extends State<UserMyHospitalListPage> {
  // =========================
  // 백엔드 베이스 URL 자동 선택
  // =========================
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  Duration _timeout = const Duration(seconds: 8);

  List<_LinkedHospital> _linked = [];
  bool _loading = true;
  String? _error;

  void _noAnimReplace(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLinkedHospitals();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<void> _loadLinkedHospitals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl/api/users/me/hospitals'); // 기본: APPROVED만
      final res = await _http
          .get(
        uri,
        headers: {
          if (widget.token != null && widget.token!.isNotEmpty)
            'Authorization': 'Bearer ${widget.token}', // ✅ 토큰 추가
        },
      )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);
        final items = list.map((e) {
          return _LinkedHospital(
            id: (e['hospitalId'] ?? e['_id'] ?? '').toString(),
            name: (e['hospitalName'] ?? e['name'] ?? '이름없음').toString(),
            linkedAt: DateTime.tryParse((e['linkedAt'] ?? '').toString()),
          );
        }).toList();

        // 최신 연동이 위
        items.sort((a, b) {
          final aa = a.linkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bb = b.linkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bb.compareTo(aa);
        });

        setState(() {
          _linked = items;
          _loading = false;
        });

        // ✅ 각 병원별로 "가장 가까운 예약 확정" 정보 로딩
        for (final h in items) {
          _loadNextApprovedApptForHospital(h);
        }
      } else if (res.statusCode == 401) {
        setState(() {
          _linked = [];
          _loading = false;
          _error = '세션이 만료되었거나 로그인 정보가 없습니다.';
        });
      } else {
        setState(() {
          _linked = [];
          _loading = false;
          _error = '서버 오류 (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _linked = [];
        _loading = false;
        _error = '네트워크 오류: $e';
      });
    }
  }

  /// ✅ 병원별로 "예약 확정" 중에서 가장 가까운 1개 찾아서 hospital.nextApptSummary 에 세팅
  Future<void> _loadNextApprovedApptForHospital(_LinkedHospital hospital) async {
    // 토큰 없으면 스킵
    if (widget.token == null || widget.token!.isEmpty) return;

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    Future<List<_Appt>> fetchMonth(DateTime m) async {
      final y = m.year;
      final mm = m.month.toString().padLeft(2, '0');
      final uri = Uri.parse(
          '$_baseUrl/api/users/me/appointments/monthly?month=$y-$mm&hospitalId=${hospital.id}');
      try {
        final res = await _http
            .get(
          uri,
          headers: {'Authorization': 'Bearer ${widget.token}'},
        )
            .timeout(_timeout);

        if (res.statusCode != 200) {
          return <_Appt>[];
        }

        final data = jsonDecode(res.body);
        final list = (data is List) ? data : <dynamic>[];
        return list
            .map((e) => _Appt.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } catch (_) {
        return <_Appt>[];
      }
    }

    // 이번 달 + 다음 달 예약 전부 모아서
    final all = <_Appt>[];
    all.addAll(await fetchMonth(thisMonth));
    all.addAll(await fetchMonth(nextMonth));

    if (all.isEmpty) return;

    final upcoming = all
        .where((a) => _isApproved(a.status) && !a.visit.isBefore(now))
        .toList()
      ..sort((a, b) => a.visit.compareTo(b.visit));

    if (upcoming.isEmpty) return;

    final a = upcoming.first;

    final y = a.visit.year.toString().padLeft(4, '0');
    final mStr = a.visit.month.toString().padLeft(2, '0');
    final dStr = a.visit.day.toString().padLeft(2, '0');

    final who = [
      if ((a.userName ?? '').isNotEmpty) a.userName!,
      if ((a.petName ?? '').isNotEmpty) a.petName!,
      if (a.doctor.isNotEmpty) a.doctor,
    ].join(' / ');

    final summary =
        '$y-$mStr-$dStr ${a.hhmm} ${a.service}${who.isNotEmpty ? ' $who' : ''}';

    if (!mounted) return;

    setState(() {
      final idx = _linked.indexWhere((x) => x.id == hospital.id);
      if (idx == -1) return;

      final updated =
      _linked[idx].copyWith(nextApptSummary: summary);
      final copied = [..._linked];
      copied[idx] = updated;
      _linked = copied;
    });
  }

  // 병원 메인으로 전환(병원 선택 후)
  void _goHospitalMain(_LinkedHospital h) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => UserMyHospitalMainScreen(
          token: widget.token ?? '',
          hospitalId: h.id,
          hospitalName: h.name,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // 병원 연동하기 화면으로 이동
  void _openConnectionPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserHospitalConnectionPage(token: widget.token),
      ),
    );
    // 돌아왔을 때 목록 새로고침
    if (mounted) _loadLinkedHospitals();
  }

  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8); // 연노랑(스샷톤)

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: AppBar(
          elevation: 0,
          backgroundColor: topYellow,
          centerTitle: true,
          title: const Text(
            '내 병원',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
      ),

      // 전체 바디에 노란 배경 적용 (리스트 + 하단 버튼 영역 모두)
      body: SafeArea(
        child: Container(
          color: topYellow,
          child: RefreshIndicator(
            onRefresh: _loadLinkedHospitals,
            child: Column(
              children: [
                // 리스트 영역
                Expanded(
                  child: _loading
                      ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : (_linked.isEmpty
                      ? _EmptyState(
                    error: _error,
                    onConnectTap: _openConnectionPage,
                  )
                      : ListView.builder(
                    physics:
                    const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16),
                    itemCount: _linked.length,
                    itemBuilder: (_, i) {
                      final h = _linked[i];
                      return _LinkedHospitalRow(
                        name: h.name,
                        nextApptSummary: h.nextApptSummary,
                        onMove: () => _goHospitalMain(h),
                      );
                    },
                  )),
                ),

                // 하단 "병원 연동하기" 버튼 (가운데)
                Padding(
                  padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: SizedBox(
                    width: 180,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _openConnectionPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text('병원 연동하기'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // 하단 네비게이션바: 단독 화면일 때만 노출 (탭 내부에서는 숨김)
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 2, // ‘내 병원’ 탭
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        onTap: (i) {
          switch (i) {
            case 0:
              _noAnimReplace(
                  PetHomeScreen(token: widget.token ?? ''));
              break;
            case 1:
              _noAnimReplace(HealthDashboardScreen(
                  token: widget.token ?? ''));
              break;
            case 2:
            // 현재 화면
              break;
            case 3:
              _noAnimReplace(
                  UserMyPageScreen(token: widget.token ?? ''));
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.health_and_safety_outlined),
              label: '건강관리'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_hospital_outlined),
              label: '내 병원'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: '마이페이지'),
        ],
      )
          : null,
    );
  }
}

// ===== 모델/위젯 =====

class _LinkedHospital {
  final String id;
  final String name;
  final DateTime? linkedAt;

  /// 예약 확정이 있을 때만 노출되는 한 줄 요약 텍스트
  final String? nextApptSummary;

  _LinkedHospital({
    required this.id,
    required this.name,
    this.linkedAt,
    this.nextApptSummary,
  });

  _LinkedHospital copyWith({String? nextApptSummary}) {
    return _LinkedHospital(
      id: id,
      name: name,
      linkedAt: linkedAt,
      nextApptSummary: nextApptSummary ?? this.nextApptSummary,
    );
  }
}

class _LinkedHospitalRow extends StatelessWidget {
  final String name;
  final String? nextApptSummary;
  final VoidCallback onMove;

  const _LinkedHospitalRow({
    super.key,
    required this.name,
    required this.nextApptSummary,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding:
          const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (nextApptSummary != null &&
                        nextApptSummary!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          nextApptSummary!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: onMove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('이동',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey.shade300,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  final VoidCallback onConnectTap;

  const _EmptyState(
      {super.key, this.error, required this.onConnectTap});

  @override
  Widget build(BuildContext context) {
    final subtle = Colors.black54;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.local_hospital_outlined,
            size: 56, color: subtle),
        const SizedBox(height: 10),
        Text(
          error == null ? '연동된 병원이 없습니다.' : error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: subtle),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: onConnectTap,
              child: const Text('병원 연동하기'),
            ),
          ),
        ),
      ],
    );
  }
}

//
// ====== 여기부터는 "예약 확정" 판별을 위한 모델/헬퍼들 ======
// (user_myhospital_main.dart 에서 사용하던 로직을 축약해서 재사용)

String statusLabelForUser(String raw) {
  final s = (raw).trim().toLowerCase();
  if (s.contains('approve') ||
      s.contains('confirm') ||
      s.contains('accept') ||
      s == 'ok' ||
      s.contains('확정') ||
      s.contains('승인')) {
    return '예약 확정';
  }
  if (s.contains('reject') ||
      s.contains('deny') ||
      s.contains('cancel') ||
      s.contains('fail') ||
      s.contains('거절') ||
      s.contains('실패') ||
      s.contains('취소')) {
    return '예약 실패';
  }
  return '예약 대기';
}

bool _isApproved(String raw) => statusLabelForUser(raw) == '예약 확정';

class _Appt {
  final String id;
  final DateTime visit;
  final String service;
  final String doctor;
  final String status;
  final String? userName;
  final String? petName;

  _Appt({
    required this.id,
    required this.visit,
    required this.service,
    required this.doctor,
    required this.status,
    this.userName,
    this.petName,
  });

  String get hhmm =>
      '${visit.hour.toString().padLeft(2, '0')}:${visit.minute.toString().padLeft(2, '0')}';

  factory _Appt.fromJson(Map<String, dynamic> m) {
    DateTime? dt;

    final dateStr = (m['date'] ?? '').toString();
    final timeStr = (m['time'] ?? '').toString();
    if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
      dt = _parseLocalDateTime(m);
    }

    if (dt == null) {
      final raw = (m['visitDateTime'] ?? '').toString();
      final parsed = raw.isNotEmpty ? DateTime.tryParse(raw) : null;
      if (parsed != null) {
        dt = parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }

    dt ??= DateTime.now();

    String? _clean(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      if (t == '미입력' ||
          t.toLowerCase() == 'unknown' ||
          t == '사용자/미입력') return null;
      return t;
    }

    return _Appt(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      visit: dt,
      service: (m['service'] ?? '진료').toString(),
      doctor: (m['doctorName'] ?? m['doctor'] ?? '의사').toString(),
      status: (m['status'] ?? 'PENDING').toString(),
      userName:
      _clean((m['userName'] ?? m['clientName'] ?? m['user'])?.toString()),
      petName: _clean((m['petName'] ?? m['pet'])?.toString()),
    );
  }

  static DateTime _parseLocalDateTime(Map<String, dynamic> m) {
    final dateStr = (m['date'] ?? '').toString();
    final timeStr = (m['time'] ?? '00:00').toString();
    final base = DateTime.tryParse(dateStr) ?? DateTime.now();
    final parts = timeStr.split(':');
    final hh = int.tryParse(parts[0]) ?? 0;
    final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(base.year, base.month, base.day, hh, mm);
  }
}
