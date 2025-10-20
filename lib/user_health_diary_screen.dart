import 'dart:convert';
import 'dart:io';
// import 'package:animal_project/user_diary_add_screen.dart'; // 파일이 없으므로 임시 주석 처리
import 'package:animal_project/user_diary_detail_screen.dart';
import 'package:animal_project/user_health_main.dart'; // ✅ 모든 모델이 있는 파일을 import
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'models/user_health_models.dart';

// ❌❌❌ 이 파일 내부에 있던 DiaryEntry, PetProfile 등 모든 중복 모델 클래스 정의를 완전히 삭제합니다. ❌❌❌

class HealthDiaryScreen extends StatefulWidget {
  final String token;
  const HealthDiaryScreen({super.key, required this.token});

  @override
  State<HealthDiaryScreen> createState() => _HealthDiaryScreenState();
}

class _HealthDiaryScreenState extends State<HealthDiaryScreen> {
  late Future<List<DiaryEntry>> _diariesFuture;

  String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:4000' : 'http://localhost:4000';

  @override
  void initState() {
    super.initState();
    _diariesFuture = _fetchDiaries();
  }

  Future<List<DiaryEntry>> _fetchDiaries() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/diaries'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> diaryListJson = json.decode(utf8.decode(response.bodyBytes));
      return diaryListJson.map((json) => DiaryEntry.fromJson(json)).toList();
    } else {
      throw Exception('일기 목록을 불러오는 데 실패했습니다.');
    }
  }

  void _refreshDiaries() {
    setState(() {
      _diariesFuture = _fetchDiaries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('건강 일기', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<DiaryEntry>>(
        future: _diariesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('작성된 일기가 없습니다.\n우측 하단 버튼을 눌러 첫 일기를 작성해보세요!', textAlign: TextAlign.center),
            );
          }

          final diaries = snapshot.data!;
          diaries.sort((a, b) => b.date.compareTo(a.date));

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: diaries.length,
            itemBuilder: (context, index) {
              final entry = diaries[index];
              return _buildDiaryCard(context, entry);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // ✅ user_diary_add_screen.dart 파일이 없으므로 임시 주석 처리
          /*
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => DiaryAddScreen(token: widget.token)),
          );
          if (result == true) {
            _refreshDiaries();
          }
          */
          // 사용자에게 파일이 없음을 알리는 임시 메시지
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일기 추가 화면 파일(user_diary_add_screen.dart)이 필요합니다.')),
          );
        },
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDiaryCard(BuildContext context, DiaryEntry entry) {
    final imageUrl = entry.imagePath.isNotEmpty ? '$_baseUrl/${entry.imagePath.replaceAll('\\', '/')}' : '';
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              // ✅ 이제 타입이 일치하여 에러가 발생하지 않습니다.
              builder: (context) => DiaryDetailScreen(diaryEntry: entry),
            ),
          );
          if (result == true) {
            _refreshDiaries();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)))
                      : Container(color: Colors.grey.shade200, child: const Icon(Icons.photo, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('yyyy년 MM월 dd일').format(entry.date),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
