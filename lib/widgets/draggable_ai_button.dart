import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/models/user_ai_chat_viewmodel.dart';
import 'package:animal_project/services/user_ai_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'dart:async'; // Timer 사용을 위해 필수

const double kBottomNavigationBarHeight = 56.0;

// -------------------------------------------------------------
// 상수 정의 (Pro UI 색상 팔레트)
// -------------------------------------------------------------
// ⭐️ [Pro UI] 세련된 그라데이션용 색상
const Color kAiPrimaryDark = Color(0xFFC06362);
const Color kAiPrimaryLight = Color(0xFFE38B8A);

const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);

// 차트 색상
const Color kWeightLineColor = Color(0xFF547AA5);
const Color kMuscleLineColor = Color(0xFF6A994E);
const Color kBodyFatLineColor = Color(0xFFE9C46A);

// -------------------------------------------------------------
// Draggable Button (PRO Version: Animation & Tooltip)
// -------------------------------------------------------------
class DraggableAiButton extends StatefulWidget {
  final PetProfile? petProfile;
  final String token;
  final AiChatViewModel viewModel;

  const DraggableAiButton({
    super.key,
    required this.petProfile,
    required this.token,
    required this.viewModel,
  });

  @override
  State<DraggableAiButton> createState() => _DraggableAiButtonState();
}

class _DraggableAiButtonState extends State<DraggableAiButton> with SingleTickerProviderStateMixin {
  late final AiChatViewModel _viewModel;
  late final AnimationController _breathingController;
  late final Animation<double> _breathingAnimation;
  Timer? _tooltipTimer;

  static const double _buttonSize = 64.0;
  static const double _screenPadding = 16.0;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel;

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    if (_viewModel.showTooltip) {
      _tooltipTimer = Timer(const Duration(seconds: 5), () {
        _viewModel.hideTooltip();
      });
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _tooltipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_viewModel, _breathingController]),
      builder: (context, child) {
        Offset currentPosition = _viewModel.buttonPosition;

        // ⭐️ [수정 포인트] 버튼이 화면의 오른쪽/위쪽 어디에 있는지 판단
        bool isRightSide = currentPosition.dx > size.width / 2;
        bool isTopSide = currentPosition.dy < 150; // 상단에 붙었을 경우

        return Positioned(
          left: currentPosition.dx,
          top: currentPosition.dy,
          child: Draggable(
            feedback: _buildProButton(isDragging: true),
            childWhenDragging: Container(width: _buttonSize, height: _buttonSize),

            onDragEnd: (details) {
              // 1. 시스템 UI 높이 계산 (상태바 + 앱바)
              final double statusBarHeight = MediaQuery.of(context).padding.top;
              // kToolbarHeight는 기본적으로 56.0입니다. 커스텀 앱바를 쓴다면 그 높이를 쓰세요.
              const double appBarHeight = kToolbarHeight;
              final double topPadding = statusBarHeight + appBarHeight;

              // 2. 바텀 네비게이션 높이 계산
              final double bottomNavHeight = kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom;

              // 3. Stack의 실제 사용 가능 높이 (전체 - 상단UI - 하단UI)
              final double bodyHeight = size.height - topPadding - bottomNavHeight;

              // 4. X축 좌표 제한 (좌우는 그대로)
              double newX = details.offset.dx;
              newX = max(_screenPadding, newX);
              newX = min(size.width - _buttonSize - _screenPadding, newX);

              // 5. Y축 좌표 보정 (핵심! ⭐)
              // 글로벌 좌표(details.offset.dy)에서 상단 여백(topPadding)을 빼야 Stack 내부 좌표가 됨
              double newY = details.offset.dy - topPadding;

              // 6. Y축 좌표 제한 (Stack 내부 기준)
              newY = max(_screenPadding, newY); // 위쪽 한계
              newY = min(bodyHeight - _buttonSize - _screenPadding, newY); // 아래쪽 한계

              _viewModel.updateButtonPosition(Offset(newX, newY));
              _viewModel.hideTooltip();
            },

            // ⭐️ [핵심 수정] Row 대신 Stack 사용 + clipBehavior: Clip.none
            // 이렇게 해야 말풍선이 버튼 영역 밖으로 튀어나와도 짤리지 않음
            child: GestureDetector(
              onTap: () {
                _viewModel.hideTooltip();
                _showAiChatModal(context, _viewModel);
              },
              child: Stack(
                clipBehavior: Clip.none, // 👈 영역 밖 그리기를 허용하는 핵심 속성
                alignment: Alignment.center,
                children: [
                  // 1. 메인 버튼 (항상 정위치)
                  ScaleTransition(
                    scale: _breathingAnimation,
                    child: _buildProButton(isDragging: false),
                  ),

                  // 2. 말풍선 (버튼 위나 아래에 둥둥 띄움)
                  if (_viewModel.showTooltip)
                    Positioned(
                      // 버튼이 상단에 있으면 말풍선을 아래로, 아니면 위로
                      top: isTopSide ? _buttonSize + 8 : null,
                      bottom: isTopSide ? null : _buttonSize + 8,
                      // 버튼이 우측에 있으면 말풍선 우측 정렬 (화면 밖 안 나가게)
                      right: isRightSide ? 0 : null,
                      left: isRightSide ? null : 0,
                      child: _buildTooltip(isTopSide: isTopSide),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ⭐️ [디자인 수정] 말풍선 꼬리 위치 조정
  Widget _buildTooltip({required bool isTopSide}) {
    return Container(
      width: 140, // 너비 고정으로 줄바꿈 방지
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            '무엇이든 물어보세요!',
            style: TextStyle(color: kAiPrimaryDark, fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProButton({required bool isDragging}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _buttonSize,
        height: _buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kAiPrimaryLight, kAiPrimaryDark],
          ),
          boxShadow: [
            BoxShadow(
              color: kAiPrimaryDark.withOpacity(isDragging ? 0.5 : 0.4),
              blurRadius: isDragging ? 20 : 12,
              offset: Offset(0, isDragging ? 8 : 6),
            ),
            BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 0,
                offset: const Offset(-2, -2),
                spreadRadius: 0,
                blurStyle: BlurStyle.inner
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 2.5),
        ),
        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  void _showAiChatModal(BuildContext context, AiChatViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ChangeNotifierProvider<AiChatViewModel>.value(
          value: viewModel,
          child: const AiChatModal(),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// Chat Modal UI (스크롤 수정 버전)
// -------------------------------------------------------------
class AiChatModal extends StatefulWidget {
  const AiChatModal({super.key});

  @override
  State<AiChatModal> createState() => _AiChatModalState();
}

class _AiChatModalState extends State<AiChatModal> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // ⭐️ [UX 개선] 모달 열리면 즉시 스크롤 최하단으로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  void _handleSend(AiChatViewModel viewModel) {
    if (_textController.text.trim().isEmpty || viewModel.isTyping) return;

    final message = _textController.text;
    _textController.clear();
    viewModel.sendMessage(message);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final viewModel = Provider.of<AiChatViewModel>(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85, // 높이 약간 키움
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHeader(context),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                itemCount: viewModel.messages.length + (viewModel.isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == viewModel.messages.length) {
                    return _buildTypingIndicator();
                  }
                  final message = viewModel.messages[index];

                  return Column(
                    children: [
                      _buildMessageBubble(message),

                      if (message.isUser && message.chartType != null)
                        _buildChartDisplay(context, viewModel, message.chartType!),
                    ],
                  );
                },
              ),
            ),

            _buildInputArea(viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.smart_toy_rounded, color: kAiPrimaryDark, size: 24),
              SizedBox(width: 8),
              Text('AI 건강 매니저', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kOnSurfaceColor)),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    // 사용자 메시지는 진한 톤, AI는 밝은 회색 톤
    final color = isUser ? kAiPrimaryDark : const Color(0xFFF3F4F6);
    final textColor = isUser ? Colors.white : kOnSurfaceColor;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                bottomRight: isUser ? Radius.zero : const Radius.circular(20),
              ),
              boxShadow: [
                if (isUser)
                  BoxShadow(color: kAiPrimaryDark.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
              ]
          ),
          child: Text(message.text, style: TextStyle(color: textColor, fontSize: 15, height: 1.4)),
        ),
      ),
    );
  }

  Widget _buildChartDisplay(BuildContext context, AiChatViewModel viewModel, String chartType) {
    final rawData = viewModel.getChartDataForType(chartType);
    final isWeight = chartType == 'WEIGHT';
    final isActivity = chartType == 'ACTIVITY';
    // final isIntake = chartType == 'INTAKE';

    if (rawData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
            '${isWeight ? '체중' : isActivity ? '활동량' : '섭취량'} 기록이 없어 차트를 표시할 수 없습니다.',
            style: const TextStyle(color: Colors.grey, fontSize: 13)
        ),
      );
    }

    // 날짜별 유니크 데이터 전처리
    final Map<String, dynamic> uniqueDataMap = {};
    for (var record in rawData) {
      final dateKey = DateFormat('MM/dd').format(record.date as DateTime);
      uniqueDataMap[dateKey] = record;
    }
    final processedData = uniqueDataMap.values.toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0, left: 4.0, right: 4.0),
      child: Container(
        height: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                    '${isWeight ? '체중' : isActivity ? '활동' : '섭취'} 변화 추이',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kOnSurfaceColor, fontSize: 14)
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AiLineChart(
                rawData: processedData,
                chartType: chartType,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    _scrollToBottom();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(kAiPrimaryDark)),
              ),
              SizedBox(width: 8),
              Text('분석 중...', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(AiChatViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), // 하단 패딩 넉넉하게
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: '궁금한 점을 물어보세요...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: kAiPrimaryLight, width: 1.5)),
              ),
              onSubmitted: (_) => _handleSend(viewModel),
            ),
          ),
          const SizedBox(width: 12),

          // 전송 버튼 디자인 개선
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kAiPrimaryLight, kAiPrimaryDark]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: kAiPrimaryDark.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: viewModel.isTyping ? null : () => _handleSend(viewModel),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// AiLineChart (단위 및 로직 유지 버전)
// -------------------------------------------------------------
class AiLineChart extends StatelessWidget {
  final List<dynamic> rawData;
  final String chartType;

  const AiLineChart({
    super.key,
    required this.rawData,
    required this.chartType
  });

  Map<String, (Color, num? Function(dynamic))> _getLineDefinitions() {
    switch (chartType) {
      case 'WEIGHT':
        return {
          '체중': (kWeightLineColor, (r) => (r as WeightRecord).bodyWeight),
          '근육량': (kMuscleLineColor, (r) => (r as WeightRecord).muscleMass),
          '체지방': (kBodyFatLineColor, (r) => (r as WeightRecord).bodyFatMass),
        };
      case 'ACTIVITY':
        return {
          '활동 시간': (kWeightLineColor, (r) => (r as ActivityRecord).time),
          '소모 칼로리': (kMuscleLineColor, (r) => (r as ActivityRecord).calories),
        };
      case 'INTAKE':
        return {
          '사료량': (kWeightLineColor, (r) => (r as IntakeRecord).food),
          '물': (kMuscleLineColor, (r) => (r as IntakeRecord).water),
        };
      default:
        return {};
    }
  }

  List<FlSpot> _getSpots(List<dynamic> data, num? Function(dynamic) getValue) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final value = getValue(entry.value);
      return value != null ? FlSpot(index.toDouble(), value.toDouble()) : null;
    }).whereType<FlSpot>().toList();
  }

  String _getUnitForLabel(String label) {
    if (label.contains('체중') || label.contains('근육량') || label.contains('체지방')) return 'kg';
    switch (label) {
      case '활동 시간': return '분';
      case '소모 칼로리': return 'kcal';
      case '사료량': return 'g';
      case '물': return 'ml';
      default: return '';
    }
  }

  String _formatValue(double value, String label) {
    if (label.contains('체중') || label.contains('근육량') || label.contains('체지방')) {
      return value.toStringAsFixed(1);
    }
    return value.toInt().toString();
  }

  Widget _buildLegend(Map<String, Color> legendData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: legendData.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(entry.key, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lineDefinitions = _getLineDefinitions();
    final legendData = lineDefinitions.map((key, value) => MapEntry(key, value.$1));
    List<LineChartBarData> lineBarsData = [];
    double maxY = 0;
    double minY = double.infinity;

    for (var def in lineDefinitions.entries) {
      final color = def.value.$1;
      final getValue = def.value.$2;
      final spots = _getSpots(rawData, getValue);

      if (spots.isNotEmpty) {
        lineBarsData.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: spots.length < 15,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4.0,
                color: Colors.white,
                strokeWidth: 2.0,
                strokeColor: barData.color ?? kAiPrimaryDark,
              );
            },
          ),
          belowBarData: BarAreaData(show: false),
        ));

        final currentMax = spots.map((s) => s.y).fold(0.0, max);
        final currentMin = spots.map((s) => s.y).fold(double.infinity, min);
        if (currentMax > maxY) maxY = currentMax;
        if (currentMin < minY) minY = currentMin;
      }
    }

    if (lineBarsData.isEmpty || rawData.isEmpty) {
      return const Center(child: Text('표시할 데이터가 없습니다.', style: TextStyle(color: Colors.grey)));
    }

    final maxX = (rawData.length - 1).toDouble();
    final range = maxY - minY;
    final buffer = range == 0 ? maxY * 0.1 : range * 0.2;
    final finalMinY = max(0.0, minY - buffer);
    final finalMaxY = (maxY + buffer) == 0 ? 10.0 : (maxY + buffer);

    final interval = (finalMaxY - finalMinY) / 4.0;
    final axisInterval = interval <= 0 ? 1.0 : interval;

    return Column(
      children: [
        if (legendData.length > 1) _buildLegend(legendData),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10.0),
            child: LineChart(
              LineChartData(
                minX: -0.3, maxX: maxX + 0.3,
                minY: finalMinY, maxY: finalMaxY,
                lineBarsData: lineBarsData,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: axisInterval,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        if (value != value.toInt().toDouble()) return Container();
                        final index = value.toInt();
                        if (index < 0 || index >= rawData.length) return Container();
                        // 데이터가 많으면 간격 띄우기
                        if (rawData.length > 7 && index % 2 != 0) return Container();

                        final currentDate = (rawData[index] as dynamic).date as DateTime;
                        return SideTitleWidget(
                          space: 8.0,
                          meta: meta,
                          child: Text(DateFormat('M/d').format(currentDate), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: axisInterval,
                      getTitlesWidget: (value, meta) {
                        if (value == finalMaxY || value == finalMinY) return Container();

                        // 대표 단위 자동 찾기
                        String representativeLabel = '';
                        if (chartType == 'WEIGHT') representativeLabel = '체중';
                        else if (chartType == 'ACTIVITY') representativeLabel = '활동 시간';
                        else if (chartType == 'INTAKE') representativeLabel = '사료량';

                        return SideTitleWidget(
                          space: 6.0,
                          meta: meta,
                          child: Text(_formatValue(value, representativeLabel), style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => kOnSurfaceColor.withOpacity(0.9),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.asMap().entries.map((entry) {
                        final index = entry.key;
                        final LineBarSpot spot = entry.value;
                        final date = (rawData[spot.x.toInt()] as dynamic).date as DateTime;
                        final String label = legendData.entries.firstWhere((e) => e.value == spot.bar.color, orElse: () => const MapEntry('', Colors.transparent)).key;

                        final rawValueText = _formatValue(spot.y, label);
                        final String unit = _getUnitForLabel(label);
                        final dateHeader = index == 0 ? '${DateFormat('M월 d일').format(date)}\n' : '';

                        return LineTooltipItem(
                          dateHeader,
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          children: [
                            TextSpan(text: '$label: $rawValueText$unit', style: TextStyle(color: spot.bar.color, fontWeight: FontWeight.w500, fontSize: 12))
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}