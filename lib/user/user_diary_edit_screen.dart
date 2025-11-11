// lib/user_diary_edit_screen.dart (신규 파일)

import 'dart:io';
import 'dart:convert';
import 'package:animal_project/models/user_health_models.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http_parser/http_parser.dart';
import 'package:animal_project/api_config.dart';


const Color kPrimaryColor = Color(0xFFC06362);

class DiaryEditScreen extends StatefulWidget {
  final String token;
  final DiaryEntry diaryEntry;

  const DiaryEditScreen({
    super.key,
    required this.token,
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
  bool _isSaving = false;

  // --- 이미지 관련 상태 변수 ---
  final ImagePicker _picker = ImagePicker();
  XFile? _newImageFile; // 새로 선택된 이미지 파일
  String? _existingImageUrl; // 기존 이미지 URL
  bool _imageRemoved = false; // 기존 이미지가 제거되었는지 여부

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    // 위젯의 초기 데이터로 상태 변수들을 초기화합니다.
    _titleController = TextEditingController(text: widget.diaryEntry.title);
    _contentController = TextEditingController(text: widget.diaryEntry.content);
    _selectedDate = widget.diaryEntry.date;
    if (widget.diaryEntry.imagePath.isNotEmpty) {
      _existingImageUrl = '$_baseUrl/${widget.diaryEntry.imagePath.replaceAll('\\', '/')}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
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
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _newImageFile = pickedFile;
          _existingImageUrl = null; // 새로 이미지를 고르면 기존 이미지는 보이지 않게 처리
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
    setState(() {
      _newImageFile = null;
      _existingImageUrl = null;
      _imageRemoved = true; // 이미지 제거 플래그 활성화
    });
  }

  /// 일기 데이터를 서버에 수정 요청하는 함수
  Future<void> _updateDiary() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/diaries/${widget.diaryEntry.id}'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';

      // 텍스트 필드 추가
      request.fields['title'] = _titleController.text;
      request.fields['content'] = _contentController.text;
      request.fields['date'] = _selectedDate.toIso8601String();

      // --- 이미지 처리 로직 ---
      // 1. 새로 선택된 이미지가 있으면 파일 추가
      if (_newImageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _newImageFile!.path, contentType: MediaType('image', 'jpeg')));
      }
      // 2. 기존 이미지가 제거되었다면, imagePath를 빈 문자열로 보내 서버에서 처리하도록 함
      else if (_imageRemoved) {
        request.fields['imagePath'] = '';
      }
      // 3. 이미지 변경이 없으면 아무것도 보내지 않음 (서버에서 기존 경로 유지)

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 && mounted) {
        Navigator.of(context).pop(true); // 수정 성공 시 true 반환
      } else {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('일기 수정 실패 (Status code: ${response.statusCode}): ${responseBody['message'] ?? '알 수 없는 오류'}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 표시해야 할 이미지가 있는지 확인
    bool hasImage = _newImageFile != null || _existingImageUrl != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
            onPressed: _isSaving ? null : _updateDiary,
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
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
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(hintText: '오늘의 건강 상태나 특별한 일을 기록해보세요.', border: InputBorder.none),
                maxLines: 15,
                style: const TextStyle(fontSize: 16, height: 1.6),
                validator: (value) => (value == null || value.isEmpty) ? '내용을 입력해주세요.' : null,
              ),
              const SizedBox(height: 20),

              // --- 이미지 첨부 UI 수정 ---
              if (!hasImage)
              // 표시할 이미지가 없을 때
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
              // 표시할 이미지가 있을 때
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          // 새로 선택한 이미지를 우선으로 보여주고, 없으면 기존 이미지를 보여줌
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