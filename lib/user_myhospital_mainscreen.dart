// user_myhospital_main.dart  (UserMyHospitalMainScreen)
// 1) 우하단 "문의채팅" 플로팅 말풍선 FAB로 교체
// 2) 상단 알림 뱃지/공지/달력/미리보기 등 기존 기능 유지
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'user_mainscreen.dart';
import 'user_myhospital_list.dart';
import 'user_medical_appointment.dart';
import 'user_medical_history.dart';
import 'user_pet_picture.dart';
import 'user_chat_hospital.dart';
import 'hospital_notification.dart';
import 'user_health_main.dart';

class UserMyHospitalMainScreen extends StatefulWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;

  const UserMyHospitalMainScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
  });

  @override
  State<UserMyHospitalMainScreen> createState() =>
      _UserMyHospitalMainScreenState();
}

class _UserMyHospitalMainScreenState extends State<UserMyHospitalMainScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final _http = http.Client();
  Duration _timeout = const Duration(seconds: 8);

  bool _loading = true;
  String? _error;
  String _notice = '';

  String _dashboardNextApptText = '';
  String _computedNextApptText = '';

  DateTime _calMonth =
  DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, List<_Appt>> _apptsByDate = {};

  // 반려 사진 미리보기
  bool _loadingPetPreview = true;
  List<_PetPreview> _petPreview = [];

  // 알림/채팅 공용 뱃지
  int _unreadCount = 0;
  Timer? _badgeTimer;

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
    _loadAll();
    _loadUnreadCount();
    _badgeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _http.close();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadHospitalNotice(),
      _loadMonthlyAppointments(_calMonth),
      _loadPetPreview(),
    ]);
    _refreshNextApptFromMap();
  }

  // 공지
  Future<void> _loadHospitalNotice() async {
    if (mounted) setState(() => _loading = true);
    try {
      final uri = Uri.parse('$_baseUrl/api/hospitals/${widget.hospitalId}/notice');
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final noticeText = (data['notice'] ?? data['message'] ?? '').toString();
        if (mounted) {
          setState(() {
            _notice = noticeText.trim().isEmpty ? '공지 없음' : noticeText.trim();
            _loading = false;
          });
        }
      } else {
        _useFallback('(${res.statusCode}) 서버 응답 오류');
      }
    } catch (e) {
      _useFallback(e.toString());
    }
  }

  // 미확인 알림/채팅 카운트
  Future<void> _loadUnreadCount() async {
    try {
      final uri = Uri.parse(
          '$_baseUrl/api/users/me/notifications/unread-count?hospitalId=${widget.hospitalId}');
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final c = (body is Map && body['count'] is num)
            ? (body['count'] as num).toInt()
            : 0;
        setState(() => _unreadCount = c);
      } else {
        setState(() => _unreadCount = 0);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadCount = 0);
    }
  }

  // 사진 미리보기
  Future<void> _loadPetPreview() async {
    setState(() {
      _loadingPetPreview = true;
      _petPreview = [];
    });
    try {
      final uri = Uri.parse(
          '$_baseUrl/api/users/me/pet-care?hospitalId=${widget.hospitalId}&sort=dateDesc&limit=10');
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list =
        (body is Map && body['data'] is List) ? body['data'] : [];
        final parsed = list
            .map((e) => _PetPreview.fromJson(
            (e as Map).cast<String, dynamic>()))
            .toList();
        if (!mounted) return;
        setState(() {
          _petPreview = parsed;
          _loadingPetPreview = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingPetPreview = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPetPreview = false);
    }
  }

  Future<void> _loadMonthlyAppointments(DateTime month) async {
    if (mounted) setState(() => _apptsByDate.clear());
    final y = month.year;
    final m = month.month.toString().padLeft(2, '0');
    try {
      final uri = Uri.parse(
          '$_baseUrl/api/users/me/appointments/monthly?month=$y-$m&hospitalId=${widget.hospitalId}');
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List?) ?? [];
        final parsed = list
            .map((e) => _Appt.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        if (mounted) {
          setState(() => _apptsByDate = _groupByDate(parsed));
          _refreshNextApptFromMap();
        }
      } else {
        if (mounted) setState(() => _apptsByDate = {});
      }
    } catch (_) {
      if (mounted) setState(() => _apptsByDate = {});
    }
  }

  Map<String, List<_Appt>> _groupByDate(List<_Appt> list) {
    final map = <String, List<_Appt>>{};
    for (final a in list) {
      map.putIfAbsent(a.dateKey, () => []).add(a);
    }
    for (final v in map.values) {
      v.sort((a, b) => a.visit.compareTo(b.visit));
    }
    return map;
  }

  void _refreshNextApptFromMap() {
    final now = DateTime.now();
    final all = _apptsByDate.values.expand((e) => e).toList()
      ..sort((a, b) => a.visit.compareTo(b.visit));

    final upcoming = all.firstWhere(
          (a) => _isApproved(a.status) && !a.visit.isBefore(now),
      orElse: () => _Appt.empty(),
    );

    String computed = '';
    if (!upcoming.isEmpty) {
      final d =
          '${upcoming.visit.year}/${upcoming.visit.month.toString().padLeft(2, '0')}/${upcoming.visit.day.toString().padLeft(2, '0')}';
      final who = [
        if ((upcoming.userName ?? '').isNotEmpty) upcoming.userName!,
        if ((upcoming.petName ?? '').isNotEmpty) upcoming.petName!,
        if ((upcoming.doctor).isNotEmpty) upcoming.doctor,
      ].join(' / ');
      computed =
      '$d ${upcoming.hhmm} · ${upcoming.service}${who.isNotEmpty ? ' ($who)' : ''}';
    }

    if (mounted) {
      setState(() {
        _computedNextApptText = computed;
      });
    }
  }

  void _useFallback(String? err) {
    if (!mounted) return;
    setState(() {
      _error = err;
      _notice = '병원 공지사항 : ${widget.hospitalName} 휴무일은 매주 일요일입니다.';
      _dashboardNextApptText = '9/08 (월) : 초음파 검사';
      _loading = false;
    });
  }

  void _goNoAnim(Widget page) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  Future<bool> _openAppointment({DateTime? initialDate}) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserMedicalAppointmentScreen(
          token: widget.token,
          hospitalId: widget.hospitalId,
          hospitalName: widget.hospitalName,
        ),
        settings: RouteSettings(
          arguments: {'initialDate': initialDate},
        ),
      ),
    ) ??
        false;
    await _loadAll();
    return created;
  }

  void _openMedicalHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserMedicalHistoryScreen(
          token: widget.token,
          hospitalId: widget.hospitalId,
          hospitalName: widget.hospitalName,
        ),
      ),
    );
  }

  void _openPetPictures() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserPetPictureScreen(
          token: widget.token,
          hospitalId: widget.hospitalId,
          hospitalName: widget.hospitalName,
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserChatHospitalScreen(
          token: widget.token,
          hospitalId: widget.hospitalId,
          hospitalName: widget.hospitalName,
        ),
      ),
    ).then((_) => _loadUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8);
    final nextApptText =
    _computedNextApptText.isNotEmpty ? _computedNextApptText : _dashboardNextApptText;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: topYellow,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(widget.hospitalName,
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.w600)),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          // 상단 알림함 + 뱃지
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => UserNotificationsScreen(
                  token: widget.token,
                  hospitalId: widget.hospitalId,
                  hospitalName: widget.hospitalName,
                ),
              ));
              _loadUnreadCount();
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                if (_unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const _DrawerHeader(),
              _DrawerTile(
                icon: Icons.receipt_long_outlined,
                title: '진료 내역',
                onTap: () {
                  Navigator.pop(context);
                  _openMedicalHistory();
                },
              ),
              _DrawerTile(
                icon: Icons.event_available,
                title: '진료 예약',
                onTap: () {
                  Navigator.pop(context);
                  _openAppointment();
                },
              ),
              _DrawerTile(
                icon: Icons.image_outlined,
                title: '반려 일지',
                onTap: () {
                  Navigator.pop(context);
                  _openPetPictures();
                },
              ),
              const _DrawerTile(icon: Icons.settings_outlined, title: '설정'),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BannerNotice(
                    loading: _loading,
                    text: _notice.isEmpty ? '공지 없음' : _notice),
                const SizedBox(height: 12),

                Center(
                  child: OutlinedButton(
                    onPressed: () => _openAppointment(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: Colors.black54),
                    ),
                    child: const Text('진료 예약 일정 안내'),
                  ),
                ),
                const SizedBox(height: 12),

                // “다가오는 확정 예약” (요약)
                _ApprovedOnlyNotice(apptsByDate: _apptsByDate),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade400),
                const SizedBox(height: 12),

                // ===== 사진 미리보기 + 더보기 =====
                Row(
                  children: [
                    Text(_formatToday(),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    InkWell(
                      onTap: _openPetPictures,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Text('더보기',
                            style: TextStyle(
                                decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                SizedBox(
                  height: 170,
                  child: _loadingPetPreview
                      ? _PreviewSkeleton()
                      : (_petPreview.isEmpty)
                      ? _PreviewEmpty(onTap: _openPetPictures)
                      : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, i) {
                      final p = _petPreview[i];
                      return _PreviewCard(
                        preview: p,
                        onTap: _openPetPictures,
                      );
                    },
                    separatorBuilder: (_, __) =>
                    const SizedBox(width: 10),
                    itemCount: _petPreview.length,
                  ),
                ),

                const SizedBox(height: 16),

                // ===== 아이콘 타일 =====
                Row(
                  children: [
                    Expanded(
                      child: _IconTile(
                        label: '진료 내역',
                        icon: Icons.receipt_long_outlined,
                        bgColor: const Color(0xFFEFF4FF),
                        onTap: _openMedicalHistory,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _IconTile(
                        label: '진료 예약',
                        icon: Icons.event_available,
                        bgColor: const Color(0xFFFFF1E8),
                        onTap: () => _openAppointment(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Center(
                  child: Text('병원 스케줄 관리',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),

                // ===== 달력 =====
                _ScheduleMemoCalendar(
                  month: _calMonth,
                  apptsByDate: _apptsByDate,
                  onChangeMonth: (m) async {
                    setState(() => _calMonth = m);
                    await _loadMonthlyAppointments(m);
                  },
                  onTapDay: (date, items) {
                    _openDaySheet(date, items);
                  },
                ),

                const SizedBox(height: 24),
                // (기존의 노란 "1:1 채팅 문의" 버튼은 제거되었습니다.)
              ],
            ),
          ),
        ),
      ),

      // ───────── 우하단 말풍선형 문의채팅 FAB ─────────
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _ChatBubbleFab(
        unreadCount: _unreadCount,
        onTap: _openChat,
      ),

        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: 2, // ✅ ‘내 병원’ 탭
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black45,
          onTap: (i) {
            switch (i) {
              case 0:
                _noAnimReplace(PetHomeScreen(token: widget.token));
                break;
              case 1:
                _noAnimReplace(HealthDashboardScreen(token: widget.token));
                break;
              case 2:
              // 현재 화면
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
        )
    );
  }

  String _formatToday() {
    final now = DateTime.now();
    return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  // 날짜 클릭 시 바텀시트
  void _openDaySheet(DateTime date, List<_Appt> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromRGBO(249, 246, 255, 0.98),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _MainDaySheet(
        date: date,
        items: items,
        onAdd: () async {
          Navigator.pop(ctx);
          await _openAppointment(initialDate: date);
        },
        onCancel: (a) async {
          final ok = await showDialog<bool>(
            context: ctx,
            builder: (_) =>
            const _ConfirmDialog(text: '해당 날짜의 예약을 취소하시겠습니까?'),
          ) ??
              false;
          if (!ok) return false;

          final success = await _deleteAppt(a.id);

          if (!ctx.mounted) return success;

          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(success ? '예약이 취소되었습니다.' : '취소 실패'),
            duration: const Duration(milliseconds: 1200),
          ));

          if (success) {
            Navigator.pop(ctx);
            await _loadAll();
          }
          return success;
        },
        onRebook: (a) async {
          final success = await _rebookAndDelete(a);
          if (!ctx.mounted) return success;
          if (success) {
            Navigator.pop(ctx);
          }
          return success;
        },
      ),
    );
  }

  // 삭제/재예약
  Future<bool> _deleteAppt(String apptId) async {
    Future<http.Response> _try(String path, {bool withHospital = false}) {
      final uri = Uri.parse('$_baseUrl$path' +
          (withHospital ? '?hospitalId=${widget.hospitalId}' : ''));
      return _http
          .delete(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);
    }

    try {
      var res = await _try('/api/appointments/$apptId');
      if (res.statusCode == 200 || res.statusCode == 204) return true;

      res = await _try('/api/users/me/appointments/$apptId');
      if (res.statusCode == 200 || res.statusCode == 204) return true;

      res = await _try('/api/users/me/appointments/$apptId',
          withHospital: true);
      if (res.statusCode == 200 || res.statusCode == 204) return true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('삭제 실패 (${res.statusCode}) ${res.body}'),
          duration: const Duration(milliseconds: 1800),
        ));
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('삭제 에러: $e'),
          duration: const Duration(milliseconds: 1800),
        ));
      }
      return false;
    }
  }

  Future<bool> _rebookAndDelete(_Appt a) async {
    final created = await _openAppointment(initialDate: a.visit);
    if (!created) return false;

    final ok = await _deleteAppt(a.id);
    if (ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('새 예약 완료 · 기존 예약 삭제됨'),
          duration: Duration(milliseconds: 1200),
        ));
      }
      await _loadAll();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('새 예약은 완료했지만 기존 예약 삭제 실패'),
          duration: Duration(milliseconds: 1400),
        ));
      }
    }
    return ok;
  }
}

// 상태/라벨 헬퍼
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
bool _isRejected(String raw) => statusLabelForUser(raw) == '예약 실패';

// 모델
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

  String get dateKey {
    final y = visit.year.toString();
    final m = visit.month.toString().padLeft(2, '0');
    final d = visit.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get hhmm =>
      '${visit.hour.toString().padLeft(2, '0')}:${visit.minute.toString().padLeft(2, '0')}';

  bool get isEmpty => id.isEmpty;
  static _Appt empty() => _Appt(
    id: '',
    visit: DateTime.fromMillisecondsSinceEpoch(0),
    service: '',
    doctor: '',
    status: '',
  );

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
      if (parsed != null) dt = parsed.isUtc ? parsed.toLocal() : parsed;
    }

    dt ??= DateTime.now();

    String? _clean(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      if (t == '미입력' || t.toLowerCase() == 'unknown' || t == '사용자/미입력') return null;
      return t;
    }

    return _Appt(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      visit: dt,
      service: (m['service'] ?? '진료').toString(),
      doctor: (m['doctorName'] ?? m['doctor'] ?? '의사').toString(),
      status: (m['status'] ?? 'PENDING').toString(),
      userName: _clean((m['userName'] ?? m['clientName'] ?? m['user'])?.toString()),
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

// 사진 미리보기 모델
class _PetPreview {
  final String id;
  final String imageUrl;
  final DateTime createdAt;
  final String memo;

  _PetPreview({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
    required this.memo,
  });

  factory _PetPreview.fromJson(Map<String, dynamic> m) {
    DateTime dt = DateTime.now();
    final candidates = [
      m['dateTime'],
      m['createdAt'],
      m['updatedAt'],
      m['date'],
    ].where((e) => e != null).map((e) => e.toString());
    for (final s in candidates) {
      final p = DateTime.tryParse(s);
      if (p != null) {
        dt = p.isUtc ? p.toLocal() : p;
        break;
      }
    }

    String img = (m['imageUrl'] ?? '').toString();
    if (img.isEmpty && m['images'] is List && (m['images'] as List).isNotEmpty) {
      img = ((m['images'] as List).first ?? '').toString();
    }

    return _PetPreview(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      imageUrl: img,
      createdAt: dt,
      memo: (m['memo'] ?? '').toString(),
    );
  }
}

// 바텀시트/확인창
class _MainDaySheet extends StatefulWidget {
  final DateTime date;
  final List<_Appt> items;
  final Future<void> Function() onAdd;
  final Future<bool> Function(_Appt a) onCancel;
  final Future<bool> Function(_Appt a) onRebook;

  const _MainDaySheet({
    required this.date,
    required this.items,
    required this.onAdd,
    required this.onCancel,
    required this.onRebook,
  });

  @override
  State<_MainDaySheet> createState() => _MainDaySheetState();
}

class _MainDaySheetState extends State<_MainDaySheet> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final ymd =
        '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999)),
            ),
            Text('$ymd 일정',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),

            if (widget.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('등록된 예약이 없습니다.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              )
            else
              ...widget.items.expand((a) {
                final expanded = _expandedId == a.id;
                final label = statusLabelForUser(a.status);

                final who = [
                  if ((a.userName ?? '').isNotEmpty) a.userName!,
                  if ((a.petName ?? '').isNotEmpty) a.petName!,
                  if (a.doctor.isNotEmpty) a.doctor,
                ].join(' / ');

                return [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE7E4EC)),
                      color: Colors.white,
                    ),
                    child: ListTile(
                      title: Text('${a.service} - ${a.hhmm}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        [
                          if (who.isNotEmpty) who,
                          label,
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusChip(label: label),
                          const SizedBox(width: 6),
                          Icon(expanded ? Icons.expand_less : Icons.expand_more,
                              size: 24),
                        ],
                      ),
                      onTap: () =>
                          setState(() => _expandedId = expanded ? null : a.id),
                    ),
                  ),

                  if (expanded)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE7E4EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('예약 내역',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 8),
                          _dotLine('진료 항목', a.service),
                          _dotLine('시간', a.hhmm),
                          if (who.isNotEmpty) _dotLine('정보', who),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final ok = await widget.onRebook(a);
                                    if (ok && mounted) {}
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: const BorderSide(color: Colors.black26),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('예약변경'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final ok = await widget.onCancel(a);
                                    if (ok && mounted) {}
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black87,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('취소하기'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ];
              }).toList(),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onAdd,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Colors.black26),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('예약 추가'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dotLine(String k, Object? v) {
    final value = (v == null) ? '-' : v.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8),
          ),
          const SizedBox(width: 8),
          Text('$k  ', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String text;
  const _ConfirmDialog({required this.text});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFF4B8),
              foregroundColor: Colors.black87,
              elevation: 0),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

// “확정만” 공지 리스트
class _ApprovedOnlyNotice extends StatelessWidget {
  final Map<String, List<_Appt>> apptsByDate;
  const _ApprovedOnlyNotice({required this.apptsByDate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final approvedUpcoming = apptsByDate.values
        .expand((e) => e)
        .where((a) => _isApproved(a.status) && a.visit.isAfter(now))
        .toList()
      ..sort((a, b) => a.visit.compareTo(b.visit));

    final list = approvedUpcoming.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      child: list.isEmpty
          ? Text('확정된 예약이 없습니다.',
          style:
          theme.textTheme.bodyMedium?.copyWith(color: Colors.black54))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list.map((a) {
          final y = a.visit.year;
          final m = a.visit.month.toString().padLeft(2, '0');
          final d = a.visit.day.toString().padLeft(2, '0');
          final who = [
            if ((a.userName ?? '').isNotEmpty) a.userName!,
            if ((a.petName ?? '').isNotEmpty) a.petName!,
            if (a.doctor.isNotEmpty) a.doctor,
          ].join(' / ');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.event_available,
                    size: 18, color: Color(0xFF4A7BFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$y-$m-$d ${a.hhmm}  ${a.service}'
                        '${who.isNotEmpty ? ' • $who' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const _StatusChip(label: '예약 확정'),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 달력
class _ScheduleMemoCalendar extends StatelessWidget {
  const _ScheduleMemoCalendar({
    required this.month,
    required this.apptsByDate,
    required this.onChangeMonth,
    required this.onTapDay,
  });

  final DateTime month; // 1일 기준
  final Map<String, List<_Appt>> apptsByDate;
  final ValueChanged<DateTime> onChangeMonth;
  final void Function(DateTime, List<_Appt>) onTapDay;

  @override
  Widget build(BuildContext context) {
    final ym = DateTime(month.year, month.month);
    final first = DateTime(ym.year, ym.month, 1);
    final daysInMonth = DateTime(ym.year, ym.month + 1, 0).day;

    final firstWeekday = first.weekday; // 1=Mon…7=Sun
    final leading = (firstWeekday + 6) % 7; // Mon:0 … Sun:6

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
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final prev = DateTime(ym.year, ym.month - 1, 1);
                  onChangeMonth(prev);
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${ym.year}년 ${ym.month}월',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final next = DateTime(ym.year, ym.month + 1, 1);
                  onChangeMonth(next);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 요일 영역 숨김
          Row(
            children: const [
              _Dow('월'), _Dow('화'), _Dow('수'), _Dow('목'), _Dow('금'), _Dow('토'), _Dow('일'),
            ],
          ),
          const SizedBox(height: 4),

          for (int r = 0; r < rows; r++)
            Row(
              children: [
                for (int c = 0; c < 7; c++)
                  _CalendarCell(
                    ym: ym,
                    leading: leading,
                    index: r * 7 + c,
                    daysInMonth: daysInMonth,
                    apptsByDate: apptsByDate,
                    onTapDay: onTapDay,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.ym,
    required this.leading,
    required this.index,
    required this.daysInMonth,
    required this.apptsByDate,
    required this.onTapDay,
  });

  final DateTime ym;
  final int leading;
  final int index;
  final int daysInMonth;
  final Map<String, List<_Appt>> apptsByDate;
  final void Function(DateTime, List<_Appt>) onTapDay;

  @override
  Widget build(BuildContext context) {
    final dayNum = index - leading + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const Expanded(child: SizedBox(height: 52));
    }

    final date = DateTime(ym.year, ym.month, dayNum);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final list = apptsByDate[key] ?? const <_Appt>[];

    // 오늘 이전 날짜 비활성화
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final isPast = date.isBefore(todayStart);

    final hasAppt = list.isNotEmpty;

    return Expanded(
      child: InkWell(
        onTap: isPast ? null : () => onTapDay(date, list),
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: isPast ? 0.4 : 1.0,
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
                Text(
                  '$dayNum',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isPast ? Colors.grey : Colors.black,
                  ),
                ),
                const Spacer(),
                if (hasAppt)
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2, right: 2),
                      child: Text('•',
                          style: TextStyle(
                              fontSize: 20, height: .8, color: Color(0xFF5B5CE2))),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dow extends StatelessWidget {
  const _Dow(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: SizedBox(
        height: 24,
        child: Center(
          child: Text(
            '',
            style: TextStyle(fontSize: 0),
          ),
        ),
      ),
    );
  }
}

// 상태칩
class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip({required this.label});

  Color _bg() {
    switch (label) {
      case '예약 확정':
        return const Color(0xFFEFF9EE);
      case '예약 실패':
        return const Color(0xFFFFEEEE);
      default:
        return const Color(0xFFEFF4FF);
    }
  }

  Color _fg() {
    switch (label) {
      case '예약 확정':
        return const Color(0xFF2E7D32);
      case '예약 실패':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF4A7BFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _fg(),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

// 재사용 위젯들
class _BannerNotice extends StatelessWidget {
  const _BannerNotice({required this.loading, required this.text});
  final bool loading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: loading
          ? const _SkeletonLine()
          : Text(text, style: const TextStyle(color: Colors.black87)),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final VoidCallback onTap;

  const _IconTile({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 36, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();
  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color(0xFFFFF4B8)),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          '메뉴',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _DrawerTile({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }
}

// ─────────── 우하단 말풍선 FAB 구성 ───────────
class _ChatBubbleFab extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatBubbleFab({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 말풍선 느낌의 라운드 사각 버튼 + 우상단 뱃지
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.black.withOpacity(0.9),
          elevation: 3,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.chat_bubble_outline, color: Colors.white),
                  SizedBox(width: 6),
                  Text('문의채팅',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

// ──────────────── 사진 미리보기 전용 UI ────────────────
class _PreviewSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, __) => Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.black12.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _PreviewEmpty extends StatelessWidget {
  final VoidCallback onTap;
  const _PreviewEmpty({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('게시된 반려 사진이 없습니다.\n터치하여 전체보기',
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final _PetPreview preview;
  final VoidCallback onTap;
  const _PreviewCard({required this.preview, required this.onTap});

  String _fmtDateDot(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  String _fmtKTime(DateTime dt) {
    final h = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final isAm = h < 12;
    int hh = h % 12;
    if (hh == 0) hh = 12;
    return '${isAm ? '오전' : '오후'} ${hh.toString().padLeft(2, '0')}:$min';
  }

  @override
  Widget build(BuildContext context) {
    final date = _fmtDateDot(preview.createdAt);
    final time = _fmtKTime(preview.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: preview.imageUrl.isEmpty
                    ? Container(color: const Color(0xFFEDEDED))
                    : Image.network(
                  preview.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFFEDEDED)),
                ),
              ),
            ),
            Container(
              color: const Color(0xFFFFF4B8),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(date,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                preview.memo.isEmpty ? '내용 없음' : preview.memo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
