// health_dashboard_viewmodel.dart

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:animal_project/models/user_health_models.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:animal_project/api_config.dart';

// ✅ [개선] 화면의 모든 상태와 로직을 관리하는 ViewModel 클래스
// UI는 이 클래스의 데이터만 보고 화면을 그리는 역할만 담당합니다.
class HealthDashboardViewModel extends ChangeNotifier {
  final String token;

  // --- 상태 변수 (Private) ---
  PetProfile? _petProfile;
  bool _isLoading = true;
  String? _error;
  String _medicationMessage = '';

  // --- UI 노출용 Getter (Public) ---
  PetProfile? get petProfile => _petProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get medicationMessage => _medicationMessage;

  String get _baseUrl => ApiConfig.baseUrl;

  // --- 생성자 ---
  HealthDashboardViewModel({required this.token}) {
    fetchPetProfile(); // ViewModel이 생성될 때 데이터 로드를 시작합니다.
  }

  // --- 데이터 로직 ---
  Future<void> fetchPetProfile() async {
    // 데이터 로드 전, 로딩 상태로 전환하고 이전 에러를 초기화합니다.
    _isLoading = true;
    _error = null;
    notifyListeners(); // 상태 변경을 UI에 알립니다.

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _petProfile = PetProfile.fromJson(data['user']['petProfile'] ?? {});
        _updateMedicationMessage(); // 데이터 로드 성공 시, 복용 메시지를 업데이트합니다.
      } else {
        _error = '프로필 정보를 불러오는 데 실패했습니다.';
      }
    } catch (e) {
      debugPrint('Error fetching pet profile: $e');
      _error = '데이터 로딩 중 오류가 발생했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners(); // 로드가 끝나면(성공/실패 무관) 상태 변경을 알립니다.
    }
  }

  // ✅ [개선] 복용 알림 메시지를 동적으로 생성하는 로직
  void _updateMedicationMessage() {
    if (_petProfile == null || _petProfile!.alarms.isEmpty) {
      _medicationMessage = '설정된 복용 알람이 없습니다. 💊';
      return;
    }

    // To-Do: 실제 알람 시간과 현재 시간을 비교하여
    // "3시간 뒤 약을 복용할 시간입니다.", "오늘 복용 완료!" 등
    // 더 동적인 메시지를 생성하는 로직을 여기에 구현할 수 있습니다.
    // 지금은 간단한 메시지로 대체합니다.
    _medicationMessage = '${_petProfile!.alarms.length}개의 복용 알람이 설정되어 있어요.';
  }
}