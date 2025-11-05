// hospital_chat_user.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'login.dart';

class HospitalChatUserListScreen extends StatefulWidget {
  const HospitalChatUserListScreen({
    super.key,
    required this.token,
    required this.hospitalName,
  });
  final String token;
  final String hospitalName;

  @override
  State<HospitalChatUserListScreen> createState() => _HospitalChatUserListScreenState();
}

class _HospitalChatUserListScreenState extends State<HospitalChatUserListScreen> {
  final _http = http.Client();
  final _timeout = const Duration(seconds: 10);
  static String get _baseUrl => ApiConfig.baseUrl;

  bool _loading = true;
  String _query = '';
  List<_Thread> _all = [];
  Map<String, String> _petNameByUserId = {}; // userId -> petName

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
    setState(() => _loading = true);
    try {
      final tUri = Uri.parse('$_baseUrl/api/hospital-admin/chat/threads');
      final uUri = Uri.parse('$_baseUrl/api/hospital-admin/linked-users');

      final results = await Future.wait([
        _http.get(tUri, headers: {'Authorization': 'Bearer ${widget.token}', 'Accept': 'application/json'}).timeout(_timeout),
        _http.get(uUri, headers: {'Authorization': 'Bearer ${widget.token}', 'Accept': 'application/json'}).timeout(_timeout),
      ]);

      for (final r in results) {
        if (r.statusCode == 401) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
          );
          return;
        }
      }

      // threads
      final r0 = results[0];
      final body0 = jsonDecode(r0.body);
      final List list0 = body0 is List ? body0 : (body0['data'] as List? ?? []);
      final threads = list0.map((e) => _Thread.fromJson(e)).toList();

      // linked users → petName map
      final r1 = results[1];
      final body1 = jsonDecode(r1.body);
      final List list1 = body1 is List ? body1 : (body1['data'] as List? ?? []);
      final map = <String, String>{};
      for (final e in list1) {
        final id = (e['userId'] ?? e['_id'] ?? e['id'] ?? '').toString();
        final pet = ((e['petProfile']?['name'] ?? e['petName'] ?? '') as String).trim();
        if (id.isNotEmpty && pet.isNotEmpty) map[id] = pet;
      }

      if (!mounted) return;
      setState(() {
        _all = threads;
        _petNameByUserId = map;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅 목록을 불러오지 못했습니다: $e')),
      );
    }
  }

  List<_Thread> get _filtered {
    if (_query.trim().isEmpty) return _all;
    final q = _query.trim();
    return _all.where((t) {
      final pet = _petNameByUserId[t.userId] ?? '';
      return t.userName.contains(q) || pet.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('문의 채팅', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 검색
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                onChanged: (s) => setState(() => _query = s),
                decoration: InputDecoration(
                  hintText: '동물/사용자이름 검색',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = _filtered[i];
                    final pet = _petNameByUserId[t.userId] ?? '';
                    final who = [t.userName, if (pet.isNotEmpty) pet].join('/');
                    return ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                      ),
                      title: Text(who, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.lastText, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: t.unread > 0
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.unread > 99 ? '99+' : '${t.unread}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      )
                          : const SizedBox.shrink(),
                      onTap: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                          builder: (_) => HospitalChatRoomScreen(
                            token: widget.token,
                            // ✅ threadId와 userId 모두 전달
                            threadId: t.threadId,
                            userId: t.userId,
                            userName: t.userName,
                            petName: pet,
                          ),
                        ))
                            .then((_) => _load());
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thread {
  final String threadId; // 스레드/룸 식별자
  final String userId;   // 상대 사용자 ID
  final String userName;
  final String lastText;
  final DateTime lastAt;
  final int unread;

  _Thread({
    required this.threadId,
    required this.userId,
    required this.userName,
    required this.lastText,
    required this.lastAt,
    required this.unread,
  });

  factory _Thread.fromJson(Map<String, dynamic> j) => _Thread(
    threadId: (j['threadId'] ?? j['roomId'] ?? j['_id'] ?? '').toString(),
    userId: (j['userId'] ?? j['targetUserId'] ?? j['_userId'] ?? j['id'] ?? '').toString(),
    userName: (j['userName'] ?? '사용자').toString(),
    lastText: (j['lastText'] ?? '').toString(),
    lastAt: DateTime.tryParse((j['lastAt'] ?? j['updatedAt'] ?? j['createdAt'] ?? '').toString()) ?? DateTime.now(),
    unread: int.tryParse('${j['unread'] ?? 0}') ?? 0,
  );
}

/// ======================
/// 채팅방 (관리자 측)
/// ======================
class HospitalChatRoomScreen extends StatefulWidget {
  const HospitalChatRoomScreen({
    super.key,
    required this.token,
    required this.userId,
    required this.userName,
    required this.petName,
    this.threadId,
  });

  final String token;
  final String userId;
  final String userName;
  final String petName;
  final String? threadId; // 있을 때는 스레드 기반 라우트 사용

  @override
  State<HospitalChatRoomScreen> createState() => _HospitalChatRoomScreenState();
}

class _HospitalChatRoomScreenState extends State<HospitalChatRoomScreen> {
  final _http = http.Client();
  final _timeout = const Duration(seconds: 10);
  static String get _baseUrl => ApiConfig.baseUrl;

  final _controller = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  List<_Msg> _msgs = [];
  Timer? _poll;

  bool get _hasThreadId => (widget.threadId ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _http.close();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      http.Response res;

      // ① thread 기반 시도
      if (_hasThreadId) {
        final uri1 = Uri.parse('$_baseUrl/api/hospital-admin/chat/threads/${widget.threadId}/messages?limit=50');
        res = await _http.get(uri1, headers: {'Authorization': 'Bearer ${widget.token}', 'Accept': 'application/json'}).timeout(_timeout);

        // 404면 ② userId 기반으로 폴백
        if (res.statusCode == 404) {
          final uri2 = Uri.parse('$_baseUrl/api/hospital-admin/chat/messages?userId=${Uri.encodeQueryComponent(widget.userId)}&limit=50');
          res = await _http.get(uri2, headers: {'Authorization': 'Bearer ${widget.token}', 'Accept': 'application/json'}).timeout(_timeout);
        }
      } else {
        // threadId 없으면 바로 ②
        final uri2 = Uri.parse('$_baseUrl/api/hospital-admin/chat/messages?userId=${Uri.encodeQueryComponent(widget.userId)}&limit=50');
        res = await _http.get(uri2, headers: {'Authorization': 'Bearer ${widget.token}', 'Accept': 'application/json'}).timeout(_timeout);
      }

      if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        return;
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List list = decoded is List ? decoded : (decoded['data'] as List? ?? []);
        final msgs = list.map((e) => _Msg.fromJson(e as Map<String, dynamic>)).toList();
        if (!mounted) return;
        setState(() {
          _msgs = msgs;
          _loading = false;
        });

        // ✅ 최초 로드 성공 시에만 읽음 처리 (두 라우트 시도)
        if (initial) {
          if (_hasThreadId) {
            _http.post(
              Uri.parse('$_baseUrl/api/hospital-admin/chat/threads/${widget.threadId}/read-all'),
              headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
            ).catchError((_) {});
          }
          _http.post(
            Uri.parse('$_baseUrl/api/hospital-admin/chat/read-all'),
            headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
            body: jsonEncode({'userId': widget.userId}),
          ).catchError((_) {});
        }

        await Future.delayed(const Duration(milliseconds: 50));
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else if (res.statusCode == 404) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('대화 대상(스레드/사용자)을 찾지 못했습니다 (404)')),
        );
      }
    } catch (_) {
      // 폴링 오류 무시
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      http.Response res;

      // ① thread 기반 전송
      if (_hasThreadId) {
        final uri1 = Uri.parse('$_baseUrl/api/hospital-admin/chat/threads/${widget.threadId}/messages');
        res = await _http.post(
          uri1,
          headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'text': text}),
        ).timeout(_timeout);

        // 404면 ② userId 기반으로 폴백
        if (res.statusCode == 404) {
          final uri2 = Uri.parse('$_baseUrl/api/hospital-admin/chat/messages');
          res = await _http.post(
            uri2,
            headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'userId': widget.userId, 'text': text}),
          ).timeout(_timeout);
        }
      } else {
        // threadId 없으면 ②
        final uri2 = Uri.parse('$_baseUrl/api/hospital-admin/chat/messages');
        res = await _http.post(
          uri2,
          headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'userId': widget.userId, 'text': text}),
        ).timeout(_timeout);
      }

      if (res.statusCode == 201 || res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final m = j is Map<String, dynamic>
            ? _Msg.fromJson(j)
            : _Msg.fromJson((j['data'] ?? {}) as Map<String, dynamic>);
        if (!mounted) return;
        setState(() => _msgs.add(m));
        await Future.delayed(const Duration(milliseconds: 30));
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      } else {
        String reason = '';
        try {
          final jb = jsonDecode(res.body);
          reason = (jb['message'] ?? jb['error'] ?? '').toString();
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패 (${res.statusCode}) ${reason.isNotEmpty ? '- $reason' : ''}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = [
      if (widget.userName.trim().isNotEmpty) widget.userName.trim(),
      if (widget.petName.trim().isNotEmpty) widget.petName.trim(),
    ].join('/');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title.isEmpty ? '채팅 문의' : title,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('＊ 문의 채팅 ＊', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                final isHospital = (m.senderRole.toUpperCase() == 'ADMIN' ||
                    m.senderRole.toUpperCase() == 'HOSPITAL');
                return Align(
                  alignment: isHospital ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isHospital ? const Color(0xFFFFF2B6) : Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(isHospital ? 14 : 4),
                        bottomRight: Radius.circular(isHospital ? 4 : 14),
                      ),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: const Color(0xFFFFF2B6).withOpacity(.45),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '채팅 입력..',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF2B6),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      elevation: 0,
                    ),
                    child: const Text('전송'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String id;
  final String senderRole; // 'USER' | 'ADMIN' | 'HOSPITAL'
  final String senderName;
  final String text;
  final DateTime at;

  _Msg({required this.id, required this.senderRole, required this.senderName, required this.text, required this.at});

  factory _Msg.fromJson(Map<String, dynamic> j) {
    DateTime parseTime() {
      final s = (j['createdAt'] ?? j['at'] ?? j['timestamp'] ?? '').toString();
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    return _Msg(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      senderRole: (j['senderRole'] ?? j['role'] ?? '').toString(),
      senderName: (j['senderName'] ?? j['fromName'] ?? '').toString(),
      text: (j['text'] ?? j['message'] ?? '').toString(),
      at: parseTime(),
    );
  }
}
