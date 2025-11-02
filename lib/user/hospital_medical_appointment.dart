// hospital_medical_appointment.dart
// 병원 관리자 - 진료예약 신청 내역 (검색, 정렬, 승인/거절, 스크롤, 빈 상태)

import 'dart:convert';
import 'dart:io' show Platform;
import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HospitalMedicalAppointmentScreen extends StatefulWidget {
  final String token;
  final String hospitalName; // 상단 타이틀 표기용

  const HospitalMedicalAppointmentScreen({
    super.key,
    required this.token,
    required this.hospitalName,
  });

  @override
  State<HospitalMedicalAppointmentScreen> createState() =>
      _HospitalMedicalAppointmentScreenState();
}

class _HospitalMedicalAppointmentScreenState
    extends State<HospitalMedicalAppointmentScreen> {
  // ----------------- 서버 -----------------
  static String get _baseUrl => ApiConfig.baseUrl;

  final _http = http.Client();
  final _timeout = const Duration(seconds: 10);

  // ----------------- 상태 -----------------
  bool _loading = true;
  String? _error;

  // 서버에서 받은 전체(PENDING) 목록
  final List<_Appt> _all = [];
  // 검색+정렬 적용된 목록
  final List<_Appt> _view = [];

  // 검색어(사용자명/진료명)
  String _query = '';

  // 정렬: 날짜 최신/오래된
  _SortOrder _order = _SortOrder.desc; // 기본 최신순

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
          '$_baseUrl/api/hospital-admin/appointments?status=PENDING');
      final res = await _http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(_timeout);

      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (map['data'] as List?) ?? const [];
        _all
          ..clear()
          ..addAll(list.map((e) => _Appt.fromJson(e)));
        _applyFilterSort();
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _error = '서버 오류 (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '네트워크 오류: $e';
      });
    }
  }

  void _applyFilterSort() {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _all
        : _all.where((a) {
      final user = (a.userName ?? '').toLowerCase();
      final service = (a.service ?? '').toLowerCase();
      return user.contains(q) || service.contains(q);
    }).toList();

    filtered.sort((a, b) {
      final ta = a.visitDateTime ?? a._fallbackDate;
      final tb = b.visitDateTime ?? b._fallbackDate;
      final cmp = ta.compareTo(tb);
      return _order == _SortOrder.asc ? cmp : -cmp;
    });

    _view
      ..clear()
      ..addAll(filtered);
  }

  // 승인/거절
  Future<void> _decide(_Appt appt, bool approve) async {
    // 낙관적 업데이트: 리스트에서 제거
    final idx = _view.indexWhere((e) => e.id == appt.id);
    if (idx < 0) return;
    final removedView = _view.removeAt(idx);

    final allIdx = _all.indexWhere((e) => e.id == appt.id);
    final removedAll = _all.removeAt(allIdx);

    setState(() {});

    try {
      final uri = Uri.parse(
          '$_baseUrl/api/hospital-admin/appointments/${appt.id}/${approve ? 'approve' : 'reject'}');
      final res = await _http
          .post(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);

      if (res.statusCode == 200) {
        _toast(approve ? '승인 완료' : '거절 완료');
      } else {
        // 롤백
        _all.insert(allIdx, removedAll);
        _applyFilterSort();
        setState(() {});
        _toast('처리 실패 (${res.statusCode})');
      }
    } catch (e) {
      _all.insert(allIdx, removedAll);
      _applyFilterSort();
      setState(() {});
      _toast('네트워크 오류로 처리 실패');
    }
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    const topYellow = Color(0xFFFFF4B8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: topYellow,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
          tooltip: '닫기',
        ),
        title: const Text(
          '진료예약 신청 내역',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 검색 + 정렬 바
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      hint: '사용자 이름/진료명 검색',
                      onChanged: (v) {
                        _query = v;
                        setState(_applyFilterSort);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    order: _order,
                    onChanged: (o) {
                      setState(() {
                        _order = o;
                        _applyFilterSort();
                      });
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 리스트 영역
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 10),
          Center(
            child: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 불러오기'),
            ),
          ),
        ],
      );
    }
    if (_view.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 60),
          Center(child: Text('진료예약 내역이 없습니다.', style: TextStyle(color: Colors.black54))),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _view.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      itemBuilder: (_, i) {
        final a = _view[i];
        return _ApptTile(
          appt: a,
          onApprove: () => _decide(a, true),
          onReject: () => _decide(a, false),
        );
      },
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)));
  }
}

// ----------------- 모델 -----------------

class _Appt {
  final String id;
  final String? userName;
  final String? petName;
  final String? service;
  final String? doctorName;
  final String? timeText; // HH:mm
  final String? dateText; // YYYY-MM-DD (백업 표기용)
  final DateTime? visitDateTime;

  _Appt({
    required this.id,
    this.userName,
    this.petName,
    this.service,
    this.doctorName,
    this.timeText,
    this.dateText,
    this.visitDateTime,
  });

  factory _Appt.fromJson(Map<String, dynamic> j) {
    DateTime? vd;
    final raw = j['visitDateTime'];
    if (raw != null) {
      final s = raw.toString();
      vd = DateTime.tryParse(s);
    }
    return _Appt(
      id: (j['_id'] ?? '').toString(),
      userName: (j['userName'] ?? '').toString(),
      petName: (j['petName'] ?? '').toString(),
      service: (j['service'] ?? '').toString(),
      doctorName: (j['doctorName'] ?? '').toString(),
      timeText: (j['time'] ?? '').toString(),
      dateText: (j['date'] ?? '').toString(),
      visitDateTime: vd,
    );
  }

  // visitDateTime이 없을 때 date+time로 보정
  DateTime get _fallbackDate {
    if (visitDateTime != null) return visitDateTime!;
    try {
      if ((dateText ?? '').isNotEmpty && (timeText ?? '').isNotEmpty) {
        final dt = DateTime.parse('${dateText!}T${timeText!}:00');
        return dt;
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get title {
    final user = userName ?? '';
    final pet = (petName ?? '').isEmpty ? '' : '/$petName';
    final svc = service ?? '';
    final up = (user + (pet)).replaceAll(RegExp(r'^/|/$'), '');
    return up.isEmpty ? svc : '$up - $svc';
  }

  String get subtitleLine1 {
    final doc = doctorName ?? '';
    final t = timeText ??
        (visitDateTime != null
            ? '${visitDateTime!.hour.toString().padLeft(2, '0')}:${visitDateTime!.minute.toString().padLeft(2, '0')}'
            : '');
    final ampm = _formatAmPm(t);
    return doc.isEmpty && ampm.isEmpty ? '' : [doc, ampm].where((e) => e.isNotEmpty).join(' / ');
  }

  String get subtitleLine2 {
    if (visitDateTime != null) {
      final y = visitDateTime!.year;
      final m = visitDateTime!.month.toString().padLeft(2, '0');
      final d = visitDateTime!.day.toString().padLeft(2, '0');
      return '$y년 $m월 $d일';
    }
    if ((dateText ?? '').isNotEmpty) {
      final parts = dateText!.split('-');
      if (parts.length == 3) {
        return '${parts[0]}년 ${parts[1]}월 ${parts[2]}일';
      }
    }
    return '';
  }

  String _formatAmPm(String hhmm) {
    if (hhmm.isEmpty || !hhmm.contains(':')) return hhmm;
    final h = int.tryParse(hhmm.split(':').first) ?? 0;
    final m = hhmm.split(':').last;
    final isAM = h < 12;
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final suffix = isAM ? '오전' : '오후';
    return '$suffix ${h12.toString().padLeft(2, '0')}:$m';
  }
}

// ----------------- 위젯 -----------------

class _ApptTile extends StatelessWidget {
  final _Appt appt;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApptTile({
    super.key,
    required this.appt,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7CC), // 연노랑 배경(스크린샷 톤)
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목줄 + 버튼
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              Expanded(
                child: Text(
                  appt.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              // 승인/거절 버튼
              Row(
                children: [
                  _pillButton(
                    context,
                    label: '승인',
                    bgColor: const Color(0xFF5B5CE2),
                    onTap: onApprove,
                  ),
                  const SizedBox(width: 8),
                  _pillButton(
                    context,
                    label: '거절',
                    bgColor: const Color(0xFFE64545),
                    onTap: onReject,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 부제목 1
          if (appt.subtitleLine1.isNotEmpty)
            Text(
              appt.subtitleLine1,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          // 부제목 2
          if (appt.subtitleLine2.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                appt.subtitleLine2,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pillButton(BuildContext context,
      {required String label, required Color bgColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// 검색 필드
class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hint, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.black38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// 정렬 버튼 (날짜별 ▾)
enum _SortOrder { asc, desc }

class _SortButton extends StatelessWidget {
  final _SortOrder order;
  final ValueChanged<_SortOrder> onChanged;

  const _SortButton({required this.order, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortOrder>(
      tooltip: '정렬',
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: _SortOrder.desc, child: Text('날짜별(최신순)')),
        PopupMenuItem(value: _SortOrder.asc, child: Text('날짜별(오래된순)')),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Text('날짜별', style: TextStyle(color: Colors.black87)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
