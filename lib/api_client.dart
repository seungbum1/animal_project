// lib/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'main.dart';

class ApiClient {
  final String baseUrl;
  static const String apiPrefix = '/api';      // ✅ 공통 prefix
  static const String authPrefix = '$apiPrefix/auth'; // ✅ 인증 prefix
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // ─────────── 공통/헬스 ───────────
  Future<Map<String, dynamic>> health() async {
    final res = await http.get(_u('/health'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─────────── 인증/계정 ───────────
  Future<Map<String, dynamic>> checkId(String email) async {
    final res = await http.get(_u('/auth/check-id', {'email': email}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? name,
    String? birthDate,
  }) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
      if (name != null) 'name': name,
      if (birthDate != null) 'birthDate': birthDate,
    });
    final res =
    await http.post(_u('/auth/signup'), headers: _headers(), body: body);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> signupWithInvite({
    required String email,
    required String password,
    required String inviteCode,
    String? name,
  }) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
      'inviteCode': inviteCode,
      if (name != null) 'name': name,
    });
    final res = await http.post(_u('/auth/signup-with-invite'),
        headers: _headers(), body: body);
    return jsonDecode(res.body);
  }

  /// return: { token: "...", user: {...} }
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(_u('/auth/login'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password}));
    return jsonDecode(res.body);
  }

  /// 일반 사용자 내 프로필
  Future<Map<String, dynamic>> usersMe(String token) async {
    final res = await http.get(_u('/users/me'), headers: _headers(token: token));
    return jsonDecode(res.body);
  }

  /// 병원 관리자 내 프로필
  Future<Map<String, dynamic>> hospitalMe(String token) async {
    final res =
    await http.get(_u('/hospital/me'), headers: _headers(token: token));
    return jsonDecode(res.body);
  }

  /// 반려동물 프로필 업데이트 (USER)
  Future<Map<String, dynamic>> updateMyPet(
      String token, {
        String? name,
        int? age,
        String? gender,
        String? species,
        String? avatarUrl,
      }) async {
    final body = jsonEncode({
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (species != null) 'species': species,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    final res = await http.put(_u('/users/me/pet'),
        headers: _headers(token: token), body: body);
    return jsonDecode(res.body);
  }

  // ─────────── 병원 목록/연동 ───────────
  Future<List<dynamic>> listHospitals() async {
    final res = await http.get(_u('/api/hospitals'));
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// 사용자 기준: 연동 가능 병원 + 내 상태
  Future<Map<String, dynamic>> availableHospitalLinks(String token) async {
    final res = await http.get(_u('/api/hospital-links/available'),
        headers: _headers(token: token));
    return jsonDecode(res.body);
  }

  /// 특정 병원에 연동 요청
  Future<Map<String, dynamic>> requestHospitalLink(
      String token, String hospitalId) async {
    final res = await http.post(_u('/api/hospital-links/request'),
        headers: _headers(token: token),
        body: jsonEncode({'hospitalId': hospitalId}));
    return jsonDecode(res.body);
  }

  /// 내가 연동한 병원 목록 (승인된 것만 기본)
  Future<Map<String, dynamic>> myHospitals(String token, {bool all = false}) async {
    final res = await http.get(
        _u('/api/users/me/hospitals', all ? {'all': '1'} : null),
        headers: _headers(token: token));
    return jsonDecode(res.body);
  }

  // ─────────── 예약(유저) ───────────
  Future<Map<String, dynamic>> getAppointmentMeta(String hospitalId) async {
    final res =
    await http.get(_u('/api/hospitals/$hospitalId/appointment-meta'));
    return jsonDecode(res.body);
  }

  /// 예약 신청 (USER) -> 병원DB + 사용자DB 동시 저장
  Future<Map<String, dynamic>> requestAppointment(
      String token, {
        required String hospitalId,
        required String service,
        required String doctorName,
        required String date, // 'YYYY-MM-DD'
        required String time, // 'HH:mm'
        String? hospitalName,
        String? userName,
        String? petName,
        DateTime? visitDateTime, // 가능하면 함께 전송
      }) async {
    final body = {
      'service': service,
      'doctorName': doctorName,
      'date': date,
      'time': time,
      if (hospitalName != null) 'hospitalName': hospitalName,
      if (userName != null) 'userName': userName,
      if (petName != null) 'petName': petName,
      if (visitDateTime != null) 'visitDateTime': visitDateTime.toIso8601String(),
    };
    final res = await http.post(
      _u('/api/hospitals/$hospitalId/appointments/request'),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  /// 내 예약 목록(옵션: 병원/월 범위)
  Future<Map<String, dynamic>> myAppointments(
      String token, {
        String? hospitalId,
        String? month, // 'YYYY-MM'
      }) async {
    final q = <String, String>{};
    if (hospitalId != null) q['hospitalId'] = hospitalId;
    if (month != null) q['month'] = month;
    final res = await http.get(_u('/api/users/me/appointments', q),
        headers: _headers(token: token));
    return jsonDecode(res.body);
  }

  /// 월간 전용 (달력용 빠른 조회)
  Future<List<dynamic>> myAppointmentsMonthly(
      String token, {
        required String month, // 'YYYY-MM'
        String? hospitalId,
      }) async {
    final q = {'month': month, if (hospitalId != null) 'hospitalId': hospitalId};
    final res = await http.get(_u('/api/users/me/appointments/monthly', q),
        headers: _headers(token: token));
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// 내 예약 삭제 (user_appointments 기준 ID)
  Future<void> deleteMyAppointment(String token, String id) async {
    final res = await http.delete(
      _u('/api/users/me/appointments/$id'),
      headers: _headers(token: token),
    );
    if (res.statusCode != 204) {
      throw Exception('Failed to delete: ${res.statusCode} ${res.body}');
    }
  }

  // ─────────── 예약(관리자) ───────────
  /// 병원 관리자: 예약 수신함
  Future<Map<String, dynamic>> adminAppointments(
      String token, {
        String? status, // PENDING, APPROVED, REJECTED, CANCELED
        String order = 'desc',
      }) async {
    final q = <String, String>{'order': order};
    if (status != null) q['status'] = status;
    final res = await http.get(_u('/api/hospital-admin/appointments', q),
        headers: _headers(token: token));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> adminApprove(String token, String apptId) async {
    final res = await http.post(
      _u('/api/hospital-admin/appointments/$apptId/approve'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> adminReject(String token, String apptId) async {
    final res = await http.post(
      _u('/api/hospital-admin/appointments/$apptId/reject'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  // ─────────── 사용자 화면용: 병원 대시보드 텍스트 ───────────
  Future<Map<String, dynamic>> userDashboard(String token, String hospitalId) async {
    final res = await http.get(
      _u('/api/hospitals/$hospitalId/user-dashboard'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }
}
