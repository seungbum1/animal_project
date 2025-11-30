// hospital_mainscreen.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'hospital_patient.dart';

// 👉 문의채팅 화면
import 'hospital_chat_user.dart';

import 'login.dart';
import 'hospital_report.dart';
import 'hospital_notice.dart';
import 'hospital_medical_appointment.dart';
import 'hospital_medical_history.dart';
import 'hospital_sos_user.dart';
import 'hospital_mypage.dart';
import 'hospital_pet_care.dart';

// -------- 공용 상태 라벨 헬퍼 (전역 함수) --------
String statusLabelForView(String? raw) {
  final s = (raw ?? '').trim().toUpperCase();
  if (s.isEmpty) return '';
  if (s.contains('APPROVED') || s.contains('CONFIRM')) return '예약 확정';
  if (s.contains('REJECT')) return '거절됨';
  if (s.contains('PENDING') || s.contains('WAIT') || s.contains('REQUEST')) return '신청/대기';

  // 한글 키워드도 처리
  final sk = (raw ?? '').trim();
  if (sk.contains('확정') || sk.contains('승인')) return '예약 확정';
  if (sk.contains('거절')) return '거절됨';
  if (sk.contains('대기') || sk.contains('신청')) return '신청/대기';

  return raw ?? '';
}

/// 병원 관리자 메인 화면
class HospitalMainScreen extends StatefulWidget {
  const HospitalMainScreen({
    super.key,
    required this.token,
    required this.hospitalName,
  });

  final String token;
  final String hospitalName;

  @override
  State<HospitalMainScreen> createState() => _HospitalMainScreenState();
}

class _HospitalMainScreenState extends State<HospitalMainScreen> {
  int _currentIndex = 0;

  // 문의채팅 미읽음 합계 (FAB 빨간 배지)
  int _chatUnread = 0;
  int _notifUnread = 0;  // 👉 알림 전체(채팅 포함)

  // ----- 서버 연동 상태 -----
  bool _loading = true;
  String? _error;

  // (연동 요청 대기)
  final List<_PendingReq> _pendingList = [];

  // ✅ 예약 목록(캘린더 표시는 승인건만)
  final List<_Appointment> _appointments = [];
  int _apptCountPending = 0; // ← 배지/회색 안내문에 사용하는 값

  // =========================
  // 백엔드 베이스 URL 자동 선택
  // =========================
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  /// 대시보드용 데이터 묶음 로드
  Future<void> _fetchDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) 연동요청 대기 목록
      final reqUri = Uri.parse('$_baseUrl/api/hospital-admin/requests');

      // 2) 예약 목록(전체) – 달력 표시 + ‘대기 건수’ 계산
      final apptUri = Uri.parse('$_baseUrl/api/hospital-admin/appointments');

      // 3) 문의채팅 스레드 목록(관리자측)
      final threadUri = Uri.parse('$_baseUrl/api/hospital-admin/chat/threads');

      final results = await Future.wait([
        _http.get(reqUri,    headers: {'Authorization': 'Bearer ${widget.token}'}).timeout(_timeout),
        _http.get(apptUri,   headers: {'Authorization': 'Bearer ${widget.token}'}).timeout(_timeout),
        _http.get(threadUri, headers: {'Authorization': 'Bearer ${widget.token}'}).timeout(_timeout),
      ]);

      // 공통 인증 만료 처리
      for (final res in results) {
        if (res.statusCode == 401) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
          );
          return;
        }
      }

      // ── 연동요청 목록 ──
      final resReq = results[0];
      if (resReq.statusCode == 200) {
        final body = jsonDecode(resReq.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);
        _pendingList
          ..clear()
          ..addAll(list.map((e) => _PendingReq.fromJson(e)));
      } else {
        _error = '요청 목록 불러오기 실패 (${resReq.statusCode})';
      }

      // ── 예약 목록(전체) + ‘대기’ 집계 + 캘린더는 승인건만 ──
      final resAppt = results[1];
      if (resAppt.statusCode == 200) {
        final body = jsonDecode(resAppt.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);
        final parsedAll = list
            .map((e) => _Appointment.fromJsonFlex(e))
            .whereType<_Appointment>()
            .toList();

        _apptCountPending = parsedAll.where((a) => _isPendingStatus(a.status)).length;

        _appointments
          ..clear()
          ..addAll(parsedAll.where((a) => _isApprovedStatus(a.status)));
      } else {
        _appointments.clear();
        _apptCountPending = 0;
      }

      // ── 문의채팅 미읽음 합계 ──
      final resThreads = results[2];
      if (resThreads.statusCode == 200) {
        final body = jsonDecode(resThreads.body);
        final List list = (body is Map && body['data'] is List)
            ? body['data']
            : (body as List? ?? const []);
        int sum = 0;
        for (final e in list) {
          final u = (e is Map && e['unread'] != null)
              ? int.tryParse(e['unread'].toString()) ?? 0
              : 0;
          sum += u;
        }
        _chatUnread = sum;
      } else {
        _chatUnread = 0;
      }

      // ✅ 알림 전체(벨): 채팅 + 예약 ‘대기’ + (있다면) 기타 시스템 알림
      int systemUnread = 0;
// 만약 서버에 별도 엔드포인트가 있으면 여기에 호출/파싱해서 systemUnread 갱신.
// 예) GET /api/hospital-admin/notifications/unread-count  → systemUnread = body['count'] ?? 0;

// 승인 대기(연동요청) 알림성을 포함하려면:
      final pendingRequestCount = _pendingList.length;
// 예약 ‘대기’ 건수 포함(이미 _apptCountPending 계산됨):
      final pendingApptCount = _apptCountPending;

// 👉 최종 알림 합계 (정책에 맞게 가감)
      _notifUnread = _chatUnread + pendingRequestCount + pendingApptCount + systemUnread;

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '네트워크 오류: $e';
      });
    }
  }

  // 상태가 ‘예약 신청/대기’인지 판별 (백엔드 표기 다양성 대응)
  bool _isPendingStatus(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty) return false;
    const pendingKeys = [
      'pending', 'requested', 'request', 'wait', 'waiting', 'hold', 'onhold',
      'pending_approval', 'to_approve', '0',
    ];
    const pendingKo = ['대기', '예약대기', '신청', '신청중', '미확정', '확인대기', '승인대기'];
    return pendingKeys.any((k) => s.contains(k)) || pendingKo.any((k) => s.contains(k));
  }

  // ✅ 승인 상태 판별 (캘린더 필터에 사용)
  bool _isApprovedStatus(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty) return false;
    const approvedKeys = ['approved', 'confirm', 'confirmed', 'accepted', 'ok'];
    const approvedKo = ['승인', '확정', '예약확정'];
    return approvedKeys.any((k) => s.contains(k)) || approvedKo.any((k) => s.contains(k));
  }

  // 승인/거절 공통 호출 (연동요청)
  Future<void> _decide({
    required _PendingReq req,
    required bool approve,
  }) async {
    final int idx = _pendingList.indexWhere((r) => r.id == req.id);
    if (idx < 0) return;

    final removed = _pendingList.removeAt(idx);
    setState(() {});

    try {
      final path = approve ? 'approve' : 'reject';
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/requests/${req.id}/$path');
      final res = await _http
          .post(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      })
          .timeout(_timeout);

      if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
        return;
      }

      if (res.statusCode == 200) {
        _toast(approve ? '승인 완료' : '거절 완료');
      } else {
        _pendingList.insert(idx, removed);
        setState(() {});
        _toast('처리 실패 (${res.statusCode})');
      }
    } catch (_) {
      _pendingList.insert(idx, removed);
      setState(() {});
      _toast('네트워크 오류로 처리 실패');
    }
  }

  // 문의채팅으로 이동
  void _goChat() {
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => HospitalChatUserListScreen( // hospital_chat_user.dart의 리스트 화면
        token: widget.token,
        hospitalName: widget.hospitalName,
      ),
    ))
        .then((_) => _fetchDashboardData()); // 돌아오면 배지 갱신
  }

  // 예약함으로 이동
  void _goAppointmentInbox() {
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => HospitalMedicalAppointmentScreen(
        token: widget.token,
        hospitalName: widget.hospitalName,
      ),
    ))
        .then((_) => _fetchDashboardData());
  }

  // ---- 하단 네비게이션 이동 ----
  void _onTapBottomNav(int i) {
    setState(() => _currentIndex = i);
    switch (i) {
      case 0:
        break;
      case 1: // ✅ 환자관리
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalPatientManageScreen( // ← 실제 환자관리 화면으로
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        // 임시로 쓰고 싶으면 아래 중 하나로 교체
        // builder: (_) => HospitalPetCareListScreen(token: widget.token, hospitalName: widget.hospitalName),
        // builder: (_) => HospitalSosUserScreen(token: widget.token, hospitalName: widget.hospitalName),

        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalMedicalHistoryScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalSosUserScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalMyPageScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 회색 안내문: “대기(신청) 건수만”
    final reserveNotice = _loading
        ? '불러오는 중...'
        : (_apptCountPending > 0
        ? '진료 예약 신청이 $_apptCountPending건 있습니다.'
        : '현재 접수된 진료 예약 신청이 없습니다.');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.hospitalName,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: '메뉴',
          ),
        ),
      ),

      // ✅ 드로어 교체: 입원 케어 일지 메뉴 포함 + 네비게이션
      drawer: _AdminDrawer(
        token: widget.token,
        hospitalName: widget.hospitalName,
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ① 진료 예약 신청 내역 헤더 (배지 + > 이동)
                InkWell(
                  onTap: _goAppointmentInbox,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                '진료 예약 신청 내역',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              if (_loading)
                                const _BadgeSkeleton()
                              else
                                _PendingBadge(count: _apptCountPending),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 회색 안내 바 – ‘신청/대기’ 건수만 표기
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    reserveNotice,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
                  ),
                ),

                const SizedBox(height: 22),

                // ② 병원 스케줄 (읽기 전용 캘린더) – ✅ 승인된 예약만 표시
                Text(
                  '병원 스케줄을 간편하게 확인하고 관리하세요.',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                _CalendarReadOnly(
                  items: _appointments,
                  onRefresh: _fetchDashboardData,
                ),

                const SizedBox(height: 24),

                // ③ 승인 관리 (연동요청)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '승인 관리로 병원 업무를 간편하게 운영하세요.',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _goAppointmentInbox,
                      child: const Text('확인하기 >'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildApprovalCardBody(theme),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),

      // 👉 오른쪽 하단 “문의채팅” FAB + 미읽음 배지
      floatingActionButton: _ChatFab(
        unread: _chatUnread,
        onTap: _goChat,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTapBottomNav,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: '환자관리'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: '진료내역'),
          BottomNavigationBarItem(icon: Icon(Icons.sos_outlined), label: '긴급호출'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }

  Widget _buildApprovalCardBody(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 불러오기'),
              ),
            ),
          ],
        ),
      );
    }
    if (_pendingList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text('승인 대기 요청이 없습니다.', style: TextStyle(color: Colors.black54)),
      );
    }

    return Column(
      children: _pendingList
          .map((e) => _ApprovalRow(
        nameAndPet: '${e.userName}/${e.petName}'
            .trim()
            .replaceAll(RegExp(r'^/|/$'), ''),
        onApprove: () => _decide(req: e, approve: true),
        onReject: () => _decide(req: e, approve: false),
      ))
          .toList(),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }
}

class _ChatFab extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;
  const _ChatFab({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 배지 포지셔닝을 위해 Stack으로 한 번 감싼다
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton.extended(
          onPressed: onTap,
          label: const Text('문의채팅'),
          icon: const Icon(Icons.chat_bubble_outline),
          backgroundColor: const Color(0xFF222222),
          foregroundColor: Colors.white,
        ),
        if (unread > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935), // 빨간 배경
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ==============================
/// 위젯/모델 영역
/// ==============================

/// ✅ 배지 위젯 (건수 표시)
class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF5B5CE2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 배지 로딩 스켈레톤
class _BadgeSkeleton extends StatelessWidget {
  const _BadgeSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 16,
      margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// 승인 대기 항목 모델 (연동요청)
class _PendingReq {
  final String id;
  final String userName;
  final String petName;
  final DateTime? createdAt;

  _PendingReq({
    required this.id,
    required this.userName,
    required this.petName,
    this.createdAt,
  });

  factory _PendingReq.fromJson(Map<String, dynamic> j) => _PendingReq(
    id: (j['_id'] ?? '').toString(),
    userName: (j['userName'] ?? '').toString(),
    petName: (j['petName'] ?? '').toString(),
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
  );
}

/// 승인 항목 한 줄 UI (연동요청)
class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.nameAndPet,
    required this.onApprove,
    required this.onReject,
  });

  final String nameAndPet;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nameAndPet.isEmpty ? '신청자' : nameAndPet,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onApprove,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF4A7BFF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('승인'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onReject,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFFE86161),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }
}

/// 캘린더에서 사용할 예약 모델 (읽기 전용)
class _Appointment {
  final String id;
  final DateTime date;
  final String title;
  final String? userName;
  final String? petName;
  final String? status;

  _Appointment({
    required this.id,
    required this.date,
    required this.title,
    this.userName,
    this.petName,
    this.status,
  });

  /// 백엔드 키가 제각각이어도 최대한 유연하게 파싱
  static _Appointment? fromJsonFlex(Map<String, dynamic> j) {
    DateTime? d = _readDate(j);
    if (d == null) return null;

    String pickString(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    return _Appointment(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      date: d,
      title: pickString(['category', 'medicalType', 'treatment', 'subject', 'title', 'memo']),
      userName: pickString(['userName', 'user', 'clientName']),
      petName: pickString(['petName', 'pet']),
      status: pickString(['status', 'state']),
    );
  }

  // 다양한 날짜 필드 지원
  static DateTime? _readDate(Map<String, dynamic> j) {
    final candidates = [
      'visitDateTime', // 백엔드 표준
      'date',          // 호환
      'reservedDate',
      'appointmentDate',
      'startAt',
      'reservationAt',
      'datetime',
      'time',
    ];
    for (final k in candidates) {
      final v = j[k];
      if (v == null) continue;
      if (v is int) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(v);
        } catch (_) {}
      }
      final s = v.toString();
      final d = DateTime.tryParse(s);
      if (d != null) return d;
    }
    return null;
  }
}

/// 읽기 전용 캘린더 위젯 (월 이동 + 도트 표시 + 바텀시트 목록)
class _CalendarReadOnly extends StatefulWidget {
  const _CalendarReadOnly({
    required this.items,
    required this.onRefresh,
  });

  final List<_Appointment> items;
  final Future<void> Function() onRefresh;

  @override
  State<_CalendarReadOnly> createState() => _CalendarReadOnlyState();
}

class _CalendarReadOnlyState extends State<_CalendarReadOnly> {
  late DateTime _cursor; // 현재 보이는 달 (1일 기준)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cursor = DateTime(now.year, now.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month + 1, 1);
    });
  }

  List<_Appointment> _itemsOn(DateTime day) {
    return widget.items.where((e) =>
    e.date.year == day.year &&
        e.date.month == day.month &&
        e.date.day == day.day).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstWeekday = DateTime(_cursor.year, _cursor.month, 1).weekday; // 1(Mon)~7(Sun)
    final daysInMonth = DateTime(_cursor.year, _cursor.month + 1, 0).day;

    // 월 시작 앞부분 공백(월요일 시작 기준)
    final leading = (firstWeekday + 6) % 7; // 월:0, 화:1 ... 일:6
    final totalCells = leading + daysInMonth;
    final rows = ((totalCells + 6) ~/ 7).clamp(5, 6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_cursor.year}년 ${_cursor.month}월',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 요일
          Row(
            children: const [
              _Dow('월'), _Dow('화'), _Dow('수'), _Dow('목'), _Dow('금'), _Dow('토'), _Dow('일'),
            ],
          ),
          const SizedBox(height: 4),
          // 그리드
          for (int r = 0; r < rows; r++)
            Row(
              children: [
                for (int c = 0; c < 7; c++)
                  _buildCell(leading, daysInMonth, r * 7 + c),
              ],
            ),
          const SizedBox(height: 8),
          // 새로고침
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int leading, int daysInMonth, int index) {
    final theme = Theme.of(context);
    final dayNum = index - leading + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const Expanded(child: SizedBox(height: 52));
    }

    final dayDate = DateTime(_cursor.year, _cursor.month, dayNum);
    final list = _itemsOn(dayDate);
    final hasAppt = list.isNotEmpty;

    return Expanded(
      child: InkWell(
        onTap: hasAppt
            ? () {
          _showApptSheet(dayDate, list);
        }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 52,
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hasAppt ? const Color(0xFFF6F7FF) : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFECECEC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$dayNum', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (hasAppt)
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 2, right: 2),
                    child: Text('•', style: TextStyle(fontSize: 20, height: .8, color: Color(0xFF5B5CE2))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApptSheet(DateTime day, List<_Appointment> list) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${day.year}년 ${day.month}월 ${day.day}일',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('해당 날짜의 예약이 없습니다.')),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final a = list[i];
                        final hh = a.date.hour.toString().padLeft(2, '0');
                        final mm = a.date.minute.toString().padLeft(2, '0');
                        final who = [
                          if ((a.userName ?? '').isNotEmpty) a.userName!,
                          if ((a.petName ?? '').isNotEmpty) a.petName!,
                        ].join(' / ');
                        final statusText = statusLabelForView(a.status);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(a.title.isEmpty ? '진료 예약' : a.title),
                          subtitle: Text([
                            '$hh:$mm',
                            if (who.isNotEmpty) who,
                            if (statusText.isNotEmpty) '상태: $statusText',
                          ].join(' • ')),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Dow extends StatelessWidget {
  const _Dow(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 24,
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
      ),
    );
  }
}

/// ✅ 관리자 드로어: ‘입원 케어 일지’ 포함
class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.token,
    required this.hospitalName,
  });

  final String token;
  final String hospitalName;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFFFF2B6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('관리자 메뉴',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('진료예약'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HospitalMedicalAppointmentScreen(
                    token: token,
                    hospitalName: hospitalName,
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('진료내역'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HospitalMedicalHistoryScreen(
                    token: token,
                    hospitalName: hospitalName,
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sos_outlined),
              title: const Text('긴급호출'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HospitalSosUserScreen(
                    token: token,
                    hospitalName: hospitalName,
                  ),
                ));
              },
            ),

            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('환자관리'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HospitalSosUserScreen(
                    token: token,
                    hospitalName: hospitalName,
                  ),
                ));
              },
            ),

            // ✅ 신규: 입원 케어 일지
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('입원 케어 일지'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HospitalPetCareListScreen(
                    token: token,
                    hospitalName: hospitalName,
                  ),
                ));
              },
            ),

            // 공지사항 작성
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('공지사항'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HospitalNoticeScreen(
                    token: token,
                    hospitalName: hospitalName,
                  ),
                ));
              },
            ),

            // 마이페이지 이동
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('마이페이지'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HospitalMyPageScreen(
                    token: token,
                    hospitalName: hospitalName,
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
