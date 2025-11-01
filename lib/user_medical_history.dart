// user_medical_history.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserMedicalHistoryScreen extends StatefulWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;

  const UserMedicalHistoryScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
  });

  @override
  State<UserMedicalHistoryScreen> createState() =>
      _UserMedicalHistoryScreenState();
}

class _UserMedicalHistoryScreenState extends State<UserMedicalHistoryScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final _http = http.Client();
  final _searchCtl = TextEditingController();

  bool _loading = true;
  String? _error;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<_History> _all = [];
  String? _expandedId; // 아코디언 펼침 대상
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _http.close();
    _debounce?.cancel();
    _searchCtl.removeListener(_onSearchChanged);
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _fetchHistory();
      if (!mounted) return;
      setState(() {
        _all = list..sort((a, b) => b.date.compareTo(a.date)); // 최신 상단
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// 서버의 관리자 입력 진료내역을 조회
  Future<List<_History>> _fetchHistory() async {
    final y = _month.year;
    final m = _month.month.toString().padLeft(2, '0');

    final uri = Uri.parse(
      '$_baseUrl/api/users/me/medical-histories'
          '?month=$y-$m&hospitalId=${widget.hospitalId}',
    );

    final res = await _http
        .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('서버 오류 ${res.statusCode}');
    }

    final body = jsonDecode(res.body);
    final List data = (body['data'] as List?) ?? [];

    return data
        .map((e) => _History.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  List<_History> get _filtered {
    final q = _searchCtl.text.trim();
    if (q.isEmpty) return _all;
    return _all.where((e) {
      final dateStr = _fmtDateDot(e.date);
      return dateStr.contains(q) ||
          e.hospital.contains(q) ||
          e.title.contains(q);
    }).toList();
  }

  void _changeMonth(int delta) async {
    final next = DateTime(_month.year, _month.month + delta);
    setState(() {
      _month = next;
      _expandedId = null;
      _all = [];
      _loading = true;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: topYellow,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('진료내역',
            style:
            TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: const SizedBox(height: 8)),
              // 검색 + 월 선택
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      _SearchBox(controller: _searchCtl),
                      const SizedBox(height: 8),
                      _MonthSelector(
                        month: _month,
                        onPrev: () => _changeMonth(-1),
                        onNext: () => _changeMonth(1),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),

              if (_loading)
                const SliverToBoxAdapter(child: _SkeletonList())
              else if (_error != null && _filtered.isEmpty)
                const SliverToBoxAdapter(
                    child: _EmptyState(text: '불러오기에 실패했습니다.\n아래로 당겨 새로고침 해보세요.'))
              else if (_filtered.isEmpty)
                  const SliverToBoxAdapter(
                      child: _EmptyState(text: '진료내역이 없습니다.'))
                else
                  SliverList.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final h = _filtered[i];
                      final expanded = _expandedId == h.id;
                      return Column(
                        children: [
                          _HistoryRow(
                            item: h,
                            expanded: expanded,
                            onToggle: () => setState(() {
                              _expandedId = expanded ? null : h.id;
                            }),
                          ),
                          if (expanded) _HistoryDetail(item: h),
                        ],
                      );
                    },
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }

  // 2025. 10. 15
  String _fmtDateDot(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}. ${dt.month.toString().padLeft(2, '0')}. ${dt.day.toString().padLeft(2, '0')}';
}

// ───────────────────────── 모델 ─────────────────────────

class _History {
  final String id;
  final DateTime date;
  final String hospital;
  final String title; // 진료명(category)
  final int price; // 원 단위
  final String content; // 진료 내용
  final String prescription; // 약 처방
  final String howToUse; // 약 복용 방법

  _History({
    required this.id,
    required this.date,
    required this.hospital,
    required this.title,
    required this.price,
    required this.content,
    required this.prescription,
    required this.howToUse,
  });

  factory _History.fromJson(Map<String, dynamic> m) {
    // server: MedicalHistory { date(Date), hospitalName, category, cost(String), content, prescription, howToTake }
    DateTime dt = DateTime.now();
    final raw = (m['date'] ?? '').toString();
    final parsed = raw.isNotEmpty ? DateTime.tryParse(raw) : null;
    if (parsed != null) dt = parsed.isUtc ? parsed.toLocal() : parsed;

    // 금액: "40,000원" / "20000" 등 → 숫자만 추출
    final costStr = (m['cost'] ?? '').toString();
    final digitsOnly = RegExp(r'\d+').allMatches(costStr).map((e) => e.group(0)).join();
    final price = int.tryParse(digitsOnly.isEmpty ? '0' : digitsOnly) ?? 0;

    return _History(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      date: dt,
      hospital: (m['hospitalName'] ?? '').toString(),
      title: (m['category'] ?? '').toString(),
      price: price,
      content: (m['content'] ?? '').toString(),
      prescription: (m['prescription'] ?? '').toString(),
      howToUse: (m['howToTake'] ?? '').toString(),
    );
  }
}

// ───────────────────────── 위젯들 ─────────────────────────

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search, size: 20, color: Colors.black38),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '날짜/병원명/진료명 검색',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              splashRadius: 18,
              onPressed: () => controller.clear(),
            ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthSelector({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final label = '${month.year}. ${month.month.toString().padLeft(2, '0')}월';
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4B8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            splashRadius: 20,
          ),
          Expanded(
            child: Center(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final _History item;
  final bool expanded;
  final VoidCallback onToggle;

  const _HistoryRow({
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  String _fmtDateDot(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}. ${dt.month.toString().padLeft(2, '0')}. ${dt.day.toString().padLeft(2, '0')}';

  String _won(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final rev = s.length - i;
      b.write(s[i]);
      if (rev > 1 && rev % 3 == 1) b.write(',');
    }
    return '${b.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF9CC), // 연한 노랑 (스크린샷 느낌)
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // 날짜/병원
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtDateDot(item.date),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(item.hospital,
                    style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
          // 진료명/금액
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_won(item.price)),
            ],
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onToggle,
            child: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetail extends StatelessWidget {
  final _History item;
  const _HistoryDetail({required this.item});

  String _fmtTitle(DateTime dt) =>
      '${dt.year} / ${dt.month.toString().padLeft(2, '0')} / ${dt.day.toString().padLeft(2, '0')} 진료내역';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFEDE7C7)),
        Container(
          color: const Color(0xFFFFF9CC),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fmtTitle(item.date),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 12),
              _Section(title: '진료 내용', text: item.content),
              const SizedBox(height: 12),
              _Section(title: '약 처방', text: item.prescription),
              const SizedBox(height: 12),
              _Section(title: '약 복용 방법', text: item.howToUse),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEDE7C7)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String text;
  const _Section({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (text.isEmpty) ? '내용 없음' : text,
            style: const TextStyle(fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
            (_) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black12.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 48, 14, 0),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 52, color: Colors.black.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
