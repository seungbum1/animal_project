import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:animal_project/user_health_main.dart';
// ✅ 기록 추가 다이얼로그를 사용하기 위해 import 합니다.
import 'package:animal_project/user_add_health_record_dialog.dart';

// 🎨 색상 팔레트
const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);

class HealthDetailScreen extends StatefulWidget {
  final PetProfile petProfile;
  // ✅ 기록 추가 API 호출을 위해 token을 전달받습니다.
  final String token;

  const HealthDetailScreen({
    super.key,
    required this.petProfile,
    required this.token, // ✅ 생성자에 token 추가
  });

  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  String _selectedDataType = '체중';

  // ✅ '건강 기록 추가' 다이얼로그를 띄우는 함수
  void _showAddRecordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        // ✅ token을 다이얼로그에 전달합니다.
        return AddHealthRecordDialog(token: widget.token);
      },
    );

    // ✅ 다이얼로그에서 '저장'이 성공적으로 완료되면...
    if (result == true && mounted) {
      // 이전 화면(메인 대시보드)에 데이터가 갱신되었음을 알리면서 현재 화면을 닫습니다.
      Navigator.pop(context, true);
    }
  }

  // (이하 다른 함수들은 기존과 동일합니다)

  double _getNiceInterval(double range) {
    if (range <= 0) return 1.0;
    const int desiredSteps = 5;
    double roughStep = range / (desiredSteps - 1);
    double magnitude = pow(10, (log(roughStep) / ln10).floor()).toDouble();
    double residual = roughStep / magnitude;
    double niceResidual;
    if (residual <= 1.0) {
      niceResidual = 1.0;
    } else if (residual <= 2.0) {
      niceResidual = 2.0;
    } else if (residual <= 5.0) {
      niceResidual = 5.0;
    } else {
      niceResidual = 10.0;
    }
    return niceResidual * magnitude;
  }

  Widget _customLeftTitleWidgets(double value, TitleMeta meta) {
    const style =
    TextStyle(color: kOnSurfaceColor, fontWeight: FontWeight.bold, fontSize: 10);
    String text;
    if (value == value.toInt().toDouble()) {
      text = value.toInt().toString();
    } else {
      text = value.toStringAsFixed(1);
    }
    if (value == meta.min) {
      return Container();
    }
    return SideTitleWidget(
        axisSide: meta.axisSide, space: 10.0, child: Text(text, style: style));
  }

  String _getUnitForDataType(String dataType) {
    switch (dataType) {
      case '체중':
        return 'kg';
      case '활동량':
        return '분';
      case '섭취량':
        return 'g';
      default:
        return '';
    }
  }

  Widget _buildDataButton(String title) {
    bool isSelected = (_selectedDataType == title);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () => setState(() => _selectedDataType = title),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: kSecondaryColor),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2))
              ]
                  : null,
            ),
            child: Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: kOnSurfaceColor,
                    fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final petProfile = widget.petProfile;

    List<ChartDataPoint> currentDataPoints;
    switch (_selectedDataType) {
      case '활동량':
        currentDataPoints = petProfile.healthChart.activity;
        break;
      case '섭취량':
        currentDataPoints = petProfile.healthChart.intake;
        break;
      case '체중':
      default:
        currentDataPoints = petProfile.healthChart.weight;
        break;
    }

    final spots = List.generate(currentDataPoints.length,
            (index) => FlSpot(index.toDouble(), currentDataPoints[index].value));
    final dateLabels =
    currentDataPoints.map((p) => '${p.date.month}-${p.date.day}').toList();

    ChartDataPoint? latestRecord;
    if (currentDataPoints.isNotEmpty) {
      final sortedList = List<ChartDataPoint>.from(currentDataPoints)
        ..sort((a, b) => b.date.compareTo(a.date));
      latestRecord = sortedList.first;
    }

    double minY = 0, maxY = 10, interval = 2;
    if (spots.isNotEmpty) {
      double minData = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      double maxData = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      double dataRange = maxData - minData;

      if (dataRange < 0.1) {
        dataRange = maxData * 0.2;
        if (dataRange < 1.0) dataRange = 1.0;
        minData = max(0, maxData - dataRange);
      }

      final padding = dataRange * 0.2;
      minY = max(0, minData - padding);
      maxY = maxData + padding;
      final chartRange = maxY - minY;
      interval = _getNiceInterval(chartRange);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(petProfile.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        centerTitle: true,
        // ✅ AppBar 오른쪽에 '추가' 버튼을 만듭니다.
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black54, size: 28),
            onPressed: _showAddRecordDialog, // ✅ 버튼을 누르면 다이얼로그 함수 호출
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_back_ios, size: 18)),
                  Text(
                    latestRecord != null
                        ? DateFormat('yy.MM.dd (E)', 'ko_KR')
                        .format(latestRecord.date)
                        : '기록 없음',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_forward_ios, size: 18)),
                ],
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildDataButton('체중'),
                  _buildDataButton('활동량'),
                  _buildDataButton('섭취량'),
                ],
              ),
            ),
            if (spots.isEmpty)
              AspectRatio(
                aspectRatio: 1.7,
                child: Center(
                    child: Text('표시할 $_selectedDataType 데이터가 없습니다.',
                        style: const TextStyle(
                            fontSize: 16, color: kOnSurfaceColor))),
              )
            else
              AspectRatio(
                aspectRatio: 1.7,
                child: Padding(
                  padding: const EdgeInsets.only(
                      right: 28.0, left: 16.0, top: 24, bottom: 12),
                  child: LineChart(
                    LineChartData(
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: (dateLabels.length / 5).ceil().toDouble(),
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < dateLabels.length) {
                                return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 8.0,
                                    child: Text(dateLabels[index],
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10)));
                              }
                              return Container();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 35,
                                interval: interval,
                                getTitlesWidget: _customLeftTitleWidgets)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) => FlLine(
                            color: kSecondaryColor.withOpacity(0.7),
                            strokeWidth: 1),
                      ),
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      minY: minY.toDouble(),
                      maxY: maxY.toDouble(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: kPrimaryColor,
                          barWidth: 2,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (latestRecord != null)
              _buildDetailSection(
                title: _selectedDataType,
                latestValue: latestRecord.value.toStringAsFixed(1),
                unit: _getUnitForDataType(_selectedDataType),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
      {required String title,
        required String latestValue,
        required String unit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kSecondaryColor, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('최신 기록',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(latestValue,
                        style: const TextStyle(
                            color: kOnSurfaceColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Text(unit,
                        style:
                        const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}