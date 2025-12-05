// ❌ import 'dart:convert';
import 'dart:io';
import 'package:animal_project/models/user_health_models.dart';
import 'user_diary_edit_screen.dart';
import 'user_health_dashboard_viewmodel.dart'; // ✅ [추가]
import 'package:flutter/material.dart';
// ❌ import 'package:http/http.dart' as http;
import 'package:animal_project/user/api_config.dart';

// ✅ [추가] 건강 차트 색상 (일관된 UI를 위해)
const Color kLineColor1 = Color(0xFF547AA5); // 체중
const Color kLineColor2 = Color(0xFF6A994E); // 활동량
const Color kLineColor3 = Color(0xFFE9C46A); // 섭취량

class DiaryDetailScreen extends StatelessWidget {
  final DiaryEntry diaryEntry;
  // ❌ [삭제] final String token;
  // ✅ [추가]
  final HealthDashboardViewModel viewModel;

  const DiaryDetailScreen({
    super.key,
    required this.diaryEntry,
    required this.viewModel, // ✅ [수정]
  });

  String get _baseUrl => ApiConfig.baseUrl;

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  // ❌ [삭제] _deleteDiary(BuildContext context) 메서드 전체

  // --- ✅ [수정] 삭제 확인 대화상자 ---
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
              onPressed: () async { // ✅ async 추가
                Navigator.of(ctx).pop(); // 대화상자 먼저 닫기

                // ✅ [수정] ViewModel의 삭제 메서드 호출
                final success = await viewModel.deleteExistingDiary(diaryEntry.id);

                if (success && context.mounted) {
                  // ✅ [수정] 상세 화면 닫기 (pop(true) 불필요)
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('일기가 삭제되었습니다.')),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(viewModel.error ?? '삭제에 실패했습니다.')),
                  );
                  viewModel.clearError();
                }
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

    // ✅ [추가] ViewModel에서 건강 기록 가져오기
    // getHealthRecordsForDate는 이미 ViewModel에 구현되어 있습니다.
    final healthRecords = viewModel.getHealthRecordsForDate(diaryEntry.date);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // ... (AppBar UI는 기존과 동일) ...
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
              // ✅ [수정] 수정 화면으로 이동
              await Navigator.push<bool>( // ✅ [수정] result 변수 제거 (불필요)
                context,
                MaterialPageRoute(
                  builder: (context) => DiaryEditScreen(
                    // ❌ [삭제] token: token,
                    viewModel: viewModel, // ✅ [추가]
                    diaryEntry: diaryEntry,
                  ),
                ),
              );
              // ❌ [삭제] pop(true)를 확인하던 .then() 블록 또는 if (result == true) 블록 제거
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black54),
            onPressed: () => _showDeleteConfirmation(context), // ✅ 수정된 함수 호출
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. 이미지 (기존과 동일) ---
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

            // --- 2. 일기 본문 (기존과 동일) ---
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

            // --- 3. ✅✅✅ [핵심 추가] 그날의 건강 기록 섹션 ✅✅✅ ---
            if (healthRecords.isNotEmpty)
              _buildHealthSummarySection(healthRecords),

            // 하단 여백
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ✅ [추가] 건강 기록 요약 섹션 위젯
  Widget _buildHealthSummarySection(Map<String, String> records) {
    return Padding(
      // 좌우 패딩은 일기 본문(20.0)과 동일하게 맞춥니다.
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50, // 일기 본문과 시각적 분리
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이날의 건강 기록',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),

            // ViewModel에서 가져온 데이터 키를 확인하여 위젯을 동적으로 생성합니다.
            if (records.containsKey('체중'))
              _buildHealthRecordRow(
                Icons.monitor_weight_outlined,
                kLineColor1, // 체중 색상
                '체중',
                records['체중']!,
              ),
            if (records.containsKey('활동 시간'))
              _buildHealthRecordRow(
                Icons.directions_run_outlined,
                kLineColor2, // 활동량 색상
                '활동 시간',
                records['활동 시간']!,
              ),
            if (records.containsKey('사료량'))
              _buildHealthRecordRow(
                Icons.restaurant_menu_outlined,
                kLineColor3, // 섭취량 색상
                '사료량',
                records['사료량']!,
              ),

            // 만약 '물'이나 '소모 칼로리' 등 다른 데이터도 getHealthRecordsForDate가 반환한다면
            // 여기에 추가할 수 있습니다. (현재는 3가지만 반환)
          ],
        ),
      ),
    );
  }

  // ✅ [추가] 건강 기록 개별 행 위젯
  Widget _buildHealthRecordRow(IconData icon, Color color, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const Spacer(), // 제목과 값 사이에 공간을 최대로 확보
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}