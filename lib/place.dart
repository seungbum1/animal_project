// lib/place.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SavedPlacesManager {
  // ⚠️ 에뮬레이터 IP 확인 (실기기 테스트 시 본인 PC IP로 변경)
  static const String baseUrl = "http://10.0.2.2:4000";

  static List<Map<String, dynamic>> _places = [];
  static List<Map<String, dynamic>> get places => _places;

  /// 📂 1. 서버에서 목록 불러오기 (토큰 인자 추가)
  static Future<void> loadFromServer(String? token) async {
    try {
      final useToken = (token != null && token.isNotEmpty) ? token : await _getToken();

      if (useToken == null) {
        _places = [];
        return;
      }

      final url = Uri.parse("$baseUrl/api/users/me/saved-places");
      final response = await http.get(url, headers: {
        "Authorization": "Bearer $useToken",
      });

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);

        // ✨ [핵심 수정] 서버 응답이 List인지 Map인지 확인
        if (body is List) {
          _places = List<Map<String, dynamic>>.from(body);
        } else if (body is Map && body['data'] != null) {
          _places = List<Map<String, dynamic>>.from(body['data']);
        } else {
          _places = [];
        }

        print("✅ 서버에서 보관함 로드 완료: ${_places.length}개");
      } else {
        print("❌ 목록 로드 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 서버 연결 오류 (load): $e");
    }
  }

  /// 💾 2. 저장/삭제 토글 (토큰 인자 추가)
  /// 💾 2. 저장/삭제 토글 (수정됨: 409 에러 예외처리 추가)
  static Future<bool> toggleServer(Map<String, dynamic> place, String? token) async {
    try {
      final useToken = (token != null && token.isNotEmpty) ? token : await _getToken();

      if (useToken == null) {
        print("❌ 로그인이 필요합니다.");
        return false;
      }

      // 현재 로컬 상태 확인
      final isAlreadySaved = isSaved(place["place_name"]);

      // URL 인코딩 (한글 깨짐 방지)
      final encodedName = Uri.encodeComponent(place['place_name']);

      final urlString = isAlreadySaved
          ? "$baseUrl/api/users/me/saved-places/$encodedName" // 이미 있으면 삭제 요청
          : "$baseUrl/api/users/me/saved-places";            // 없으면 저장 요청

      final url = Uri.parse(urlString);
      http.Response response;

      if (isAlreadySaved) {
        // DELETE 요청
        response = await http.delete(url, headers: {
          "Authorization": "Bearer $useToken",
        });
      } else {
        // POST 요청
        response = await http.post(
          url,
          headers: {
            "Authorization": "Bearer $useToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode(place),
        );
      }

      // ✅ 성공 처리 (200 OK, 201 Created)
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (isAlreadySaved) {
          _places.removeWhere((p) => p["place_name"] == place["place_name"]);
          return false; // 저장 해제됨
        } else {
          _places.add(place);
          return true; // 저장됨
        }
      }
      // ✅ [추가] 409 Conflict 처리 (이미 저장되어 있는 경우)
      else if (response.statusCode == 409) {
        print("⚠️ 이미 서버에 저장된 장소입니다. 로컬 상태를 '저장됨'으로 동기화합니다.");

        // 로컬 리스트에 없으면 추가해줌
        if (!isSaved(place["place_name"])) {
          _places.add(place);
        }
        return true; // 결과적으로 '저장된 상태'이므로 true 반환
      }
      else {
        print("❌ 요청 실패: ${response.statusCode} / ${response.body}");
        return isAlreadySaved; // 실패 시 원래 상태 유지
      }
    } catch (e) {
      print("❌ 에러 발생: $e");
      return false;
    }
  }

  static bool isSaved(String placeName) {
    return _places.any((p) => p["place_name"] == placeName);
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_token');
  }
}