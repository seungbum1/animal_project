// user_chat_hospital.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class UserChatHospitalScreen extends StatefulWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;

  const UserChatHospitalScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
  });

  @override
  State<UserChatHospitalScreen> createState() => _UserChatHospitalScreenState();
}

class _UserChatHospitalScreenState extends State<UserChatHospitalScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  bool _loading = false;
  String? _myUserId;
  String _myName = '나';
  String _adminName = '김철수 원장'; // 서버에서 못 받아오면 fallback
  Timer? _pollTimer;
  DateTime? _lastFetchedAt;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputCtrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (mounted) setState(() => _loading = true);
    try {
      await _loadMe();
      await _loadHospitalAdminSummary();
      await _fetchMessages(initial: true);
      _startPolling();
    } finally {
      if (mounted) setState(() => _loading = false);
      _jumpToBottom();
    }
  }

  Future<void> _loadMe() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/users/me');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _myUserId = (data['id'] ?? data['_id'] ?? '').toString();
        final name = (data['name'] ?? data['displayName'] ?? data['nickname'] ?? '').toString().trim();
        if (name.isNotEmpty) _myName = name;
      }
    } catch (_) {}
  }

  Future<void> _loadHospitalAdminSummary() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/hospitals/${widget.hospitalId}/admin/summary');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final n = (data['doctorName'] ?? data['adminName'] ?? '').toString().trim();
        if (n.isNotEmpty) _adminName = n;
      }
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    try {
      final qs = <String, String>{};
      if (!initial && _lastFetchedAt != null) {
        qs['since'] = _lastFetchedAt!.toUtc().toIso8601String();
      }
      final uri = Uri.parse('$_baseUrl/api/hospitals/${widget.hospitalId}/chat/messages')
          .replace(queryParameters: qs.isEmpty ? null : qs);

      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List?) ?? <dynamic>[];
        if (list.isNotEmpty) {
          final newOnes = list.map<_ChatMessage>((raw) {
            final role = (raw['senderRole'] ?? '').toString().toUpperCase();
            final isMine = role == 'USER'
                ? (raw['senderId']?.toString() == _myUserId ||
                (raw['senderName']?.toString() == _myName))
                : false;

            final name = isMine
                ? _myName
                : ((raw['senderName']?.toString().trim().isNotEmpty ?? false)
                ? raw['senderName'].toString()
                : _adminName);

            final createdAtStr = (raw['createdAt'] ?? raw['time'] ?? '').toString();
            final created = DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now();

            return _ChatMessage(
              id: (raw['_id'] ?? raw['id'] ?? '').toString(),
              isMine: isMine || (role == 'USER' && _myUserId == null),
              text: (raw['text'] ?? '').toString(),
              time: created,
              senderName: name,
              senderRole: role,
            );
          }).toList();

          // 중복 제거
          final existingIds = _messages.map((e) => e.id).toSet();
          final dedup = newOnes.where((m) => m.id.isEmpty || !existingIds.contains(m.id)).toList();

          if (dedup.isNotEmpty) {
            setState(() {
              _messages.addAll(dedup);
              _messages.sort((a, b) => a.time.compareTo(b.time));
              _lastFetchedAt = _messages.last.time.toUtc();
            });
            _jumpToBottom();
          }
        }

        // ✅ 최초 로드 성공 후 읽음 처리 (배지 초기화용)
        if (initial) {
          final headers = {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          };
          // 프로젝트 서버 경로에 맞춰 1~2개 호출 (실패 무시)
          Future.wait([
            http.post(
              Uri.parse('$_baseUrl/api/users/chat/read'),
              headers: headers,
              body: jsonEncode({'hospitalId': widget.hospitalId}),
            ),
          ]).catchError((_) {});
        }
      }
    } catch (_) {/* 폴링 중 에러 무시 */}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      _fetchMessages();
    });
  }

  Future<void> _send() async {
    final txt = _inputCtrl.text.trim();
    if (txt.isEmpty) return;

    final temp = _ChatMessage(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      isMine: true,
      text: txt,
      time: DateTime.now(),
      senderName: _myName,
      senderRole: 'USER',
    );

    setState(() {
      _messages.add(temp);
    });
    _inputCtrl.clear();
    _jumpToBottom();

    try {
      final uri = Uri.parse('$_baseUrl/api/hospitals/${widget.hospitalId}/chat/send');
      final res = await http
          .post(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'text': txt}),
      )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final raw = jsonDecode(res.body);
        final createdAtStr = (raw['createdAt'] ?? raw['time'] ?? '').toString();
        final created = DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now();

        final real = _ChatMessage(
          id: (raw['_id'] ?? raw['id'] ?? temp.id).toString(),
          isMine: true,
          text: (raw['text'] ?? txt).toString(),
          time: created,
          senderName: _myName,
          senderRole: 'USER',
        );

        setState(() {
          final idx = _messages.indexWhere((m) => m.id == temp.id);
          if (idx != -1) {
            _messages[idx] = real;
          } else {
            _messages.add(real);
          }
          _messages.sort((a, b) => a.time.compareTo(b.time));
          _lastFetchedAt = _messages.last.time.toUtc();
        });
        _jumpToBottom();
      } else {
        _rollbackTemp(temp.id);
      }
    } catch (_) {
      _rollbackTemp(temp.id);
    }
  }

  void _rollbackTemp(String tempId) {
    setState(() {
      _messages.removeWhere((m) => m.id == tempId);
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markReadOnExit() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/users/chat/read'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'hospitalId': widget.hospitalId}),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8);

    return WillPopScope(
      onWillPop: () async {
        await _markReadOnExit(); // 뒤로가기 시 한 번 더 읽음 처리
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: topYellow,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text(
            '채팅 문의',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.transparent,
                child: Text(
                  '＊ ${widget.hospitalName} 원장님과의 채팅 공간입니다 ＊',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final prev = i > 0 ? _messages[i - 1] : null;
                    final prevName = prev == null
                        ? null
                        : (prev.isMine ? _myName : (prev.senderName ?? _adminName));
                    final thisName = m.isMine ? _myName : (m.senderName ?? _adminName);
                    final showName = !m.isMine && thisName != null && thisName != prevName;

                    return _MessageRow(
                      message: m.copyWith(senderName: m.isMine ? _myName : thisName),
                      showName: showName,
                      adminAvatarColor: const Color(0xFF7A3E2D),
                    );
                  },
                ),
              ),
              _InputBar(
                controller: _inputCtrl,
                focusNode: _focus,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 모델/위젯들은 기존과 동일 =====

class _ChatMessage {
  final String id;
  final bool isMine;
  final String text;
  final DateTime time;
  final String? senderName;
  final String? senderRole;

  _ChatMessage({
    required this.id,
    required this.isMine,
    required this.text,
    required this.time,
    this.senderName,
    this.senderRole,
  });

  _ChatMessage copyWith({
    String? id,
    bool? isMine,
    String? text,
    DateTime? time,
    String? senderName,
    String? senderRole,
  }) {
    return _ChatMessage(
      id: id ?? this.id,
      isMine: isMine ?? this.isMine,
      text: text ?? this.text,
      time: time ?? this.time,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.showName,
    required this.adminAvatarColor,
  });
  final _ChatMessage message;
  final bool showName;
  final Color adminAvatarColor;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    final avatar = !isMine
        ? CircleAvatar(radius: 16, backgroundColor: adminAvatarColor)
        : const SizedBox(width: 32);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.66),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Text(message.text, style: const TextStyle(fontSize: 14.5, color: Colors.black87)),
      ),
    );

    final name = showName
        ? Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 4),
      child: Text(
        message.senderName ?? '',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    )
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine) name,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine) avatar,
              if (!isMine) const SizedBox(width: 8),
              bubble,
              if (isMine) const SizedBox(width: 8),
              if (isMine) const SizedBox(width: 32),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFFF9D6);
    final canSend = widget.controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        color: bg,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEFEFEF)),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: '채팅 입력..',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: canSend ? widget.onSend : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black54,
                  disabledBackgroundColor: Colors.white70,
                  disabledForegroundColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('전송'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
