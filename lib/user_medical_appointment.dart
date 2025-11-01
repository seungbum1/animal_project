// user_medical_appointment.dart.

import 'api_config.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_appointment_finish.dart';

class UserMedicalAppointmentScreen extends StatefulWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;
  final DateTime? initialDate;


  const UserMedicalAppointmentScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
    this.initialDate,
  });

  @override
  State<UserMedicalAppointmentScreen> createState() =>
      _UserMedicalAppointmentScreenState();
}

class _UserMedicalAppointmentScreenState
    extends State<UserMedicalAppointmentScreen> {
  // ---- 서버 공통 ----
  static String get _baseUrl => ApiConfig.baseUrl;

  final _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  // ---- 메타/내정보 ----
  List<String> _services = const [
    '일반진료',
    '건강검진',
    '종합백신',
    '심장사상충',
    '치석제거',
  ];
  List<_Doctor> _doctors = const [
    _Doctor(id: 'default', name: '김철수 원장'),
  ];

  // 서버에서 받은 값을 기본으로 사용 (둘 다 비어있을 때만 폴백 텍스트)
  String _userName = '';
  String _petName = '';

  // ---- 선택값 ----
  String? _selectedService;
  _Doctor? _selectedDoctor;

  // 캘린더 상태
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  String? _selectedTime;

  // 시간 슬롯
  static const List<String> _timeSlots = [
    '10:00', '10:30', '11:00', '11:30', '13:00',
    '13:30', '14:00', '14:30', '15:00', '15:30',
    '16:00', '16:30', '17:00', '17:30', '18:00',
  ];

  // 섹션 접기/펼치기 상태
  bool _openService = true;
  bool _openDoctor  = true;
  bool _openDate    = true;
  bool _openTime    = true;

  // ✅ 라우트로 전달된 initialDate를 한 번만 적용하기 위한 플래그
  bool _didApplyInitialDate = false;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _initLoad();
  }

  // ✅ 여기서 arguments의 initialDate를 읽어 초기 선택 날짜/월 반영
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didApplyInitialDate) return;

    final args = ModalRoute.of(context)?.settings.arguments as Map<dynamic, dynamic>?;
    final DateTime? initialDate = args?['initialDate'] as DateTime?;

    if (initialDate != null) {
      final d = DateTime(initialDate.year, initialDate.month, initialDate.day);
      _selectedDate = d;
      _focusedMonth = DateTime(d.year, d.month);
      // 시간은 전달받지 않았으니 초기화 유지 (_selectedTime 그대로)
      setState(() {}); // 초깃값 UI 반영
    }
    _didApplyInitialDate = true;
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  Future<void> _initLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([_fetchMeta(), _fetchMe()]);
      // 기본 선택값 지정
      _selectedService ??= _services.isNotEmpty ? _services.first : null;
      _selectedDoctor ??= _doctors.isNotEmpty ? _doctors.first : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMeta() async {
    final uri = Uri.parse(
        '$_baseUrl/api/hospitals/${widget.hospitalId}/appointment-meta');

    try {
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final services = (data['services'] as List?)?.cast<String>();
        final doctorsRaw = (data['doctors'] as List?)?.cast<dynamic>();

        if (services != null && services.isNotEmpty) {
          _services = services;
        }
        if (doctorsRaw != null && doctorsRaw.isNotEmpty) {
          _doctors = doctorsRaw.map((e) {
            final m = (e as Map).cast<String, dynamic>();
            return _Doctor(
              id: (m['id'] ?? m['_id'] ?? '').toString(),
              name: (m['name'] ?? '의사').toString(),
            );
          }).toList();
        }
      }
    } catch (_) {
      // 폴백 유지
    }
  }

  Future<void> _fetchMe() async {
    final uri = Uri.parse('$_baseUrl/api/users/me');
    try {
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final root = jsonDecode(res.body) as Map<String, dynamic>;

        // 서버가 { user: {...}, name: '...', petProfile: {...} } 형태로 내려오므로 안전하게 병합
        final userObj = (root['user'] as Map<String, dynamic>?) ?? {};
        final topName = (root['name'] ?? '').toString().trim();
        final objName = (userObj['name'] ?? '').toString().trim();

        final petTop = (root['petProfile'] is Map)
            ? (root['petProfile'] as Map).cast<String, dynamic>()
            : null;
        final petObj = (userObj['petProfile'] is Map)
            ? (userObj['petProfile'] as Map).cast<String, dynamic>()
            : null;

        final mergedName = topName.isNotEmpty ? topName : objName;
        final mergedPet  = ((petTop?['name'] ?? '') as String).trim().isNotEmpty
            ? (petTop!['name'] as String).trim()
            : (((petObj?['name'] ?? '') as String).trim());

        setState(() {
          _userName = mergedName; // 비어있으면 '', 폴백은 UI에서 처리
          _petName  = mergedPet;  // 비어있으면 ''
        });
      }
    } catch (_) {
      // 폴백 유지
    }
  }

  // ---- 예약 제출 ----
  Future<void> _submit() async {
    if (_selectedService == null ||
        _selectedDoctor == null ||
        _selectedTime == null) {
      _toast('진료 항목/의사/시간을 모두 선택해주세요.');
      return;
    }

    setState(() => _submitting = true);

    try {
      // 방문 시간 DateTime 구성 (로컬 기준)
      final parts = _selectedTime!.split(':');
      final visit = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      final body = {
        'hospitalId': widget.hospitalId,
        'hospitalName': widget.hospitalName,
        'service': _selectedService,
        'doctorName': _selectedDoctor!.name,
        'date': _fmtDate(_selectedDate),
        'time': _selectedTime,
        'visitDateTime': visit.toIso8601String(),
        'userName': _userName.isNotEmpty ? _userName : '사용자',
        'petName':  _petName.isNotEmpty  ? _petName  : '(미입력)',
        'status': 'PENDING',
      };

      final uri = Uri.parse(
        '$_baseUrl/api/hospitals/${widget.hospitalId}/appointments/request',
      );

      final res = await _http
          .post(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(_timeout);

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        // ✅ 성공 시: 완료 화면으로 전환
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserAppointmentFinishScreen(
              token: widget.token,
              hospitalId: widget.hospitalId,
              hospitalName: widget.hospitalName,
              petName: _petName,                  // 예: 다롱이
              service: _selectedService!,         // 선택한 진료 항목
              doctorName: _selectedDoctor!.name,  // 선택한 의사
              date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
              time: _selectedTime!,               // 'HH:mm'
            ),
          ),
        );
      } else {
        _toast('전송 실패 (${res.statusCode})');
      }
    } catch (e) {
      _toast('전송 중 오류: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: topYellow,
        elevation: 0,
        centerTitle: true,
        title: const Text('진료 예약',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: RefreshIndicator(
          onRefresh: _initLoad,
          child: ListView(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 섹션: 진료 항목
              _CollapsibleHeader(
                title: '진료 항목',
                expanded: _openService,
                onTap: () => setState(() => _openService = !_openService),
              ),
              const SizedBox(height: 8),
              if (_openService)
                _RadioGroup<String>(
                  options: _services,
                  selected: _selectedService,
                  onChanged: (v) =>
                      setState(() => _selectedService = v),
                ),
              const _DividerBar(),

              // 섹션: 진료의
              _CollapsibleHeader(
                title: '진료의',
                expanded: _openDoctor,
                onTap: () => setState(() => _openDoctor = !_openDoctor),
              ),
              const SizedBox(height: 8),
              if (_openDoctor)
                _RadioGroup<_Doctor>(
                  options: _doctors,
                  labeler: (d) => d.name,
                  selected: _selectedDoctor,
                  onChanged: (v) =>
                      setState(() => _selectedDoctor = v),
                ),
              const _DividerBar(),

              // 섹션: 방문 날짜
              _CollapsibleHeader(
                title: '방문 날짜',
                expanded: _openDate,
                onTap: () => setState(() => _openDate = !_openDate),
              ),
              const SizedBox(height: 8),
              if (_openDate)
                _MonthCalendar(
                  focusedMonth: _focusedMonth,
                  selectedDate: _selectedDate,
                  onMonthChanged: (m) =>
                      setState(() => _focusedMonth = m),
                  onDateSelected: (d) =>
                      setState(() => _selectedDate = d),
                ),
              const _DividerBar(),

              // 섹션: 방문 시간
              _CollapsibleHeader(
                title: '방문 시간',
                expanded: _openTime,
                onTap: () => setState(() => _openTime = !_openTime),
              ),
              const SizedBox(height: 8),
              if (_openTime)
                _TimeGrid(
                  times: _timeSlots,
                  selected: _selectedTime,
                  onSelected: (t) => setState(() => _selectedTime = t),
                ),
              const SizedBox(height: 16),

              // 예약/취소 버튼
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: topYellow,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                          : const Text('예약하기',
                          style: TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.black26),
                        foregroundColor: Colors.black87,
                      ),
                      child: const Text('취소하기',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 하단: 현재 선택 요약
              _SelectionSummary(
                userName:
                _userName.isNotEmpty ? _userName : '사용자',
                petName:
                _petName.isNotEmpty ? _petName : '(미입력)',
                hospitalName: widget.hospitalName,
                service: _selectedService,
                doctor: _selectedDoctor?.name,
                date: _fmtDate(_selectedDate),
                time: _selectedTime,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 유틸 ----
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1200)),
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }
}

// ===== Helper Models / Widgets =====

class _Doctor {
  final String id;
  final String name;
  const _Doctor({required this.id, required this.name});
  @override
  String toString() => name;
}

class _CollapsibleHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onTap;
  const _CollapsibleHeader({
    super.key,
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const Spacer(),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerBar extends StatelessWidget {
  const _DividerBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: const Color(0xFFFFF4B8),
    );
  }
}

class _RadioGroup<T> extends StatelessWidget {
  final List<T> options;
  final T? selected;
  final void Function(T?) onChanged;
  final String Function(T)? labeler;

  const _RadioGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labeler,
  });

  String _labelOf(T v) => labeler != null ? labeler!(v) : v.toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options
          .map(
            (v) => RadioListTile<T>(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: v,
          groupValue: selected,
          onChanged: onChanged,
          title: Text(_labelOf(v)),
          visualDensity: VisualDensity.compact,
        ),
      )
          .toList(),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  final List<String> times;
  final String? selected;
  final void Function(String) onSelected;

  const _TimeGrid({
    super.key,
    required this.times,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: times.map((t) {
        final isSel = t == selected;
        return ChoiceChip(
          label: Text(t),
          selected: isSel,
          onSelected: (_) => onSelected(t),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSel ? Colors.black : Colors.black87,
          ),
          shape: StadiumBorder(
            side: BorderSide(color: isSel ? Colors.black : Colors.black38),
          ),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFFFF4B8),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  final String userName;
  final String petName;
  final String hospitalName;
  final String? service;
  final String? doctor;
  final String date;
  final String? time;

  const _SelectionSummary({
    required this.userName,
    required this.petName,
    required this.hospitalName,
    required this.service,
    required this.doctor,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final text = [
      '병원: $hospitalName',
      if (service != null) '진료 항목: $service',
      if (doctor != null) '진료의: $doctor',
      '방문 날짜: $date ${time ?? ''}'.trim(),
    ].join('\n');

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFF4B8)),
      ),
      child: Text(
        text,
        style: const TextStyle(height: 1.4),
      ),
    );
  }
}

/// ─────────────────────────────
/// 커스텀 월 캘린더(동그라미 선택 표시)
/// ─────────────────────────────
class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth; // ex) 2025-10-01
  final DateTime selectedDate; // ex) 2025-10-09
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _MonthCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ym = DateTime(focusedMonth.year, focusedMonth.month);
    final first = DateTime(ym.year, ym.month, 1);
    final daysInMonth = DateTime(ym.year, ym.month + 1, 0).day;
    // Dart weekday: Mon=1..Sun=7  →  Sun-first grid offset
    final startOffset = first.weekday % 7; // Sun=0, Mon=1 ...

    // ✅ 오늘(자정 기준) 계산 추가
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final items = <_CellDay>[];
    for (int i = 0; i < startOffset; i++) {
      items.add(const _CellDay.blank());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      items.add(_CellDay(DateTime(ym.year, ym.month, d)));
    }
    while (items.length % 7 != 0) {
      items.add(const _CellDay.blank());
    }

    final headerStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더 (이전/다음 달)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final prev = DateTime(ym.year, ym.month - 1);
                  onMonthChanged(prev);
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${ym.year}년 ${ym.month}월',
                    style: headerStyle,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final next = DateTime(ym.year, ym.month + 1);
                  onMonthChanged(next);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 요일 헤더 (일~토)
          Row(
            children: const [
              _Dow('일'), _Dow('월'), _Dow('화'), _Dow('수'),
              _Dow('목'), _Dow('금'), _Dow('토'),
            ],
          ),
          const SizedBox(height: 6),

          // 날짜 그리드
          GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (_, i) {
              final cell = items[i];
              if (!cell.isDay) return const SizedBox.shrink();

              final d = cell.date!;
              final isSelected = d.year == selectedDate.year &&
                  d.month == selectedDate.month &&
                  d.day == selectedDate.day;

              // ✅ 과거 날짜 비활성화 판단
              final isDisabled = d.isBefore(today);

              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: isDisabled ? null : () => onDateSelected(d),
                child: Container(
                  alignment: Alignment.center,
                  // ✅ 과거이거나 미선택이면 데코레이션 없음(동그라미 제거)
                  decoration: (!isDisabled && isSelected)
                      ? BoxDecoration(
                    color: const Color(0xFFFFF4B8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black87, width: 1.2),
                  )
                      : null,
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      fontWeight: (!isDisabled && isSelected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      // ✅ 과거 날짜 회색 숫자
                      color: isDisabled ? Colors.grey : Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Dow extends StatelessWidget {
  final String t;
  const _Dow(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CellDay {
  final DateTime? date;
  final bool isDay;
  const _CellDay(this.date) : isDay = true;
  const _CellDay.blank()
      : date = null,
        isDay = false;
}
