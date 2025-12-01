// lib/widgets/draggable_ai_button.dart (최종 다중 라인 차트 통합 버전 + 날짜/단위 문제 해결)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/models/user_ai_chat_viewmodel.dart';
import 'package:animal_project/services/user_ai_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:intl/intl.dart';


const double kBottomNavigationBarHeight = 56.0;
// -------------------------------------------------------------
// 상수 정의 (HealthChartDashboard의 색상을 따름)
// -------------------------------------------------------------
const Color kPrimaryColor = Color(0xFFC06362);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);

const Color kWeightLineColor = Color(0xFF547AA5);
const Color kMuscleLineColor = Color(0xFF6A994E);
const Color kBodyFatLineColor = Color(0xFFE9C46A);

// -------------------------------------------------------------
// Draggable Button (Floating UI)
// -------------------------------------------------------------
class DraggableAiButton extends StatefulWidget {
  final PetProfile? petProfile;
  final String token;
  // ⭐️ 1. 외부에서 ViewModel 인스턴스를 받도록 필드 추가
  final AiChatViewModel viewModel;

  const DraggableAiButton({
    super.key,
    required this.petProfile,
    required this.token,
    required this.viewModel, // 👈 필수 인자로 추가
  });

  @override
  // ⭐️ 2. ViewModel을 State 생성자에게 전달하도록 수정
  State<DraggableAiButton> createState() => _DraggableAiButtonState(viewModel: viewModel);
}

class _DraggableAiButtonState extends State<DraggableAiButton> {
  // ⭐️ 3. 주입된 ViewModel을 final로 선언하고 사용
  final AiChatViewModel _viewModel;

  // ⭐️ 4. State 생성자를 통해 ViewModel을 받도록 수정
  _DraggableAiButtonState({required AiChatViewModel viewModel}) : _viewModel = viewModel;

  static const double _buttonSize = 60.0;
  static const double _screenPadding = 16.0;

  // ⭐️ 5. initState에서 새로 생성하는 로직 제거

  @override
  Widget build(BuildContext context) {
    // ⭐️ 6. Animation Builder는 주입된 _viewModel을 사용
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _viewModel, // 👈 주입된 인스턴스 사용
      builder: (context, child) {
        Offset currentPosition = _viewModel.buttonPosition;

        return Positioned(
          left: currentPosition.dx,
          top: currentPosition.dy,
          child: Draggable(
            feedback: _buildButton(isDragging: true),
            childWhenDragging: Container(width: _buttonSize, height: _buttonSize),

            // ⭐️ [복구 핵심] onDragEnd 로직을 최초에 작동했던 단순한 형태로 복구합니다.
            onDragEnd: (details) {
              double newX = details.offset.dx;
              double newY = details.offset.dy;
              // X축 경계 체크
              newX = max(_screenPadding, newX);
              newX = min(size.width - _buttonSize - _screenPadding, newX);

              // Y축 경계 체크 (최초의 Global 좌표계 기준)
              // 상단 경계는 _screenPadding
              final double bottomBoundary = size.height
                  // 🚨 이 줄을 아래처럼 수정해야 합니다.
                  - kBottomNavigationBarHeight
                  - MediaQuery.of(context).padding.bottom
                  - _buttonSize
                  - _screenPadding;

              newY = max(_screenPadding, newY);
              newY = min(bottomBoundary, newY);

              _viewModel.updateButtonPosition(Offset(newX, newY));
            },
            child: GestureDetector(
              onTap: () {
                _showAiChatModal(context, _viewModel);
              },
              child: _buildButton(isDragging: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton({required bool isDragging}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _buttonSize,
        height: _buttonSize,
        decoration: BoxDecoration(
          color: kPrimaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDragging ? 0.6 : 0.3),
              blurRadius: isDragging ? 15 : 8,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 30),
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
// Chat Modal UI (Modal Bottom Sheet)
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
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHeader(context),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 10, bottom: 20, left: 16, right: 16),
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
                        _buildChartDisplay(context, viewModel, message.chartType!), // ⭐️ 차트 위젯 삽입
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.smart_toy, color: kPrimaryColor),
              SizedBox(width: 8),
              Text('AI 건강 비서', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
            ],
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? kPrimaryColor.withOpacity(0.9) : Colors.grey[200];
    final textColor = isUser ? Colors.white : kOnSurfaceColor;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
              bottomRight: isUser ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Text(message.text, style: TextStyle(color: textColor)),
        ),
      ),
    );
  }

  // ⭐️ [유지] 차트 렌더링 위젯 (날짜별 데이터 유일성 전처리 로직 유지)
  Widget _buildChartDisplay(BuildContext context, AiChatViewModel viewModel, String chartType) {
    // ⭐️ [STEP 1: 원본 데이터 로드]
    final rawData = viewModel.getChartDataForType(chartType);
    final isWeight = chartType == 'WEIGHT';
    final isActivity = chartType == 'ACTIVITY';
    final isIntake = chartType == 'INTAKE';

    // 표시할 데이터가 없는 경우
    if (rawData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        child: Text('${isWeight ? '체중' : isActivity ? '활동량' : '섭취량'} 기록이 없어 차트를 표시할 수 없습니다.',
            style: const TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
      );
    }

    // ⭐️ [STEP 2: 날짜별 최종 데이터만 추출하는 전처리] ⭐️
    final Map<String, dynamic> uniqueDataMap = {};
    for (var record in rawData) {
      final dateKey = DateFormat('MM/dd').format(record.date as DateTime);
      uniqueDataMap[dateKey] = record;
    }
    final processedData = uniqueDataMap.values.toList();
    // ----------------------------------------------------

    // ⭐️ [STEP 3: 전처리된 데이터로 차트 호출]
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0, left: 10.0, right: 10.0),
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kSecondaryColor, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${isWeight ? '체중 변화' : isActivity ? '활동 시간 변화' : '섭취량 변화'} 그래프 (최근 기록)',
                style: const TextStyle(fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
            const SizedBox(height: 8),
            Expanded(
              child: AiLineChart(
                rawData: processedData, // 👈 전처리된 유일한 데이터 리스트 전달
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
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('AI 비서가 답변을 준비 중입니다...', style: TextStyle(color: kOnSurfaceColor, fontStyle: FontStyle.italic)),
              SizedBox(width: 8),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(AiChatViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: '궁금한 점을 물어보세요...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                ),
              ),
              onSubmitted: (_) => _handleSend(viewModel),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: viewModel.isTyping ? Colors.grey : kPrimaryColor,
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: viewModel.isTyping ? null : () => _handleSend(viewModel),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// ⭐️ [최종 수정 위젯] AiLineChart
// -------------------------------------------------------------
class AiLineChart extends StatelessWidget {
  final List<dynamic> rawData;
  final String chartType;

  const AiLineChart({
    super.key,
    required this.rawData,
    required this.chartType
  });

  // ⭐️ [수정] 모든 세부 항목을 라인으로 정의
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
          // ⭐️ 활동량의 세부 기록들을 모두 표시
          '활동 시간': (kWeightLineColor, (r) => (r as ActivityRecord).time),
          '소모 칼로리': (kMuscleLineColor, (r) => (r as ActivityRecord).calories),
        };
      case 'INTAKE':
        return {
          // ⭐️ 섭취량의 세부 기록들을 모두 표시
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
    if (label.contains('체중') || label.contains('근육량') || label.contains('체지방')) {
      return 'kg';
    }
    switch (label) {
      case '활동 시간':
        return '분';
      case '소모 칼로리':
        return 'kcal';
      case '사료량':
        return 'g';
      case '물':
        return 'ml';
      default:
        return '';
    }
  }

  // ⭐️ [수정] 라벨(Label)에 따라 정확한 단위를 적용합니다.
  String _formatValue(double value, String label) {
    // 소수점 처리가 필요한 경우 (체중 계열)
    if (label.contains('체중') || label.contains('근육량') || label.contains('체지방')) {
      return value.toStringAsFixed(1); // 단위 제거
    }

    // 정수 처리가 필요한 경우 (활동/섭취 계열)
    // 모든 단위(분, kcal, g, ml)를 제거하고 정수만 반환
    return value.toInt().toString();
  }

  Widget _buildLegend(Map<String, Color> legendData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: legendData.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Container(width: 8, height: 8, color: entry.value),
              const SizedBox(width: 4),
              Text(entry.key, style: const TextStyle(fontSize: 11, color: kOnSurfaceColor)),
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
          dotData: FlDotData(
            show: spots.length < 15,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4.0,
                color: barData.color ?? kPrimaryColor,
                strokeWidth: 0,
                strokeColor: Colors.transparent,
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
      return const Center(child: Text('기록된 유효한 데이터가 없습니다.', style: TextStyle(color: Colors.grey)));
    }

    final maxX = (rawData.length - 1).toDouble();

    final range = maxY - minY;
    final buffer = range * 0.2;
    final finalMinY = max(0.0, minY - buffer);
    final finalMaxY = maxY + buffer;

    final interval = (finalMaxY - finalMinY) / 4.0;
    final axisInterval = interval.clamp(1.0, double.infinity);


    return Column(
      children: [
        if (legendData.length > 1) _buildLegend(legendData),
        const SizedBox(height: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 4.0),
            child: LineChart(
              LineChartData(
                minX: -0.5, maxX: maxX + 0.5,
                minY: finalMinY, maxY: finalMaxY,

                lineBarsData: lineBarsData,

                borderData: FlBorderData(show: false),

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: axisInterval,
                  getDrawingHorizontalLine: (value) => FlLine(color: kSecondaryColor.withOpacity(0.5), strokeWidth: 1),
                ),

                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                  // X축 (날짜) - 모든 데이터 포인트에 라벨 표시
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        if (value != value.toInt().toDouble()) return Container();

                        final index = value.toInt();
                        if (index < 0 || index >= rawData.length) return Container();

                        // ⭐️ [최종 수정] 모든 인덱스에 대해 라벨을 반환합니다.
                        final currentDate = (rawData[index] as dynamic).date as DateTime;

                        return SideTitleWidget(
                          space: 8.0,
                          meta: meta,
                          child: Text(
                              DateFormat('MM/dd').format(currentDate),
                              style: const TextStyle(color: Colors.grey, fontSize: 10)
                          ),
                        );
                      },
                    ),
                  ),

                  // Y축 (값) - 대표 라벨 단위 적용
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: axisInterval,
                      getTitlesWidget: (value, meta) {
                        if (value == finalMaxY) return Container();

                        // Y축은 이제 순수한 값만 표시합니다.
                        // Y축에 표시될 대표 라벨 (체중/활동 시간/사료량)을 사용하여 포맷합니다.
                        String representativeLabel;
                        if (chartType == 'WEIGHT') representativeLabel = '체중';
                        else if (chartType == 'ACTIVITY') representativeLabel = '활동 시간';
                        else if (chartType == 'INTAKE') representativeLabel = '사료량';
                        else representativeLabel = '';

                        return SideTitleWidget(
                          space: 4.0,
                          meta: meta,
                          // ⭐️ [수정] 순수한 값만 출력하도록 _formatValue 호출
                          child: Text(_formatValue(value, representativeLabel), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),

                // 터치 상호작용 - 정확한 단위 적용
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black.withOpacity(0.8),
                    getTooltipItems: (touchedSpots) {
                      // ⭐️ [핵심 수정] 툴팁 목록을 순회하며 index 0인 항목에만 날짜 헤더를 추가합니다.
                      return touchedSpots.asMap().entries.map((entry) {
                        final int index = entry.key; // 툴팁 목록 내의 순서 (0, 1, 2...)
                        final LineBarSpot spot = entry.value;

                        final date = (rawData[spot.x.toInt()] as dynamic).date as DateTime;

                        final String label = legendData.entries.firstWhere((e) => e.value == spot.bar.color, orElse: () => const MapEntry('', Colors.transparent)).key;

                        // 1. 툴팁 값을 포맷하고 단위를 붙입니다.
                        final rawValueText = _formatValue(spot.y, label);
                        final String unit = _getUnitForLabel(label);
                        final valueTextWithUnit = '$rawValueText$unit';

                        // 2. index가 0일 때만 날짜 헤더를 포함합니다.
                        final String dateHeader = index == 0
                            ? '${DateFormat('MM/dd').format(date)}\n'
                            : '';

                        return LineTooltipItem(
                          dateHeader, // ⭐️ index 0일 때만 날짜 포함
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          children: [
                            TextSpan(
                                text: '$label: $valueTextWithUnit',
                                style: TextStyle(color: spot.bar.color, fontWeight: FontWeight.normal, fontSize: 12)
                            )
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