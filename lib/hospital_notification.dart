// user_notification.dart.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class UserNotificationsScreen extends StatefulWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;

  const UserNotificationsScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
  });

  @override
  State<UserNotificationsScreen> createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final _http = http.Client();
  final _controller = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _end = false;
  String? _error;

  final List<_Notify> _items = [];
  String? _cursor; // 서버가 cursor 기반이면 사용, 아니면 skip로 대체

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _http.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
      _end = false;
      _items.clear();
      _cursor = null;
    });
    await _fetch();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetch() async {
    if (_end) return;
    try {
      final qs = {
        'hospitalId': widget.hospitalId,
        'limit': '20',
        if (_cursor != null && _cursor!.isNotEmpty) 'cursor': _cursor!,
      };
      final uri = Uri.parse('$_baseUrl/api/users/me/notifications')
          .replace(queryParameters: qs);
      final res = await _http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List data =
        body is Map && body['data'] is List ? (body['data'] as List) : (body as List? ?? []);
        final nextCursor =
        (body is Map && body['nextCursor'] is String) ? body['nextCursor'] as String : null;

        final appended = data
            .map((e) => _Notify.fromJson((e as Map).cast<String, dynamic>()))
            .toList();

        setState(() {
          _items.addAll(appended);
          _cursor = nextCursor;
          if (appended.isEmpty || nextCursor == null) _end = true;
        });
      } else {
        setState(() => _error = '(${res.statusCode}) 로드 실패');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _onScroll() {
    if (_controller.position.pixels >
        _controller.position.maxScrollExtent - 300 &&
        !_loadingMore &&
        !_end) {
      _loadingMore = true;
      _fetch().whenComplete(() => _loadingMore = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/users/me/notifications/$id/read')
          .replace(queryParameters: {'hospitalId': widget.hospitalId});
      await _http.patch(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      });
    } catch (_) {}
  }

  Future<void> _delete(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/users/me/notifications/$id')
          .replace(queryParameters: {'hospitalId': widget.hospitalId});
      await _http.delete(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    // 선호: 서버 단일 엔드포인트
    try {
      final uri = Uri.parse(
          '$_baseUrl/api/users/me/notifications/mark-all-read?hospitalId=${widget.hospitalId}');
      final res = await _http.post(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });
      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() {
          for (final n in _items) {
            n.read = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 알림을 읽음 처리했어요.')),
        );
        return;
      }
    } catch (_) {}

    // 대안: 클라이언트에서 순차 처리
    for (final n in _items.where((e) => !e.read)) {
      await _markAsRead(n.id);
      n.read = true;
    }
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('모든 알림을 읽음 처리했어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = AppBar(
      title: const Text('알림함', style: TextStyle(color: Colors.black87)),
      backgroundColor: const Color(0xFFFFF4B8),
      iconTheme: const IconThemeData(color: Colors.black87),
      actions: [
        TextButton(
          onPressed: _items.isEmpty ? null : _markAllRead,
          child: const Text('모두 읽음', style: TextStyle(color: Colors.black87)),
        ),
      ],
    );

    return Scaffold(
      appBar: header,
      body: RefreshIndicator(
        onRefresh: _loadFirst,
        child: _loading
            ? const _LoadingList()
            : _error != null
            ? ListView(
          children: [
            const SizedBox(height: 60),
            Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
          ],
        )
            : _items.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('받은 알림이 없습니다.')),
          ],
        )
            : ListView.separated(
          controller: _controller,
          itemCount: _items.length + (_end ? 0 : 1),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i >= _items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final n = _items[i];
            return Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.redAccent,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) async {
                await _delete(n.id);
                setState(() => _items.removeAt(i));
              },
              child: ListTile(
                onTap: () async {
                  if (!n.read) {
                    await _markAsRead(n.id);
                    setState(() => n.read = true);
                  }
                  // 필요 시 타입별 화면 이동 훅
                  // e.g., if (n.type == 'APPOINTMENT_APPROVED') { ... }
                },
                leading: _typeIcon(n),
                title: Text(
                  n.title.isEmpty ? _defaultTitle(n.type) : n.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: n.read ? FontWeight.w500 : FontWeight.w800,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (n.message.isNotEmpty)
                      Text(
                        n.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtK(n.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                trailing: n.read
                    ? null
                    : Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A7BFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 유틸 ────────────────────────────────────────────────────────────────
  String _fmtK(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour;
    final mm = local.minute.toString().padLeft(2, '0');
    final isAm = h < 12;
    int hh = h % 12;
    if (hh == 0) hh = 12;
    return '$y.$m.$d · ${isAm ? '오전' : '오후'} ${hh.toString().padLeft(2, '0')}:$mm';
  }

  Widget _typeIcon(_Notify n) {
    IconData icon;
    Color bg;
    switch (n.type.toUpperCase()) {
      case 'APPOINTMENT_APPROVED':
        icon = Icons.event_available; bg = const Color(0xFFEFF9EE); break;
      case 'APPOINTMENT_REJECTED':
        icon = Icons.event_busy; bg = const Color(0xFFFFEEEE); break;
      case 'PET_CARE_POSTED':
        icon = Icons.pets; bg = const Color(0xFFFFF1E8); break;
      case 'MEDICAL_HISTORY_ADDED':
        icon = Icons.receipt_long_outlined; bg = const Color(0xFFEFF4FF); break;
      case 'SOS_ALERT':
        icon = Icons.warning_amber_rounded; bg = const Color(0xFFFFF0C2); break;
      default:
        icon = Icons.notifications; bg = const Color(0xFFEDEDED);
    }
    return CircleAvatar(
      backgroundColor: bg,
      child: Icon(icon, color: Colors.black87),
    );
  }

  String _defaultTitle(String type) {
    switch (type.toUpperCase()) {
      case 'APPOINTMENT_APPROVED': return '진료 예약이 승인되었습니다';
      case 'APPOINTMENT_REJECTED': return '진료 예약이 거절되었습니다';
      case 'PET_CARE_POSTED': return '새 반려 일지가 도착했어요';
      case 'MEDICAL_HISTORY_ADDED': return '새 진료 내역이 등록되었습니다';
      case 'SOS_ALERT': return '병원에서 긴급 SOS를 보냈어요';
      default: return '새 알림';
    }
  }
}

// ── 모델 ────────────────────────────────────────────────────────────────
class _Notify {
  final String id;
  final String type;   // e.g., APPOINTMENT_APPROVED, SOS_ALERT ...
  final String title;
  final String message;
  DateTime createdAt;
  bool read;

  _Notify({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  factory _Notify.fromJson(Map<String, dynamic> m) {
    DateTime dt = DateTime.now();
    for (final k in ['createdAt', 'dateTime', 'time', 'created']) {
      final v = m[k];
      if (v == null) continue;
      final p = DateTime.tryParse(v.toString());
      if (p != null) { dt = p.isUtc ? p.toLocal() : p; break; }
    }
    return _Notify(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      type: (m['type'] ?? 'SYSTEM').toString(),
      title: (m['title'] ?? '').toString(),
      message: (m['message'] ?? m['body'] ?? '').toString(),
      createdAt: dt,
      read: (m['read'] == true) || (m['isRead'] == true) || (m['status']?.toString().toLowerCase() == 'read'),
    );
  }
}

// ── 로딩 스켈레톤 ───────────────────────────────────────────────────────
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => const ListTile(
        leading: CircleAvatar(backgroundColor: Color(0xFFEDEDED)),
        title: _SkeletonLine(),
        subtitle: _SkeletonLine(width: 140),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  const _SkeletonLine({this.width = 220});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: 14,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black12, borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
