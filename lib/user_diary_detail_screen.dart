import 'dart:io';
// import 'package:animal_project/user_diary_edit_screen.dart'; // 수정 화면 파일이 없으므로 임시 주석 처리
import 'package:animal_project/user_health_main.dart'; // ✅ DiaryEntry 모델을 user_health_main.dart에서 가져오도록 수정
import 'package:flutter/material.dart';

class DiaryDetailScreen extends StatelessWidget {
  final DiaryEntry diaryEntry;

  const DiaryDetailScreen({super.key, required this.diaryEntry});

  // ✅ 기기에 따라 서버의 기본 URL을 반환하는 함수
  String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:4000' : 'http://localhost:4000';

  // 날짜 형식을 'yyyy년 MM월 dd일'로 바꿔주는 함수
  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  // 삭제 확인 대화상자를 띄우는 함수
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('정말로 이 일기를 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(ctx).pop(); // 대화상자 닫기
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
              onPressed: () {
                // TODO: 실제 서버에 삭제 요청을 보내는 API 호출 로직 추가 필요
                // 1. 대화상자 닫기
                Navigator.of(ctx).pop();
                // 2. 상세 화면 닫으면서 목록 화면에 '삭제됨' 신호 보내기
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 서버에서 받은 상대 경로와 기본 URL을 조합하여 완전한 이미지 URL 생성
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
        title: Text(
          _formatDate(diaryEntry.date),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black54),
            onPressed: () {
              // ✅ user_diary_edit_screen.dart 파일이 없으므로 임시 주석 처리
              /*
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiaryEditScreen(diaryEntry: diaryEntry),
                ),
              );
              */
              // 사용자에게 파일이 없음을 알리는 임시 메시지
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('수정 화면 파일(user_diary_edit_screen.dart)이 필요합니다.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black54),
            onPressed: () {
              _showDeleteConfirmation(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 300,
              width: double.infinity,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey),
                  );
                },
              )
                  : const Center(
                child: Icon(Icons.photo, size: 50, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diaryEntry.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(
                    diaryEntry.content,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

