// user_health_detail_screen.dart (수정 완료)

import 'package:animal_project/user_add_health_record_dialog.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

import 'package:animal_project/models/user_health_models.dart'; // ✅ 통합 모델 파일 import
import 'package:animal_project/user_date_selection_screen.dart';

const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);

class HealthDetailScreen extends StatefulWidget {
  final PetProfile petProfile;
  final String token;

  const HealthDetailScreen({
    super.key,
    required this.petProfile,
    required this.token,
  });

  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  String _selectedDataType = '체중';
  late DateTime _selectedDate;
  late List<DateTime> _allRecordDates;
  late PetProfile _currentPetProfile;
  bool _isLoading = false;

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  String get _baseUrl =>
      Platform.isAndroid ? 'http://10.0.2.2:4000' : 'http://localhost:4000';

  @override
  void initState() {
    super.initState();
    _currentPetProfile = widget.petProfile;
    _updateAndSetInitialDate();
  }

  // ✅ [수정됨] 날짜 목록을 만들고, 초기 날짜를 설정하는 함수
  void _updateAndSetInitialDate() {
    final allDatesWithDuplicates = [
      ..._currentPetProfile.healthChart.weightDetails.map((r) => r.date),
      ..._currentPetProfile.healthChart.activityDetails.map((r) => r.date),
      ..._currentPetProfile.healthChart.intakeDetails.map((r) => r.date),
    ];
    // Set으로 변환하여 중복을 제거하고 다시 List로 만듭니다.
    _allRecordDates = allDatesWithDuplicates.toSet().toList();

    _allRecordDates.sort();

    if (_allRecordDates.isNotEmpty) {
      _selectedDate = _allRecordDates.last;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final user = data['user'];
        if (mounted) {
          setState(() {
            final oldSelectedDate = _selectedDate; // 이전 선택 날짜 기억
            _currentPetProfile = PetProfile.fromJson(user['petProfile'] ?? {});

            // ✅ 새로고침 후 날짜 목록을 다시 만들고
            final allDatesWithDuplicates = [
              ..._currentPetProfile.healthChart.weightDetails.map((r) => r.date),
              ..._currentPetProfile.healthChart.activityDetails.map((r) => r.date),
              ..._currentPetProfile.healthChart.intakeDetails.map((r) => r.date),
            ];
            // Set으로 변환하여 중복을 제거하고 다시 List로 만듭니다.
            _allRecordDates = allDatesWithDuplicates.toSet().toList();

            _allRecordDates.sort();

            // ✅ 기존 선택 날짜를 유지하려고 시도
            if (_allRecordDates.isNotEmpty) {
              _selectedDate = _allRecordDates.contains(oldSelectedDate)
                  ? oldSelectedDate
                  : _allRecordDates.last;
            } else {
              _selectedDate = DateTime.now();
            }
          });
        }
      } else {
        // ... (에러 처리)
      }
    } catch (e) {
      // ... (에러 처리)
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToPreviousDay() {
    final currentIndex = _allRecordDates.indexOf(_selectedDate);
    if (currentIndex > 0) {
      setState(() {
        _selectedDate = _allRecordDates[currentIndex - 1];
      });
    }
  }

  void _goToNextDay() {
    final currentIndex = _allRecordDates.indexOf(_selectedDate);
    if (currentIndex != -1 && currentIndex < _allRecordDates.length - 1) {
      setState(() {
        _selectedDate = _allRecordDates[currentIndex + 1];
      });
    }
  }

  void _selectDate() async {
    final DateTime? pickedDate = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DateSelectionScreen(
          allDates: _allRecordDates.toSet().toList(),
          initialDate: _selectedDate,
        ),
      ),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _showAddRecordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AddHealthRecordDialog(token: widget.token);
      },
    );

    if (result == true && mounted) {
      await _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final petProfile = _currentPetProfile;

    // (build 메소드 상단부 코드는 그대로 유지)
    List<ChartDataPoint> originalDataPoints;
    dynamic detailedRecords;
    switch (_selectedDataType) {
      case '활동량':
        originalDataPoints = petProfile.healthChart.activity;
        detailedRecords = petProfile.healthChart.activityDetails;
        break;
      case '섭취량':
        originalDataPoints = petProfile.healthChart.intake;
        detailedRecords = petProfile.healthChart.intakeDetails;
        break;
      case '체중':
      default:
        originalDataPoints = petProfile.healthChart.weight;
        detailedRecords = petProfile.healthChart.weightDetails;
        break;
    }
    final List<ChartDataPoint> currentDataPoints = List.from(originalDataPoints);
    currentDataPoints.sort((a, b) => a.date.compareTo(b.date));
    if (detailedRecords is List) {
      detailedRecords.sort((a,b) => a.date.compareTo(b.date));
    }
    final spots = List.generate(currentDataPoints.length,
            (index) => FlSpot(index.toDouble(), currentDataPoints[index].value));
    final dateLabels =
    currentDataPoints.map((p) => '${p.date.month}-${p.date.day}').toList();
    final double interval = _getIntervalForType(_selectedDataType);
    double maxY = 0;
    if (spots.isNotEmpty) {
      final double maxData = spots.map((e) => e.y).reduce(max);
      maxY = (maxData / interval).ceil() * interval;
    }
    if (maxY == 0) {
      maxY = interval * 5;
    }
    final int selectedIndex = currentDataPoints.indexWhere((p) => p.date == _selectedDate);

    // ==================== ⬇️ 모든 문제 해결의 핵심 ⬇️ ====================
    // ✅ build 메소드가 실행될 때마다, 현재 상태를 기준으로 버튼 활성화 여부를 '직접 계산'합니다.
    // ✅ 이렇게 하면 상태가 꼬일 가능성이 원천적으로 사라집니다.
    final currentIndex = _allRecordDates.indexOf(_selectedDate);
    final canGoPrevious = currentIndex > 0;
    final canGoNext = currentIndex != -1 && currentIndex < _allRecordDates.length - 1;
    // ====================================================================

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(petProfile.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black54, size: 28),
            onPressed: _showAddRecordDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              // ✅ [수정됨] build 메소드에서 직접 계산한 변수를 사용합니다.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      onPressed: canGoPrevious ? _goToPreviousDay : null,
                      icon: Icon(
                        Icons.arrow_back_ios,
                        size: 18,
                        color: canGoPrevious ? Colors.black : Colors.grey.shade300,
                      )),
                  InkWell(
                    onTap: _selectDate,
                    child: Text(
                      _allRecordDates.isNotEmpty
                          ? DateFormat('yy.MM.dd (E) HH:mm', 'ko_KR')
                          .format(_selectedDate)
                          : '기록 없음',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                      onPressed: canGoNext ? _goToNextDay : null,
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: canGoNext ? Colors.black : Colors.grey.shade300,
                      )),
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
            SizedBox(
              height: 250,
              child: spots.isEmpty
                  ? Center(
                  child: Text('표시할 $_selectedDataType 데이터가 없습니다.',
                      style: const TextStyle(
                          fontSize: 16, color: kOnSurfaceColor)))
                  : Padding(
                padding: const EdgeInsets.only(
                    right: 28.0, left: 16.0, top: 24, bottom: 12),
                child: LineChart(
                  LineChartData(
                    extraLinesData: ExtraLinesData(
                      verticalLines: [
                        if (selectedIndex != -1)
                          VerticalLine(
                            x: selectedIndex.toDouble(),
                            color: Colors.blueGrey.withOpacity(0.7),
                            strokeWidth: 2,
                            dashArray: [5, 5],
                          ),
                      ],
                    ),
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true, // 기존 툴팁 기능을 위해 유지
                      touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                        // 터치 이벤트가 '탭 종료'일 때만 반응하도록 합니다.
                        if (event is FlTapUpEvent) {
                          // 차트의 빈 공간이나 유효하지 않은 곳을 탭했다면 아무것도 하지 않습니다.
                          if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
                            return;
                          }

                          // 탭한 지점(spot)의 데이터 인덱스를 가져옵니다.
                          final spotIndex = response.lineBarSpots![0].spotIndex;

                          // 해당 인덱스가 실제 데이터 범위 안에 있는지 확인합니다.
                          if (spotIndex < currentDataPoints.length) {
                            // 인덱스를 사용해 해당 날짜를 찾고, 화면 상태를 업데이트합니다.
                            final newSelectedDate = currentDataPoints[spotIndex].date;
                            setState(() {
                              _selectedDate = newSelectedDate;
                            });
                          }
                        }
                      },
                      touchTooltipData: LineTouchTooltipData(
                          maxContentWidth: 200,
                          fitInsideHorizontally: true,
                          getTooltipColor: (spot) => Colors.black.withOpacity(0.8),
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          getTooltipItems: (touchedSpots) {
                            TextSpan buildComparisonSpan(String label, num? currentValue, num? comparisonValue, String unit, {bool isDouble = false}) {
                              if (currentValue == null) return const TextSpan();
                              String comparisonText = '(첫 기록)';
                              Color comparisonColor = Colors.grey;
                              if (comparisonValue != null) {
                                final double diff = currentValue.toDouble() - comparisonValue.toDouble();
                                if (diff.abs() > (isDouble ? 0.01 : 0)) {
                                  comparisonText = '(${diff > 0 ? '+' : ''}${isDouble ? diff.toStringAsFixed(1) : diff.toInt()}$unit)';
                                  comparisonColor = diff > 0 ? Colors.red.shade400 : Colors.blue.shade400;
                                } else {
                                  comparisonText = '(-)';
                                }
                              }
                              return TextSpan(
                                  style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.8),
                                  children: [
                                    TextSpan(text: '$label\u00A0\u00A0', style: const TextStyle(color: Colors.white70)),
                                    TextSpan(text: '${isDouble ? currentValue.toStringAsFixed(1) : currentValue.toInt()}$unit\u00A0\u00A0', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: comparisonText, style: TextStyle(color: comparisonColor)),
                                  ]
                              );
                            }

                            return touchedSpots.map((spot) {
                              final int touchedIndex = spot.spotIndex;
                              final DateFormat formatter = DateFormat('yy.MM.dd (E)', 'ko_KR');

                              switch (_selectedDataType) {
                                case '체중':
                                  if (detailedRecords is! List<WeightRecord> || detailedRecords.length <= touchedIndex) return null;

                                  final List<WeightRecord> sortedDetails = detailedRecords;
                                  final WeightRecord currentRecord = sortedDetails[touchedIndex];
                                  WeightRecord? comparisonRecord;
                                  if (touchedIndex > 0) {
                                    comparisonRecord = sortedDetails[touchedIndex - 1];
                                  }

                                  return LineTooltipItem(
                                      '', const TextStyle(), textAlign: TextAlign.start,
                                      children: [
                                        TextSpan(text: '${formatter.format(currentRecord.date)}\n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.5)),
                                        const TextSpan(text: '──────────\n', style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: -1)),
                                        buildComparisonSpan('체중', currentRecord.bodyWeight, comparisonRecord?.bodyWeight, 'kg', isDouble: true),
                                        buildComparisonSpan('\n근육량', currentRecord.muscleMass, comparisonRecord?.muscleMass, 'kg', isDouble: true),
                                        buildComparisonSpan('\n체지방', currentRecord.bodyFatMass, comparisonRecord?.bodyFatMass, '%', isDouble: true),
                                      ]
                                  );

                                case '활동량':
                                  if (detailedRecords is! List<ActivityRecord> || detailedRecords.length <= touchedIndex) return null;

                                  final List<ActivityRecord> sortedDetails = detailedRecords;
                                  final ActivityRecord currentRecord = sortedDetails[touchedIndex];
                                  ActivityRecord? comparisonRecord;
                                  if (touchedIndex > 0) {
                                    comparisonRecord = sortedDetails[touchedIndex - 1];
                                  }

                                  return LineTooltipItem(
                                      '', const TextStyle(), textAlign: TextAlign.start,
                                      children: [
                                        TextSpan(text: '${formatter.format(currentRecord.date)}\n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.5)),
                                        const TextSpan(text: '──────────\n', style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: -1)),
                                        buildComparisonSpan('활동 시간', currentRecord.time, comparisonRecord?.time, '분'),
                                        buildComparisonSpan('\n소모 칼로리', currentRecord.calories, comparisonRecord?.calories, 'kcal'),
                                      ]
                                  );

                                case '섭취량':
                                  if (detailedRecords is! List<IntakeRecord> || detailedRecords.length <= touchedIndex) return null;

                                  final List<IntakeRecord> sortedDetails = detailedRecords;
                                  final IntakeRecord currentRecord = sortedDetails[touchedIndex];
                                  IntakeRecord? comparisonRecord;
                                  if (touchedIndex > 0) {
                                    comparisonRecord = sortedDetails[touchedIndex - 1];
                                  }

                                  return LineTooltipItem(
                                      '', const TextStyle(), textAlign: TextAlign.start,
                                      children: [
                                        TextSpan(text: '${formatter.format(currentRecord.date)}\n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.5)),
                                        const TextSpan(text: '──────────\n', style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: -1)),
                                        buildComparisonSpan('사료량', currentRecord.food, comparisonRecord?.food, 'g'),
                                        buildComparisonSpan('\n물', currentRecord.water, comparisonRecord?.water, 'ml'),
                                      ]
                                  );

                                default:
                                  return null;
                              }
                            }).where((item) => item != null).cast<LineTooltipItem>().toList();
                          }
                      ),
                    ),
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
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= dateLabels.length) {
                              return Container();
                            }
                            if (index == 0 || index == dateLabels.length - 1) {
                              if (index == dateLabels.length - 1 && dateLabels.first == dateLabels.last && dateLabels.length > 1) {
                                return Container();
                              }
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 8.0,
                                child: Text(dateLabels[index], style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              );
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
                    minY: 0,
                    maxY: maxY,
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
            _buildDetailedComparisonSection(
              detailedRecords: detailedRecords,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedComparisonSection({required dynamic detailedRecords}) {
    final currentRecordIndex = detailedRecords.indexWhere(
            (r) => r.date == _selectedDate);

    if (currentRecordIndex == -1) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        alignment: Alignment.center,
        child: Text('선택된 시간의 $_selectedDataType 기록이 없습니다.'),
      );
    }

    final currentRecord = detailedRecords[currentRecordIndex];
    final previousRecord = (currentRecordIndex > 0) ? detailedRecords[currentRecordIndex - 1] : null;

    List<Widget> comparisonBars = [];

    switch (_selectedDataType) {
      case '체중':
        final record = currentRecord as WeightRecord;
        final prev = previousRecord as WeightRecord?;
        comparisonBars = [
          _buildComparisonBar('체중', record.bodyWeight, prev?.bodyWeight, 'kg', 15),
          _buildComparisonBar('근육량', record.muscleMass, prev?.muscleMass, 'kg', 10),
          _buildComparisonBar('체지방', record.bodyFatMass, prev?.bodyFatMass, '%', 30),
        ];
        break;
      case '활동량':
        final record = currentRecord as ActivityRecord;
        final prev = previousRecord as ActivityRecord?;
        comparisonBars = [
          _buildComparisonBar('활동 시간', record.time, prev?.time, '분', 120),
          _buildComparisonBar('소모 칼로리', record.calories, prev?.calories, 'kcal', 500),
        ];
        break;
      case '섭취량':
        final record = currentRecord as IntakeRecord;
        final prev = previousRecord as IntakeRecord?;
        comparisonBars = [
          _buildComparisonBar('사료량', record.food, prev?.food, 'g', 500),
          _buildComparisonBar('물', record.water, prev?.water, 'ml', 1000),
        ];
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedDataType,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kSecondaryColor, width: 1),
            ),
            child: Column(
              children: comparisonBars.isNotEmpty
                  ? comparisonBars
                  : [const Text('표시할 세부 데이터가 없습니다.')],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(String label, num? currentValue, num? previousValue, String unit, double maxValue) {
    if (currentValue == null) return Container();

    String changeText = '(첫 기록)';
    Color changeColor = Colors.grey;
    if (previousValue != null) {
      final double diff = currentValue.toDouble() - previousValue.toDouble();
      if (diff.abs() > (unit == 'kg' || unit == '%' ? 0.01 : 0)) {
        changeText = '${diff > 0 ? '+' : ''}${unit == 'kg' || unit == '%' ? diff.toStringAsFixed(1) : diff.toInt()}$unit';
        changeColor = diff > 0 ? Colors.red.shade400 : Colors.blue.shade400;
      } else {
        changeText = '(-)';
      }
    }

    final barWidth = (currentValue / maxValue) * 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${unit == 'kg' || unit == '%' ? currentValue.toStringAsFixed(1) : currentValue.toInt()}$unit',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(changeText, style: TextStyle(fontSize: 12, color: changeColor)),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: kSecondaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: constraints.maxWidth * (barWidth / 100).clamp(0, 1),
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _customLeftTitleWidgets(double value, TitleMeta meta) {
    const style =
    TextStyle(color: kOnSurfaceColor, fontWeight: FontWeight.bold, fontSize: 10);
    String text;
    if (value == 0) {
      return Container();
    }
    if (value == value.toInt().toDouble()) {
      text = value.toInt().toString();
    } else {
      text = value.toStringAsFixed(1);
    }
    return SideTitleWidget(
        axisSide: meta.axisSide, space: 10.0, child: Text(text, style: style));
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

  double _getIntervalForType(String dataType) {
    switch (dataType) {
      case '섭취량':
        return 50.0;
      case '활동량':
        return 10.0;
      case '체중':
      default:
        return 2.0;
    }
  }
}