// lib/viewmodels/user_ai_chat_viewmodel.dart (MongoDB 연동 버전)

import 'package:flutter/material.dart';
import '../models/user_health_models.dart';
import 'package:animal_project/services/user_ai_service.dart';


// -------------------------------------------------------------
// AiChatViewModel
// -------------------------------------------------------------
class AiChatViewModel extends ChangeNotifier {

  final AiService _aiService;
  // ⭐️ late final 제거하고 null 허용으로 변경
  PetProfile? _petProfile;
  PetProfile? get petProfile => _petProfile;

  String _systemContext;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  // ⭐️ [복구 핵심] 초기 위치를 최초에 보였던 고정값으로 되돌립니다.
  Offset _buttonPosition = const Offset(300, 600);
  Offset get buttonPosition => _buttonPosition;


  AiChatViewModel({required String token, required PetProfile? petProfile})
      : _petProfile = petProfile,
        _aiService = AiService(token: token),
  // ⭐️ 초기 Context를 여기서 생성합니다.
        _systemContext = AiService(token: token).generateSystemPrompt(petProfile, periodDays: 7)
  {
    // ⭐️ [수정] 앱 시작 시 MongoDB에서 메시지를 로드합니다.
    _loadMessagesFromServer();
  }

  // ⭐️ [신규] 서버에서 메시지 로드 및 초기화
  Future<void> _loadMessagesFromServer() async {
    // ⭐️ [핵심] 서버에서 내역 로드
    final savedMessages = await _aiService.loadMessages();

    if (savedMessages.isNotEmpty) {
      _messages.addAll(savedMessages);
    } else {
      // 서버에 메시지가 없으면 초기 AI 환영 메시지 추가
      _initializeWelcomeMessage();
    }
    notifyListeners();
  }

  // ⭐️ [수정] 초기 환영 메시지 로직: 서버 저장 로직 추가
  void _initializeWelcomeMessage() {
    String petName = _petProfile?.name ?? "반려동물";
    final welcomeMessage = ChatMessage(
      text: '안녕하세요! 저는 ${petName}의 건강 데이터를 분석하는 AI 비서입니다. 무엇이 궁금하신가요?',
      isUser: false,
      timestamp: DateTime.now(),
    );
    _messages.add(welcomeMessage);
    // ⭐️ [핵심] 환영 메시지도 서버에 저장 (await 없이 비동기 처리)
    _aiService.saveMessage(welcomeMessage);
  }


  void updatePetProfile(PetProfile? newProfile) {
    // 이미 같은 인스턴스이거나, 데이터가 이미 있는 경우 중복 실행 방지
    if (_petProfile == newProfile || newProfile == null && _petProfile != null) return;

    _petProfile = newProfile;
    // 프로필이 업데이트되면 시스템 컨텍스트를 다시 만듭니다.
    _systemContext = _aiService.generateSystemPrompt(_petProfile, periodDays: 7);
    // 채팅 내역은 유지됩니다.
    // notifyListeners(); // 버튼 위치 변화가 없으므로 필요 없음
  }

  void updateButtonPosition(Offset newOffset) {
    _buttonPosition = newOffset;
    notifyListeners();
  }

  // ⭐️ [수정] 질문에서 기간(숫자)을 추출하는 함수 (유연하게 변경됨)
  int _extractPeriodDays(String text) {
    // 예: '20일 체중 변화', '3주 변화', '2달 변화' -> 숫자와 단위만 있으면 추출
    final regExp = RegExp(r'(\d+)\s*(일|주|달|개월|월)');
    final match = regExp.firstMatch(text);

    if (match == null) return 7;

    final int number = int.tryParse(match.group(1)!) ?? 7;
    final String unit = match.group(2)!;

    switch (unit) {
      case '주':
        return number * 7;
      case '달':
      case '개월':
      case '월':
        return number * 30;
      case '일':
      default:
        return number;
    }
  }

  // ⭐️ [수정] sendMessage 함수: 유동적으로 Context를 업데이트하고 MongoDB에 저장
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    final intent = _analyzeIntent(text);
    final shouldShowChart = intent != 'GENERAL';

    // ⭐️ [핵심] 유동적인 기간 추출 및 Context 업데이트
    final int requestedDays = _extractPeriodDays(text);

    // AI에 전송할 새로운 Context 생성 (요청된 기간 포함)
    final String dynamicContext = _aiService.generateSystemPrompt(_petProfile, periodDays: requestedDays);


    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      chartType: shouldShowChart ? intent : null,
    );

    _messages.add(userMessage);
    // ⭐️ [핵심] 사용자 메시지 서버 저장 (await 없이 비동기 처리)
    _aiService.saveMessage(userMessage);

    _isTyping = true;
    notifyListeners();

    // AI 통신: 추출된 기간으로 업데이트된 Context를 전달
    final aiResponseText = await _aiService.sendChatMessage(
      text,
      dynamicContext,
      _messages,
    );

    final aiMessage = ChatMessage(
      text: aiResponseText,
      isUser: false,
      timestamp: DateTime.now(),
      chartType: null,
    );

    _messages.add(aiMessage);
    // ⭐️ [핵심] AI 응답 메시지 서버 저장 (await 없이 비동기 처리)
    _aiService.saveMessage(aiMessage);

    _isTyping = false;
    notifyListeners();
  }

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

  List<dynamic> getChartDataForType(String type) {
    if (_petProfile == null) return [];

    switch (type) {
      case 'WEIGHT':
        return _petProfile!.healthChart.weightDetails;
      case 'ACTIVITY':
        return _petProfile!.healthChart.activityDetails;
      case 'INTAKE':
        return _petProfile!.healthChart.intakeDetails;
      default:
        return [];
    }
  }
}