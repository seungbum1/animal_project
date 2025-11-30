// ================= hospital_medical_history.dart =================
// 병원관리자용: 사용자 목록 → 개인별 진료내역(아코디언) 조회/추가
// - 하단 네비게이션(홈/진료내역/SOS/마이페이지): _onTapBottomNav 패턴 적용
// - 상세 화면(아코디언)에서도 동일한 네비게이션 표시
// - 샘플 더미 데이터 제거: 서버 데이터/직접 추가한 것만 노출
// - 진료 항목 선택, 날짜 밀림 방지, 결제비 '원' 입력 가능

import 'dart:convert';
import 'dart:io' show Platform;

import 'hospital_patient.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'login.dart';
import 'hospital_mainscreen.dart';
import 'hospital_sos_user.dart';
import 'hospital_mypage.dart';


// ─────────────────────────────────────────────────────────────
// 공통: 베이스 URL & 무애니 라우팅
// ─────────────────────────────────────────────────────────────


Route _noAnim(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
);

void _pushNoAnim(BuildContext context, Widget page) {
  Navigator.of(context).push(_noAnim(page));
}

void _replaceNoAnim(BuildContext context, Widget page) {
  Navigator.of(context).pushReplacement(_noAnim(page));
}

// ─────────────────────────────────────────────────────────────
// 0) 사용자 목록 + 하단 네비
// ─────────────────────────────────────────────────────────────
class HospitalMedicalHistoryScreen extends StatefulWidget {
  const HospitalMedicalHistoryScreen({
    super.key,
    required this.token,
    required this.hospitalName,
    this.hospitalId,
  });

  final String token;
  final String hospitalName;
  final String? hospitalId;

  @override
  State<HospitalMedicalHistoryScreen> createState() =>
      _HospitalMedicalHistoryScreenState();
}

class _HospitalMedicalHistoryScreenState
    extends State<HospitalMedicalHistoryScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<_UserLite> _users = [];

  // 네비 인덱스: 0 홈 / 1 진료내역 / 2 SOS / 3 마이페이지
  int _currentIndex = 2;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _http.close();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/patients');
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
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
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);
        _users =
            list.map((e) => _UserLite.fromJsonFlex((e as Map).cast<String, dynamic>())).toList();
      } else {
        _error = '사용자 목록 오류 (${res.statusCode})';
      }
    } catch (e) {
      _error = '네트워크 오류: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- 하단 네비게이션 이동 ----
  void _onTapBottomNav(int i) {
    setState(() => _currentIndex = i);
    switch (i) {
      case 0:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalMainScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
      case 1: // 환자관리
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HospitalPatientManageScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
            hospitalId: widget.hospitalId,
          ),
        ));
        break;
      case 2:
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
    final q = _norm(_searchCtrl.text.trim());
    final filtered = q.isEmpty
        ? _users
        : _users
        .where((u) => _norm('${u.userName}/${u.petName}').contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        automaticallyImplyLeading: false, // ◀︎ 제거
        title: const Text('진료내역', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '동물/사용자이름 검색',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('다시 불러오기'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: filtered.isEmpty
                      ? ListView(
                    children: const [
                      SizedBox(height: 160),
                      Center(child: Text('연동 승인된 사용자가 없습니다.')),
                      SizedBox(height: 60),
                    ],
                  )
                      : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      return ListTile(
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        title: Text(
                          '${u.userName}/${u.petName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: OutlinedButton(
                          child: const Text('진료정보'),
                          onPressed: () {
                            _pushNoAnim(
                              context,
                              _AdminUserHistoryPage(
                                token: widget.token,
                                hospitalName: widget.hospitalName,
                                hospitalId: widget.hospitalId,
                                user: u,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),

      // 하단 네비게이션(요청하신 옵션 그대로)
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
}

// ─────────────────────────────────────────────────────────────
// 1) 개인 상세: 월 전환 + 아코디언 (샘플 제거)
// ─────────────────────────────────────────────────────────────
class _AdminUserHistoryPage extends StatefulWidget {
  const _AdminUserHistoryPage({
    required this.token,
    required this.hospitalName,
    required this.user,
    this.hospitalId,
  });

  final String token;
  final String hospitalName;
  final _UserLite user;
  final String? hospitalId;

  @override
  State<_AdminUserHistoryPage> createState() => _AdminUserHistoryPageState();
}

class _AdminUserHistoryPageState extends State<_AdminUserHistoryPage> {

  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  DateTime _cursor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = true;
  String? _error;
  List<_MedicalHistory> _all = [];
  String? _expandedId;

  // 상세 화면에도 하단 네비 표시
  int _currentIndex = 1;

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

  void _onTapBottomNav(int i) {
    setState(() => _currentIndex = i);
    switch (i) {
      case 0:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalMainScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
      case 1:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalMedicalHistoryScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
            hospitalId: widget.hospitalId,
          ),
        ));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalSosUserScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalMyPageScreen(
            token: widget.token,
            hospitalName: widget.hospitalName,
          ),
        ));
        break;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final q = {
        'userId': widget.user.userId,
        if (widget.hospitalId != null) 'hospitalId': widget.hospitalId!,
      };
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/medical-histories')
          .replace(queryParameters: q);

      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);
        _all = list
            .map((e) => _MedicalHistory.fromJsonFlex((e as Map).cast<String, dynamic>()))
            .whereType<_MedicalHistory>()
            .toList();
      } else if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
        return;
      } else {
        _error = '불러오기 오류 (${res.statusCode})';
      }
    } catch (e) {
      _error = '네트워크 오류: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_MedicalHistory> get _filteredByMonth {
    final list = _all.toList()..sort((a, b) => b.date.compareTo(a.date));
    return list
        .where((e) => e.date.year == _cursor.year && e.date.month == _cursor.month)
        .toList();
  }

  void _prevMonth() => setState(() {
    _cursor = DateTime(_cursor.year, _cursor.month - 1, 1);
    _expandedId = null;
  });
  void _nextMonth() => setState(() {
    _cursor = DateTime(_cursor.year, _cursor.month + 1, 1);
    _expandedId = null;
  });

  String _fmtMonth(DateTime m) => '${m.year}. ${m.month.toString().padLeft(2, '0')}월';

  @override
  Widget build(BuildContext context) {
    final title = '${widget.user.userName}/${widget.user.petName} 진료내역';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        title: Text(title, style: const TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('다시 불러오기')),
          ],
        ),
      )
          : Column(
        children: [
          // 월 선택 헤더
          Container(
            color: const Color(0xFFFFF7CC),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Center(
                    child: Text(_fmtMonth(_cursor),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: _filteredByMonth.isEmpty
                ? const Center(child: Text('진료내역이 없습니다.'))
                : ListView.separated(
              itemCount: _filteredByMonth.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = _filteredByMonth[i];
                final expanded = _expandedId == m.id;
                return Column(
                  children: [
                    _AccordionHeader(
                      item: m,
                      expanded: expanded,
                      onToggle: () => setState(() {
                        _expandedId = expanded ? null : m.id;
                      }),
                    ),
                    if (expanded) _AccordionDetail(item: m),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                ),
                onPressed: () async {
                  final created =
                  await showModalBottomSheet<_MedicalHistory>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) => _AdminAddHistorySheet(
                      token: widget.token,
                      user: widget.user,
                      hospitalId: widget.hospitalId,
                    ),
                  );
                  if (created != null) {
                    setState(() => _all.insert(0, created));
                  }
                },
                child: const Text('진료내역 추가'),
              ),
            ),
          ),
        ],
      ),

      // 상세 화면 하단 네비게이션
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTapBottomNav,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: '진료내역'),
          BottomNavigationBarItem(icon: Icon(Icons.sos_outlined), label: '긴급호출'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 아코디언 UI
// ─────────────────────────────────────────────────────────────
class _AccordionHeader extends StatelessWidget {
  final _MedicalHistory item;
  final bool expanded;
  final VoidCallback onToggle;
  const _AccordionHeader({
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  String _fmtDate(DateTime d) =>
      '${d.year}. ${d.month.toString().padLeft(2, '0')}. ${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF7CC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtDate(item.date), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(item.hospitalName ?? '병원', style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.category ?? '진료', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(item.cost ?? ''),
            ],
          ),
          const SizedBox(width: 8),
          InkWell(onTap: onToggle, child: Icon(expanded ? Icons.expand_less : Icons.expand_more)),
        ],
      ),
    );
  }
}

class _AccordionDetail extends StatelessWidget {
  final _MedicalHistory item;
  const _AccordionDetail({required this.item});

  String _title(DateTime d) =>
      '${d.year} / ${d.month.toString().padLeft(2, '0')} / ${d.day.toString().padLeft(2, '0')} 진료내역';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFEDE7C7)),
        Container(
          color: const Color(0xFFFFF7CC),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title(item.date),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 12),
              _ReadSection('진료 내용', item.content),
              const SizedBox(height: 12),
              _ReadSection('약 처방', item.prescription),
              const SizedBox(height: 12),
              _ReadSection('약 복용 방법', item.howToTake),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEDE7C7)),
      ],
    );
  }
}

class _ReadSection extends StatelessWidget {
  final String title;
  final String? value;
  const _ReadSection(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    final text = (value?.trim().isNotEmpty ?? false) ? value!.trim() : '내용 없음';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: const TextStyle(fontSize: 13.5)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2) 관리자 입력(바텀시트) → POST 저장
//    - 진료 항목 선택
//    - 날짜 UTC 자정 저장(밀림 방지)
//    - 결제비: 텍스트(‘원’ 입력 가능), 기본값 없음
// ─────────────────────────────────────────────────────────────
class _AdminAddHistorySheet extends StatefulWidget {
  const _AdminAddHistorySheet({
    required this.token,
    required this.user,
    this.hospitalId,
  });

  final String token;
  final _UserLite user;
  final String? hospitalId;

  @override
  State<_AdminAddHistorySheet> createState() => _AdminAddHistorySheetState();
}

class _AdminAddHistorySheetState extends State<_AdminAddHistorySheet> {

  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  DateTime _date = DateTime.now();
  final _contentCtrl = TextEditingController();
  final _prescriptionCtrl = TextEditingController();
  final _howToCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  static const List<String> _categories = [
    '일반진료', '건강검진', '종합백신', '심장사상충', '치석제거',
  ];
  String? _selectedCategory;

  bool _saving = false;

  @override
  void dispose() {
    _http.close();
    _contentCtrl.dispose();
    _prescriptionCtrl.dispose();
    _howToCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '날짜 선택',
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // 선택 날짜를 UTC 자정으로 지정(표시시는 로컬 변환)
      final utcDateIso =
      DateTime.utc(_date.year, _date.month, _date.day).toIso8601String();

      final body = {
        'userId': widget.user.userId,
        if (widget.hospitalId != null) 'hospitalId': widget.hospitalId,
        'date': utcDateIso,
        'category': (_selectedCategory ?? '').trim(),
        'content': _contentCtrl.text.trim(),
        'prescription': _prescriptionCtrl.text.trim(),
        'howToTake': _howToCtrl.text.trim(),
        'cost': _costCtrl.text.trim(),
        'petName': widget.user.petName,
        'userName': widget.user.userName,
      };

      final uri = Uri.parse('$_baseUrl/api/hospital-admin/medical-histories');
      final res = await _http
          .post(uri,
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body))
          .timeout(_timeout);

      if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
        return;
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final map = jsonDecode(res.body);
        final data = map is Map<String, dynamic> ? (map['data'] ?? map) : map;
        final created =
        _MedicalHistory.fromJsonFlex((data as Map).cast<String, dynamic>());
        if (!mounted) return;
        Navigator.of(context).pop(created);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: ${res.statusCode}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_date.year} / ${_date.month.toString().padLeft(2, '0')} / ${_date.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                '${widget.user.userName}/${widget.user.petName} 진료내역',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 20),

            const Text('날짜 선택', style: TextStyle(fontWeight: FontWeight.w600)),
            Row(
              children: [
                Expanded(child: Text(dateLabel, style: const TextStyle(fontSize: 16))),
                TextButton(onPressed: _pickDate, child: const Text('변경')),
              ],
            ),
            const SizedBox(height: 12),

            const Text('진료 항목', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final selected = _selectedCategory == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            const Text('진료 내용'),
            _box(_contentCtrl, maxLines: 3, hint: '진료 내용을 입력하세요'),
            const SizedBox(height: 10),

            const Text('약 처방'),
            _box(_prescriptionCtrl, maxLines: 3, hint: '처방 약을 입력하세요'),
            const SizedBox(height: 10),

            const Text('약 복용 방법'),
            _box(_howToCtrl, maxLines: 3, hint: '예: 하루 3회 아침/점심/저녁'),
            const SizedBox(height: 10),

            const Text('결제비'),
            _box(
              _costCtrl,
              keyboard: TextInputType.text, // '원' 입력 가능
              hint: '예: 40,000원',
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('취소')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('추가')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(TextEditingController c,
      {int maxLines = 1, String? hint, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 모델 & 유틸
// ─────────────────────────────────────────────────────────────
class _UserLite {
  final String userId;
  final String userName;
  final String petName;

  const _UserLite({
    required this.userId,
    required this.userName,
    required this.petName,
  });

  factory _UserLite.fromJsonFlex(Map<String, dynamic> j) {
    String pick(List<String> k) {
      for (final key in k) {
        final v = j[key];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    return _UserLite(
      userId: pick(['userId', '_id', 'id']),
      userName: pick(['userName', 'name']),
      petName: pick(['petName', 'pet']),
    );
  }
}

class _MedicalHistory {
  final String id;
  final DateTime date;
  final String? category; // 진료 항목
  final String? content; // 진료 내용
  final String? prescription; // 약 처방
  final String? howToTake; // 복용 방법
  final String? cost; // 결제비
  final String? hospitalName;
  final String? userName;
  final String? petName;

  _MedicalHistory({
    required this.id,
    required this.date,
    this.category,
    this.content,
    this.prescription,
    this.howToTake,
    this.cost,
    this.hospitalName,
    this.userName,
    this.petName,
  });

  static _MedicalHistory? fromJsonFlex(Map<String, dynamic> j) {
    DateTime? _parseDate(Map<String, dynamic> m) {
      for (final k in ['date', 'visitedAt', 'createdAt', 'historyDate']) {
        final v = m[k];
        if (v == null) continue;
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
        final d = DateTime.tryParse(v.toString());
        if (d != null) return d.toLocal(); // 로컬로 변환(밀림 방지)
      }
      return null;
    }

    String pick(List<String> k) {
      for (final key in k) {
        final v = j[key];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    final d = _parseDate(j);
    if (d == null) return null;

    return _MedicalHistory(
      id: pick(['_id', 'id']),
      date: d,
      category: pick(['category', 'type', 'subject']).ifEmptyNull(),
      content: pick(['content', 'diagnosis', 'description']).ifEmptyNull(),
      prescription: pick(['prescription', 'medicine', 'rx']).ifEmptyNull(),
      howToTake: pick(['howToTake', 'instruction', 'guide']).ifEmptyNull(),
      cost: pick(['cost', 'price', 'payment']).ifEmptyNull(),
      hospitalName: pick(['hospitalName']).ifEmptyNull(),
      userName: pick(['userName']).ifEmptyNull(),
      petName: pick(['petName']).ifEmptyNull(),
    );
  }
}

extension on String {
  String? ifEmptyNull() => trim().isEmpty ? null : this;
}
