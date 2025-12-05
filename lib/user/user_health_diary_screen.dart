// lib/user_health_diary_screen.dart

import 'user_diary_add_screen.dart';
import 'user_diary_detail_screen.dart';
import 'user_health_main.dart' hide kPrimaryColor;
import 'user_health_dashboard_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user_health_models.dart';   // 🔥 이건 한 폴더 위로 가서 models
import 'package:animal_project/user/api_config.dart';

class HealthDiaryScreen extends StatelessWidget {
  final HealthDashboardViewModel viewModel;   // ⭐ token X, viewModel만 사용
  const HealthDiaryScreen({super.key, required this.viewModel});

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, child) {
        final petProfile = viewModel.petProfile;

        if (viewModel.isLoading || petProfile == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: _buildAppBar(context),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final diaries = petProfile.diaries;
        diaries.sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(context),
          body: diaries.isEmpty
              ? const Center(
            child: Text(
              '작성된 일기가 없습니다.\n우측 하단 버튼을 눌러 첫 일기를 작성해보세요!',
              textAlign: TextAlign.center,
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: diaries.length,
            itemBuilder: (context, index) {
              final entry = diaries[index];
              return _buildDiaryCard(context, entry);
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final DateTime dateToSuggest = DateTime.now();

              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => DiaryAddScreen(
                    viewModel: viewModel,
                    initialDate: dateToSuggest,
                  ),
                ),
              );
            },
            backgroundColor: kPrimaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        '건강 일기',
        style: TextStyle(color: Colors.black),
      ),
      centerTitle: true,
    );
  }

  Widget _buildDiaryCard(BuildContext context, DiaryEntry entry) {
    final imageUrl = entry.imagePath.isNotEmpty
        ? '$_baseUrl/${entry.imagePath.replaceAll('\\', '/')}'
        : '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => DiaryDetailScreen(
                diaryEntry: entry,
                viewModel: viewModel,   // ⭐ token 대신 viewModel 넘김
              ),
            ),
          );
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
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                  )
                      : Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.photo, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('yyyy년 MM월 dd일').format(entry.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
