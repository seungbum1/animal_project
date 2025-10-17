// ======================= hospital_notice.dart =======================
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'login.dart';

class HospitalNoticeScreen extends StatefulWidget {
  const HospitalNoticeScreen({
    super.key,
    required this.token,
    required this.hospitalName,
    this.hospitalId,
  });

  final String token;
  final String hospitalName;
  final String? hospitalId;

  @override
  State<HospitalNoticeScreen> createState() => _HospitalNoticeScreenState();
}

class _HospitalNoticeScreenState extends State<HospitalNoticeScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  bool _loading = true;
  String? _error;
  List<_Notice> _items = [];

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
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/notices').replace(
        queryParameters: {
          if (widget.hospitalId != null) 'hospitalId': widget.hospitalId!,
        },
      );

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
        _items = list.map((e) => _Notice.fromJsonFlex(e)).whereType<_Notice>().toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _error = '공지 불러오기 실패 (${res.statusCode})';
      }
    } catch (e) {
      _error = '네트워크 오류: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openComposer() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('공지사항 작성',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(
                controller: titleCtrl,
                maxLength: 50,
                decoration: InputDecoration(
                  hintText: '제목',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: '내용',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: () async {
                          final ok = await _createNotice(
                              titleCtrl.text.trim(), contentCtrl.text.trim());
                          if (!mounted) return;
                          Navigator.pop(context, ok);
                        },
                        child: const Text('등록')),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );

    if (ok == true) {
      _load();
    }
  }

  Future<bool> _createNotice(String title, String content) async {
    if (title.isEmpty || content.isEmpty) {
      _toast('제목과 내용을 입력하세요.');
      return false;
    }
    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/notices');
      final res = await _http
          .post(uri,
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'title': title,
            'content': content,
            if (widget.hospitalId != null) 'hospitalId': widget.hospitalId,
          }))
          .timeout(_timeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        _toast('등록되었습니다.');
        return true;
      } else if (res.statusCode == 401) {
        if (!mounted) return false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
        return false;
      } else {
        _toast('등록 실패: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      _toast('네트워크 오류: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        title: Text('${widget.hospitalName} 공지사항',
            style: const TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
              onPressed: _openComposer, icon: const Icon(Icons.edit_outlined))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton(
              onPressed: _load, child: const Text('다시 불러오기')),
        ]),
      )
          : _items.isEmpty
          ? const Center(child: Text('등록된 공지사항이 없습니다.'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final n = _items[i];
          final d =
              '${n.createdAt.year}.${n.createdAt.month.toString().padLeft(2, '0')}.${n.createdAt.day.toString().padLeft(2, '0')}';
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFECECEC))),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(d,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    n.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        label: const Text('공지 작성'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }
}

class _Notice {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  _Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  static _Notice? fromJsonFlex(Map<String, dynamic> j) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    DateTime? parseDate(Map<String, dynamic> m) {
      final keys = ['createdAt', 'date', 'postedAt', 'updatedAt'];
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        final d = DateTime.tryParse(v.toString());
        if (d != null) return d;
      }
      return null;
    }

    final d = parseDate(j);
    if (d == null) return null;

    return _Notice(
      id: pick(['_id', 'id']),
      title: pick(['title', 'subject']),
      content: pick(['content', 'body', 'text']),
      createdAt: d,
    );
  }
}
