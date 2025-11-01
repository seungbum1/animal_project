// lib/user_diary_detail_screen.dart (수정 완료)

import 'dart:convert';
import 'dart:io';
import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/user_diary_edit_screen.dart'; // ✅ 수정 화면 import
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:animal_project/api_config.dart';

class DiaryDetailScreen extends StatelessWidget {
  final DiaryEntry diaryEntry;
  final String token; // ✅ 수정, 삭제를 위해 token 전달받기

  const DiaryDetailScreen({
    super.key,
    required this.diaryEntry,
    required this.token, // ✅ 생성자에 token 추가
  });

  String get _baseUrl => ApiConfig.baseUrl;

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  // --- 🚀 실제 서버에 삭제 요청을 보내는 함수 ---
  Future<void> _deleteDiary(BuildContext context) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/diaries/${diaryEntry.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 204 && context.mounted) {
        // 1. 상세 화면 닫기 (true를 반환하여 목록 화면이 새로고침되도록 함)
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일기가 삭제되었습니다.')),
        );
      } else {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('삭제 실패: ${responseBody['message']}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }


  // --- 삭제 확인 대화상자 ---
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('정말로 이 일기를 삭제하시겠습니까?\n삭제된 내용은 복구할 수 없습니다.'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
              onPressed: () {
                Navigator.of(ctx).pop(); // 대화상자 먼저 닫기
                _deleteDiary(context); // ✅ 실제 삭제 함수 호출
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = diaryEntry.imagePath.isNotEmpty ? '$_baseUrl/${diaryEntry.imagePath.replaceAll('\\', '/')}' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_formatDate(diaryEntry.date), style: const TextStyle(color: Colors.black, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black54),
            onPressed: () async {
              // ✅ 수정 화면으로 이동하고, 결과(true)를 받으면 현재 화면도 닫아서 목록을 새로고침
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => DiaryEditScreen(
                    token: token,
                    diaryEntry: diaryEntry,
                  ),
                ),
              );
              // 수정이 완료되어 true를 반환받으면, 상세 화면도 닫고 목록을 새로고침하게 함
              if (result == true && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black54),
            onPressed: () => _showDeleteConfirmation(context), // ✅ 함수 호출
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 이미지 표시 부분 (기존과 동일) ---
            if (imageUrl.isNotEmpty)
              SizedBox(
                height: 300,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey));
                  },
                ),
              ),
            // --- 제목 및 내용 표시 부분 (기존과 동일) ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(diaryEntry.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(diaryEntry.content, style: const TextStyle(fontSize: 16, height: 1.6)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}