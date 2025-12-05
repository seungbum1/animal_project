// lib/user_diary_edit_screen.dart (수정 완료)

import 'dart:io';
import 'package:animal_project/models/user_health_models.dart';
import 'user_health_dashboard_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:animal_project/user/api_config.dart';


const Color kPrimaryColor = Color(0xFFC06362);

class DiaryEditScreen extends StatefulWidget {
  final HealthDashboardViewModel viewModel;
  final DiaryEntry diaryEntry;

  const DiaryEditScreen({
    super.key,
    required this.viewModel,
    required this.diaryEntry,
  });

  @override
  State<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends State<DiaryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late DateTime _selectedDate;

  final ImagePicker _picker = ImagePicker();
  XFile? _newImageFile;
  String? _existingImageUrl;
  bool _imageRemoved = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.diaryEntry.title);
    _contentController = TextEditingController(text: widget.diaryEntry.content);
    _selectedDate = widget.diaryEntry.date;
    if (widget.diaryEntry.imagePath.isNotEmpty) {
      _existingImageUrl = '${ApiConfig.baseUrl}/${widget.diaryEntry.imagePath.replaceAll('\\', '/')}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    // ... (기존과 동일)
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    // ... (기존과 동일)
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _newImageFile = pickedFile;
          _existingImageUrl = null;
          _imageRemoved = false;
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 가져오는 데 실패했습니다: $e')),
        );
      }
    }
  }

  void _removeImage() {
    // ... (기존과 동일)
    setState(() {
      _newImageFile = null;
      _existingImageUrl = null;
      _imageRemoved = true;
    });
  }

  Future<void> _updateDiary() async {
    // ... (기존과 동일)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await widget.viewModel.updateExistingDiary(
      widget.diaryEntry.id,
      _titleController.text,
      _contentController.text,
      _selectedDate,
      _newImageFile,
      _imageRemoved,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.viewModel.error ?? '수정에 실패했습니다.')),
      );
      widget.viewModel.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasImage = _newImageFile != null || _existingImageUrl != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // ... (기존과 동일)
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('일기 수정', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: widget.viewModel.isSavingDiary ? null : _updateDiary,
            child: widget.viewModel.isSavingDiary
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: kPrimaryColor))
                : const Text('저장', style: TextStyle(color: kPrimaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (날짜 선택, 제목 입력은 기존과 동일) ...
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: kPrimaryColor),
                title: Text(DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate), style: const TextStyle(fontSize: 16)),
                onTap: () => _pickDate(context),
              ),
              const Divider(),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: '제목', border: InputBorder.none),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                validator: (value) => (value == null || value.isEmpty) ? '제목을 입력해주세요.' : null,
              ),
              const Divider(),
              // ✅✅✅ [ 2번 에러 수정 ] ✅✅✅
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(hintText: '오늘의 건강 상태나 특별한 일을 기록해보세요.', border: InputBorder.none), // ✅ InputVordezr -> InputBorder
                maxLines: 15,
                style: const TextStyle(fontSize: 16, height: 1.6),
                validator: (value) => (value == null || value.isEmpty) ? '내용을 입력해주세요.' : null,
              ),
              const SizedBox(height: 20),

              // ... (이하 이미지 UI는 기존과 동일) ...
              if (!hasImage)
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: InkWell(
                    onTap: _pickImage,
                    child: const Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 32)),
                  ),
                )
              else
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: _newImageFile != null
                              ? FileImage(File(_newImageFile!.path))
                              : NetworkImage(_existingImageUrl!) as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _removeImage,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    )
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}