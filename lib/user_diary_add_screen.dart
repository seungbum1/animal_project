// lib/user_diary_add_screen.dart (이미지 첨부 기능 추가 완료)

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http_parser/http_parser.dart';
import 'package:animal_project/api_config.dart';

// 다른 파일에 정의된 kPrimaryColor를 가져오거나 여기에 직접 정의합니다.
const Color kPrimaryColor = Color(0xFFC06362);

class DiaryAddScreen extends StatefulWidget {
  final String token;
  const DiaryAddScreen({super.key, required this.token});

  @override
  State<DiaryAddScreen> createState() => _DiaryAddScreenState();
}

class _DiaryAddScreenState extends State<DiaryAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  // 이미지 관련 상태 변수
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 날짜 선택 다이얼로그를 표시하는 함수
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

  /// 갤러리에서 이미지를 선택하는 함수
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
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

  /// 선택된 이미지를 제거하는 함수
  void _removeImage() {
    setState(() {
      _imageFile = null;
    });
  }

  /// 일기 데이터를 서버에 저장하는 함수 (Multipart Request 사용)
  Future<void> _saveDiary() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Multipart request 생성
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/diaries'));

      // 헤더 추가
      request.headers['Authorization'] = 'Bearer ${widget.token}';

      // 텍스트 필드 추가
      request.fields['title'] = _titleController.text;
      request.fields['content'] = _contentController.text;
      request.fields['date'] = _selectedDate.toIso8601String();

      // 이미지 파일이 선택되었다면 파일 추가
      if (_imageFile != null) {
        final file = await http.MultipartFile.fromPath(
          'image', // 백엔드에서 받을 필드 이름
          _imageFile!.path,
          contentType: MediaType('image', 'jpeg'), // 이미지 타입에 맞게 수정 가능
        );
        request.files.add(file);
      }

      // 요청 전송 및 응답 처리
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 && mounted) {
        Navigator.of(context).pop(true);
      } else {
        // 서버에서 온 에러 메시지를 포함하여 좀 더 자세한 정보 제공
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception('일기 저장 실패 (Status code: ${response.statusCode}): ${responseBody['message'] ?? '알 수 없는 오류'}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
            onPressed: _isSaving ? null : _saveDiary,
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
              // --- 날짜 선택 ---
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: kPrimaryColor),
                title: Text(
                  DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () => _pickDate(context),
              ),
              const Divider(),
              // --- 제목 입력 ---
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '제목',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '제목을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const Divider(),
              // --- 내용 입력 ---
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: '오늘의 건강 상태나 특별한 일을 기록해보세요.',
                  border: InputBorder.none,
                ),
                maxLines: 15,
                style: const TextStyle(fontSize: 16, height: 1.6),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '내용을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // --- 이미지 첨부 UI ---
              if (_imageFile == null)
              // 이미지가 없을 때
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: _pickImage,
                    child: const Center(
                      child: Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 32),
                    ),
                  ),
                )
              else
              // 이미지가 있을 때
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(_imageFile!.path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // 이미지 제거 버튼
                    InkWell(
                      onTap: _removeImage,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
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