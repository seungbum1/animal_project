// user_pet_picture.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'api_config.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserPetPictureScreen extends StatefulWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;

  const UserPetPictureScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
  });

  @override
  State<UserPetPictureScreen> createState() => _UserPetPictureScreenState();
}

String _abs(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http')) return url;
  return '${ApiConfig.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
}

class _UserPetPictureScreenState extends State<UserPetPictureScreen> {
  // ⚠️ iOS 시뮬레이터는 localhost 불가 → 맥의 로컬 IP로 교체 필요
  // 터미널: ipconfig getifaddr en0  (예: 192.168.0.23)
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final TextEditingController _searchCtl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<_PetPost> _all = [];
  String _sort = 'new'; // 'new'(최신순) | 'old'(오래된순)
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
    _searchCtl.removeListener(_onSearchChanged);
    _searchCtl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() {}); // 필터링만 적용
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _fetchPosts();
      if (!mounted) return;
      setState(() {
        _all = list;
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

  /// 병원관리자가 올린 케어 일지(사용자 본인 보기)를 불러온다.
  /// 기대 응답: { data: [{ _id, date, time, dateTime, memo, imageUrl, images:[] }, ...] }
  Future<List<_PetPost>> _fetchPosts() async {
    final uri = Uri.parse(
        '$_baseUrl/api/users/me/pet-care?hospitalId=${widget.hospitalId}&sort=dateDesc');

    final res = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('불러오기 실패: ${res.statusCode}');
    }

    final body = jsonDecode(res.body);
    final List list = (body is Map && body['data'] is List) ? body['data'] : <dynamic>[];
    return list
        .map((e) => _PetPost.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  List<_PetPost> get _filteredSorted {
    final q = _searchCtl.text.trim();
    Iterable<_PetPost> list = _all;

    if (q.isNotEmpty) {
      list = list.where((e) =>
      e.content.contains(q) ||
          _fmtDateDot(e.createdAt).contains(q) ||
          _fmtKTime(e.createdAt).contains(q));
    }

    final sorted = list.toList()
      ..sort((a, b) => _sort == 'new'
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt));

    return sorted;
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
        title: Text(
          widget.hospitalName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(child: _SearchBox(controller: _searchCtl)),
                      const SizedBox(width: 8),
                      _SortChip(
                        value: _sort,
                        onChanged: (v) => setState(() => _sort = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (_loading)
                const SliverToBoxAdapter(child: _SkeletonGrid())
              else if (_error != null && _filteredSorted.isEmpty)
                const SliverToBoxAdapter(
                    child: _EmptyState(text: '불러오기에 실패했습니다.\n아래로 당겨 새로고침 해보세요.'))
              else if (_filteredSorted.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyState(text: '게시글이 없습니다.'))
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, i) {
                          final p = _filteredSorted[i];
                          return _PostCard(post: p, onTap: () {});
                        },
                        childCount: _filteredSorted.length,
                      ),
                    ),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

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
}

// ───────────────────────── 모델 ─────────────────────────

class _PetPost {
  final String id;
  final String imageUrl;
  final DateTime createdAt;
  final String content;

  _PetPost({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
    required this.content,
  });

  factory _PetPost.fromJson(Map<String, dynamic> m) {
    // 서버: { _id, date, time, dateTime, memo, imageUrl, images:[] }
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

    return _PetPost(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      imageUrl: img,
      createdAt: dt,
      content: (m['memo'] ?? m['content'] ?? '').toString(),
    );
  }
}

// ───────────────────────── UI 위젯 ─────────────────────────

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
                hintText: '검색',
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

class _SortChip extends StatelessWidget {
  final String value; // 'new' | 'old'
  final ValueChanged<String> onChanged;
  const _SortChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: const [
            DropdownMenuItem(value: 'new', child: Text('날짜순')),
            DropdownMenuItem(value: 'old', child: Text('오래된순')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final _PetPost post;
  final VoidCallback? onTap;
  const _PostCard({required this.post, this.onTap});

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
    final date = _fmtDateDot(post.createdAt);
    final time = _fmtKTime(post.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: AspectRatio(
                  aspectRatio: 1.05,
                  child: post.imageUrl.isEmpty
                      ? Container(color: const Color(0xFFEDEDED))
                      : Image.network(
                    _abs(post.imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFFEDEDED)),
                  ),
                ),
              ),
              Container(
                color: const Color(0xFFFFF4B8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    post.content.isEmpty ? '내용 없음' : post.content,
                    style: const TextStyle(fontSize: 12.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.black12.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
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
          Icon(Icons.photo_library_outlined,
              size: 52, color: Colors.black.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
