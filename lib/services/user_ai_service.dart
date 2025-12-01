// lib/services/user_ai_service.dart (최종 유동 기간 컨텍스트 생성 버전)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/user_health_models.dart';
import '../api_config.dart';

// -------------------------------------------------------------
// ChatMessage 모델
// -------------------------------------------------------------
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? chartType;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.chartType,
  });
}

// -------------------------------------------------------------
// AiService (AI 통신 및 컨텍스트 생성 담당)
// -------------------------------------------------------------
class AiService {
  final String token;
  static final String _baseUrl = ApiConfig.baseUrl;
  static final String _aiEndpoint = '$_baseUrl/api/ai-chat';
  // ⭐️ [추가] MongoDB와 통신할 엔드포인트
  static final String _chatHistoryEndpoint = '$_baseUrl/api/chat-history';

  AiService({required this.token});

  Future<void> saveMessage(ChatMessage message) async {
    try {
      await http.post(
        Uri.parse(_chatHistoryEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'isUser': message.isUser,
          'text': message.text,
          'timestamp': message.timestamp.toIso8601String(),
          // chartType는 백엔드에서 필요 없으면 제외 가능
        }),
      );
    } catch (e) {
      // 서버 저장 실패 시 로깅 또는 사용자에게 알림 (앱 사용에는 지장 없음)
      debugPrint('Error saving chat message to MongoDB: $e');
    }
  }

  Future<List<ChatMessage>> loadMessages() async {
    try {
      final response = await http.get(
        Uri.parse(_chatHistoryEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> historyData = json.decode(utf8.decode(response.bodyBytes));

        return historyData.map((item) {
          return ChatMessage(
            text: item['text'] as String,
            isUser: item['isUser'] as bool,
            timestamp: DateTime.parse(item['timestamp'] as String),
            chartType: item['chartType'] as String?, // chartType은 MongoDB에서 가져올 수도 있습니다.
          );
        }).toList();

      } else {
        debugPrint('Failed to load chat history (Code: ${response.statusCode})');
        return [];
      }
    } catch (e) {
      debugPrint('Network error loading chat history: $e');
      return [];
    }
  }

  // ⭐️ [수정] generateSystemPrompt에 periodDays 인자 추가 (선택적 인자)
  String generateSystemPrompt(PetProfile? profile, {int? periodDays}) {
    if (profile == null || profile.name.isEmpty) {
      return "당신은 수의학 AI 비서입니다. 반려동물 정보가 없습니다. 일반적인 건강 질문에만 답변하세요.";
    }

    // 데이터 추출 및 최신 기록 포맷팅
    final weightRecords = profile.healthChart.weightDetails;
    final activityRecords = profile.healthChart.activityDetails;
    final intakeRecords = profile.healthChart.intakeDetails;

    final lastWeight = weightRecords.isNotEmpty
        ? "${weightRecords.last.bodyWeight?.toStringAsFixed(1) ?? 'N/A'}kg"
        : '기록 없음';
    final lastActivity = activityRecords.isNotEmpty
        ? "${activityRecords.last.time ?? 'N/A'}분"
        : '기록 없음';
    final lastIntake = intakeRecords.isNotEmpty
        ? "${intakeRecords.last.food ?? 'N/A'}g"
        : '기록 없음';

    // ⭐️ [핵심] 사용자가 요청한 기간(또는 기본 7일)의 체중 추세를 계산
    int targetPeriod = periodDays ?? 7;
    String targetTrend = _calculateTrend(
        weightRecords.map((r) => r.bodyWeight).whereType<double>().toList(), 'kg', targetPeriod);

    final activeAlarms = profile.alarms.where((a) => a.isActive).map((a) => a.label).toList();
    final activeMedicationAlarms = activeAlarms.isNotEmpty ? activeAlarms.join(', ') : '없음';


    // ⭐️ 최종 베테랑 시스템 프롬프트 (유동 기간 반영) ⭐️
    return """
당신은 수의학 지식을 가진 반려동물 건강 및 행동 컨설턴트입니다.
당신의 주 임무는 아래 컨텍스트 데이터를 기반으로 보호자의 질문에 맞춤형으로 응답하는 것입니다.

--- 데이터 컨텍스트 (필요 시 참고) ---
- 이름: ${profile.name} (반드시 호칭에 사용)
- 나이: ${profile.age}세
- 성별: ${profile.gender}
- [최근 상태] 체중: ${lastWeight}kg, 활동: ${lastActivity}분, 섭취: ${lastIntake}g
- [요청 기간 추세] ${targetPeriod}일 변화: ${targetTrend} ⭐️
- [주요 알람] 복약 목록: ${activeMedicationAlarms}
----------------------------------

[안전 제약]
1. 진단 및 처방 금지: 당신은 실제 수의사가 아닙니다. 어떠한 질병에 대한 진단, 치료법, 약물 처방을 시도해서는 안 됩니다.
2. 병원 권유: 보호자가 심각한 증상을 언급할 경우, 반드시 '가까운 동물병원 수의사와 직접 상담하라'는 문구를 포함해야 합니다.

[대화 스타일 및 유연성]
1. 자아(自我) 제거: 매번 자신을 소개하는 반복적인 구문은 절대 사용하지 마세요. 이미 대화 중임을 인지하고 자연스럽게 이어가세요.
2. 이름 사용: 응답 시 '${profile.name}'의 이름을 자주 사용하여 친밀감을 높이세요.
3. 자연스러운 응대: '안녕' 같은 인사나 일반적인 질문에는 따뜻하고 간결하게 응대하세요.
4. 데이터 활용 조건:
    * 직접 질문: 사용자가 체중 변화를 물으면, 컨텍스트의 [요청 기간 추세]에서 ${targetPeriod}일 데이터를 찾아 답변하세요. 데이터가 부족하면 '데이터 부족'을 언급하세요.
    * 징후 해석: 사용자가 증상이나 징후를 물을 경우, 컨텍스트의 '최근 추세' 데이터를 언급하며 조언의 근거로 사용합니다.
5. 어조/길이: 친절하고 공감하는 어조를 유지하며, 답변은 간결하게 200자 내외로 제공하세요.
""";
  }

  // ⭐️ [수정] _calculateTrend 함수: 유동적인 기간(periodDays)을 처리하도록 수정
  String _calculateTrend(List<double> values, String unit, int periodDays) {
    if (values.length < 2) return '데이터 부족';

    // ⭐️ [핵심 수정] 유동 기간에 맞는 데이터 슬라이싱 로직 강화
    final List<double> targetValues;
    if (periodDays > 0) {
      // 요청된 기간보다 데이터가 적으면 전체 데이터를 사용하고, 아니면 끝에서부터 periodDays만큼 슬라이싱
      targetValues = values.length > periodDays
          ? values.sublist(values.length - periodDays)
          : values;
    } else {
      targetValues = values; // 0일 경우 전체 기간
    }

    // 데이터가 기간을 커버하지 못하거나 충분치 않은 경우
    if(targetValues.length < 2) {
      // ⭐️ [보완] 요청 기간의 데이터가 부족할 경우, AI에게 그 사실을 알려줄 텍스트 제공
      return '요청된 ${periodDays}일간의 데이터 부족';
    }

    final startValue = targetValues.first;
    final endValue = targetValues.last;
    final change = endValue - startValue;

    if (change.abs() < 0.1) return '변화 없음';
    String sign = change > 0 ? '증가' : '감소';
    double absChange = change.abs();

    // AI가 사용할 구체적인 문구 제공
    return "${absChange.toStringAsFixed(1)}${unit} ${sign} (기준: ${targetValues.length}개 기록)";
  }

  // 3. 실제 AI 백엔드 통신 로직
  Future<String> sendChatMessage(String userMessage, String systemContext, List<ChatMessage> history) async {
    final chatHistory = history.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    final messages = [
      {'role': 'system', 'content': systemContext},
      ...chatHistory.skip(chatHistory.length > 10 ? chatHistory.length - 10 : 0),
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http.post(
        Uri.parse(_aiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'messages': messages}),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return decoded['response'] ?? "서버로부터 응답을 받지 못했습니다. (응답 코드는 정상)";
      } else {
        return "AI 서버 통신 오류 (코드: ${response.statusCode}). 잠시 후 다시 시도해 주세요.";
      }
    } catch (e) {
      return "네트워크 연결 오류 또는 백엔드 통신 실패: $e";
    }
  }
}