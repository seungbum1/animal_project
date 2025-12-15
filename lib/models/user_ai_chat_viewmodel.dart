// lib/models/user_ai_chat_viewmodel.dart

import 'package:flutter/material.dart';
import '../models/user_health_models.dart';
import 'package:animal_project/services/user_ai_service.dart';

// -------------------------------------------------------------
// AiChatViewModel
// -------------------------------------------------------------
class AiChatViewModel extends ChangeNotifier {

  final AiService _aiService;

  bool _showTooltip = true;
  bool get showTooltip => _showTooltip;

  PetProfile? _petProfile;
  PetProfile? get petProfile => _petProfile;

  // 기본 시스템 컨텍스트 (초기값)
  String _systemContext;

  // 채팅 내역 (메모리에만 저장, 앱 끄면 사라짐)
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  // 드래그 버튼 초기 위치
  Offset _buttonPosition = const Offset(300, 600);
  Offset get buttonPosition => _buttonPosition;


  AiChatViewModel({required String token, required PetProfile? petProfile})
      : _petProfile = petProfile,
        _aiService = AiService(token: token),
        _systemContext = AiService(token: token).generateSystemPrompt(petProfile, periodDays: 7)
  {
    // ✅ 앱 시작 시 이전 내역 불러오기(DB Load) 제거 -> 바로 환영 메시지 띄움
    _initializeWelcomeMessage();
  }

  void hideTooltip() {
    if (_showTooltip) {
      _showTooltip = false;
      notifyListeners();
    }
  }

  // 초기 환영 메시지 (RAM에만 추가)
  void _initializeWelcomeMessage() {
    String petName = _petProfile?.name ?? "반려동물";
    final welcomeMessage = ChatMessage(
      text: '안녕하세요! 저는 $petName의 건강 데이터를 분석하는 AI 비서입니다. 무엇이 궁금하신가요?',
      isUser: false,
      timestamp: DateTime.now(),
    );
    _messages.add(welcomeMessage);
    // _aiService.saveMessage(welcomeMessage); // ⛔️ 서버 저장 안 함
  }

  void updatePetProfile(PetProfile? newProfile) {
    if (_petProfile == newProfile || (newProfile == null && _petProfile != null)) return;

    _petProfile = newProfile;
    // 프로필 업데이트 시 기본 컨텍스트 갱신
    _systemContext = _aiService.generateSystemPrompt(_petProfile, periodDays: 7);
    notifyListeners();
  }

  void updateButtonPosition(Offset newOffset) {
    _buttonPosition = newOffset;
    notifyListeners();
  }

  // 질문 텍스트에서 '기간' 추출
  int _extractPeriodDays(String text) {
    final regExp = RegExp(r'(\d+)\s*(일|주|달|개월|월)');
    final match = regExp.firstMatch(text);

    if (match == null) return 7; // 기본값 7일

    final int number = int.tryParse(match.group(1)!) ?? 7;
    final String unit = match.group(2)!;

    switch (unit) {
      case '주': return number * 7;
      case '달':
      case '개월':
      case '월': return number * 30;
      case '일':
      default: return number;
    }
  }

  // 의도 분석 (차트 표시용)
  String _analyzeIntent(String text) {
    final lowerText = text.toLowerCase();
    if (lowerText.contains('체중') || lowerText.contains('몸무게') || lowerText.contains('살')) {
      return 'WEIGHT';
    }
    if (lowerText.contains('활동') || lowerText.contains('산책') || lowerText.contains('움직임')) {
      return 'ACTIVITY';
    }
    if (lowerText.contains('섭취') || lowerText.contains('사료') || lowerText.contains('식사') || lowerText.contains('밥')) {
      return 'INTAKE';
    }
    return 'GENERAL';
  }

  // ⭐️ [수정된 핵심 함수] 변수 선언 누락 수정됨
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    // 1. 사용자 질문 분석 (의도 파악)
    final intent = _analyzeIntent(text); // 👈 아까 누락된 부분

    // 2. 기간 추출
    final periodDays = _extractPeriodDays(text);

    // 3. AI에게 보낼 동적 컨텍스트 생성 (기간 반영)
    final dynamicContext = _aiService.generateSystemPrompt(_petProfile, periodDays: periodDays); // 👈 아까 누락된 부분

    // 4. 차트 표시 여부 결정
    final shouldShowChart = intent != 'GENERAL'; // 👈 아까 누락된 부분

    // 5. 사용자 메시지 추가 (화면 표시용)
    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      chartType: shouldShowChart ? intent : null,
    );
    _messages.add(userMessage);
    // _aiService.saveMessage(userMessage); // ⛔️ 서버 저장 안 함 (휘발성)

    _isTyping = true;
    notifyListeners();

    // 6. AI 서버 통신
    final aiResponseText = await _aiService.sendChatMessage(
      text,
      dynamicContext,
      _messages,
    );

    // 7. AI 응답 메시지 추가 (화면 표시용)
    final aiMessage = ChatMessage(
      text: aiResponseText,
      isUser: false,
      timestamp: DateTime.now(),
      chartType: null,
    );
    _messages.add(aiMessage);
    // _aiService.saveMessage(aiMessage); // ⛔️ 서버 저장 안 함 (휘발성)

    _isTyping = false;
    notifyListeners();
  }

  List<dynamic> getChartDataForType(String type) {
    if (_petProfile == null) return [];

    switch (type) {
      case 'WEIGHT': return _petProfile!.healthChart.weightDetails;
      case 'ACTIVITY': return _petProfile!.healthChart.activityDetails;
      case 'INTAKE': return _petProfile!.healthChart.intakeDetails;
      default: return [];
    }
  }
}