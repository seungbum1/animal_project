import 'dart:convert';
import 'dart:io';
// import 'package:animal_project/user_diary_add_screen.dart'; // 파일이 없으므로 임시 주석 처리
import 'package:animal_project/user_diary_add_screen.dart';
import 'package:animal_project/user_diary_detail_screen.dart';
import 'package:animal_project/user_health_main.dart' hide kPrimaryColor; // ✅ 모든 모델이 있는 파일을 import
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'models/user_health_models.dart';
import 'package:animal_project/api_config.dart';

// ❌❌❌ 이 파일 내부에 있던 DiaryEntry, PetProfile 등 모든 중복 모델 클래스 정의를 완전히 삭제합니다. ❌❌❌

class HealthDiaryScreen extends StatefulWidget {
  final String token;
  const HealthDiaryScreen({super.key, required this.token});

  @override
  State<HealthDiaryScreen> createState() => _HealthDiaryScreenState();
}

class _HealthDiaryScreenState extends State<HealthDiaryScreen> {
  late Future<List<DiaryEntry>> _diariesFuture;

  String get _baseUrl => ApiConfig.baseUrl;

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
          // ✅ 주석을 풀고 SnackBar 코드를 삭제하여 화면 이동 기능을 활성화합니다.
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => DiaryAddScreen(token: widget.token)),
          );
          // 새 일기를 작성하고 돌아왔을 때 (result == true) 목록을 새로고침합니다.
          if (result == true) {
            _refreshDiaries();
          }
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
              builder: (context) => DiaryDetailScreen(
                diaryEntry: entry,
                token: widget.token, // ✅ 상세 화면으로 token을 전달합니다.
              ),
            ),
          );
          // 상세 화면에서 수정 또는 삭제가 발생하여 true를 반환하면 목록을 새로고침합니다.
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
