// lib/user_diary_add_screen.dart

import 'dart:io';
import 'package:animal_project/user_health_dashboard_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

const Color kPrimaryColor = Color(0xFFC06362);

class DiaryAddScreen extends StatefulWidget {
  final HealthDashboardViewModel viewModel;
  final DateTime? initialDate;

  const DiaryAddScreen({
    super.key,
    required this.viewModel,
    this.initialDate,
  });

  @override
  State<DiaryAddScreen> createState() => _DiaryAddScreenState();
}

class _DiaryAddScreenState extends State<DiaryAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  late DateTime _selectedDate;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
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

  Future<void> _pickImages() async {
    try {
      if (_selectedImages.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진은 최대 5장까지 첨부할 수 있습니다.')),
        );
        return;
      }

      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        limit: 5 - _selectedImages.length,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 가져오는 데 실패했습니다: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _saveDiary() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await widget.viewModel.addNewDiary(
      _titleController.text,
      _contentController.text,
      _selectedDate,
      _selectedImages,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.viewModel.error ?? '저장에 실패했습니다.')),
      );
      widget.viewModel.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('일기 작성', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: widget.viewModel.isSavingDiary ? null : _saveDiary,
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: kPrimaryColor),
                title: Text(
                  DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
                onTap: () => _pickDate(context),
              ),
              const Divider(),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '제목',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                validator: (value) => (value == null || value.isEmpty) ? '제목을 입력해주세요.' : null,
              ),
              const Divider(),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: '오늘의 건강 상태나 특별한 일을 기록해보세요.',
                  border: InputBorder.none,
                ),
                maxLines: 10,
                style: const TextStyle(fontSize: 16, height: 1.6),
                validator: (value) => (value == null || value.isEmpty) ? '내용을 입력해주세요.' : null,
              ),
              const SizedBox(height: 20),

              _buildImageSelectionArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSelectionArea() {
    if (_selectedImages.isEmpty) {
      return Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: _pickImages,
          child: const Center(
            child: Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 32),
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length + (_selectedImages.length < 5 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _selectedImages.length) {
            return Container(
              margin: const EdgeInsets.only(right: 12),
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: InkWell(
                onTap: _pickImages,
                child: const Center(
                  child: Icon(Icons.add, color: Colors.grey, size: 32),
                ),
              ),
            );
          }

          return Stack(
            children: [
              Container(
                // ✅ [수정됨] right 중복 제거 완료
                margin: const EdgeInsets.only(right: 12, top: 8),
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(File(_selectedImages[index].path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}