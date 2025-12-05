// lib/user_diary_repository.dart (MIME Type 명시 추가)

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // ✅ [필수] 이걸 위해 패키지 추가 필요할 수 있음 (보통 기본 포함)
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:animal_project/user/api_config.dart';
import 'package:animal_project/models/user_health_models.dart';

class DiaryRepository {
  final String token;
  String get baseUrl => ApiConfig.baseUrl;

  DiaryRepository({required this.token});

  // 🔹 내부 헬퍼 함수: 플랫폼에 맞춰 이미지 압축 수행
  Future<XFile> _compressImage(XFile file) async {
    // 1. 모바일 (Android / iOS)
    if (Platform.isAndroid || Platform.isIOS) {
      final String targetPath = file.path;
      final int lastIndex = targetPath.lastIndexOf(RegExp(r'.jp|.pn|.he|.we'));
      final String splitted = lastIndex != -1 ? targetPath.substring(0, lastIndex) : targetPath;
      final String outPath = "${splitted}_out.jpg";

      try {
        var result = await FlutterImageCompress.compressAndGetFile(
          file.path,
          outPath,
          minWidth: 1024,
          minHeight: 1024,
          quality: 70,
        );
        if (result != null) return result;
      } catch (e) {
        print("📱 모바일 압축 실패 (원본 반환): $e");
      }
      return file;
    }
    // 2. 그 외 (Windows / Mac / Linux)
    else {
      try {
        final File originFile = File(file.path);
        final List<int> bytes = await originFile.readAsBytes();
        final img.Image? image = img.decodeImage(bytes as dynamic);

        if (image == null) return file;

        final img.Image resized = img.copyResize(image, width: 1024);
        // ✅ 무조건 JPG로 변환됨
        final List<int> jpg = img.encodeJpg(resized, quality: 70);

        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(jpg);

        return XFile(tempPath);
      } catch (e) {
        print("💻 PC 압축 실패 (원본 반환): $e");
        return file;
      }
    }
  }

  Future<DiaryEntry> addDiary(String title, String content, DateTime date, List<XFile> imageFiles) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/diaries'));
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['content'] = content;
    request.fields['date'] = date.toIso8601String();

    for (var image in imageFiles) {
      XFile fileToSend = await _compressImage(image);

      // ✅ [핵심 수정] Content-Type을 image/jpeg로 강제 지정
      // (압축 로직에서 무조건 .jpg로 만들었으므로 jpeg가 맞음)
      request.files.add(await http.MultipartFile.fromPath(
        'images',
        fileToSend.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    try {
      final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return DiaryEntry.fromJson(data);
      } else {
        throw Exception('일기 저장 실패 (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('서버 전송 오류: $e');
    }
  }

  Future<DiaryEntry> updateDiary(String id, String title, String content, DateTime date, XFile? newImage, bool imageRemoved) async {
    var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/diaries/$id'));
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['content'] = content;
    request.fields['date'] = date.toIso8601String();
    request.fields['imageRemoved'] = imageRemoved.toString();

    if (newImage != null) {
      XFile fileToSend = await _compressImage(newImage);

      // ✅ [핵심 수정] 수정 시에도 Content-Type 지정
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        fileToSend.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final streamedResponse = await request.send().timeout(const Duration(minutes: 1));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return DiaryEntry.fromJson(data);
    } else {
      throw Exception('일기 수정 실패: ${response.body}');
    }
  }

  Future<void> deleteDiary(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/diaries/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('일기 삭제 실패: ${response.body}');
    }
  }
}