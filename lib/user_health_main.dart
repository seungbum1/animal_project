// user_health_main.dart (수정 완료)

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:animal_project/models/user_health_models.dart'; // ✅ 통합 모델 파일 import
import 'package:animal_project/user_add_health_record_dialog.dart';
import 'package:animal_project/user_health_detail_screen.dart';
import 'package:animal_project/user_health_diary_screen.dart';
import 'package:animal_project/user_medication_alarm_list_screen.dart';


// ❌❌❌ 이 파일 상단에 있던 모든 모델 클래스 정의를 완전히 삭제합니다. ❌❌❌


const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);

class HealthDashboardScreen extends StatefulWidget {
  final String token;
  final String petName;
  const HealthDashboardScreen(
      {super.key, required this.token, required this.petName});
  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  late Future<PetProfile> _petProfileFuture;
  String get _baseUrl =>
      Platform.isAndroid ? 'http://10.0.2.2:4000' : 'http://localhost:4000';
  @override
  void initState() {
    super.initState();
    _petProfileFuture = fetchPetProfile();
  }

  Future<PetProfile> fetchPetProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final user = data['user'];
      return PetProfile.fromJson(user['petProfile'] ?? {});
    } else {
      throw Exception('프로필 정보를 불러오는 데 실패했습니다.');
    }
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _petProfileFuture = fetchPetProfile();
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
      // ✅ 이 파일에서는 await 없이 _refreshData()를 호출해야 합니다.
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PetProfile>(
      future: _petProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                  child: CircularProgressIndicator(color: kPrimaryColor)));
        }
        if (snapshot.hasError) {
          return Scaffold(
              appBar: AppBar(title: const Text('오류')),
              body: Center(child: Text('데이터 로딩 실패: ${snapshot.error}')));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
              appBar: AppBar(title: const Text('')),
              body: const Center(child: Text('반려동물 프로필 정보가 없습니다.')));
        }
        final petProfile = snapshot.data!;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Row(
                  children: [
                    Container(
                        width: 25,
                        height: 15,
                        decoration: const BoxDecoration(
                            color: kPrimaryColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(petProfile.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black)),
                    const Icon(Icons.arrow_drop_down, color: Colors.black87),
                  ],
                ),
                const SizedBox(width: 48),
              ],
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('3시간 뒤 약을 복용할 시간입니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('건강 기록 대시보드',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                ),
                HealthChartDashboard(
                  petProfile: petProfile,
                  token: widget.token,
                  onAddRecordPressed: _showAddRecordDialog,
                  onRecordAdded: _refreshData,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionCard(context,
                          icon: Icons.article_outlined,
                          label: '일기',
                          iconBackgroundColor:
                          kSecondaryColor.withOpacity(0.5)),
                      _buildActionCard(context,
                          icon: Icons.local_pharmacy_outlined,
                          label: '복용량 설정',
                          iconBackgroundColor:
                          const Color(0xFFC06362).withOpacity(0.2)),
                    ],
                  ),
                ),
                RecentRecordList(
                    diaries: petProfile.diaries, alarms: petProfile.alarms),
                const SizedBox(height: 80),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavBar(Theme.of(context)),
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required IconData icon,
        required String label,
        required Color iconBackgroundColor}) {
    return InkWell(
      onTap: () {
        if (label == '일기') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => HealthDiaryScreen(token: widget.token)));
        } else if (label == '복용량 설정') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const MedicationAlarmListScreen()));
        }
      },
      child: Container(
          width: MediaQuery.of(context).size.width / 2 - 30,
          height: 120,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kSecondaryColor, width: 2)),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, size: 44, color: kPrimaryColor)),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: kOnSurfaceColor))
              ])),
    );
  }

  Widget _buildBottomNavBar(ThemeData theme) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: kPrimaryColor,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      currentIndex: 1,
      onTap: (int index) {
        switch (index) {
          case 0:
            Navigator.of(context).popUntil((route) => route.isFirst);
            break;
          case 1:
            break;
          case 2:
            break;
          case 3:
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
        BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
        BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital_outlined), label: '내 병원'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: '마이페이지')
      ],
    );
  }
}

class HealthChartDashboard extends StatefulWidget {
  final PetProfile petProfile;
  final String token;
  final VoidCallback onAddRecordPressed;
  final VoidCallback onRecordAdded;

  const HealthChartDashboard(
      {super.key,
        required this.petProfile,
        required this.token,
        required this.onAddRecordPressed,
        required this.onRecordAdded});
  @override
  State<HealthChartDashboard> createState() => _HealthChartDashboardState();
}

class _HealthChartDashboardState extends State<HealthChartDashboard> {
  String _selectedDataType = '체중';

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

  @override
  Widget build(BuildContext context) {
    List<ChartDataPoint> originalDataPoints;
    switch (_selectedDataType) {
      case '활동량':
        originalDataPoints = widget.petProfile.healthChart.activity;
        break;
      case '섭취량':
        originalDataPoints = widget.petProfile.healthChart.intake;
        break;
      case '체중':
      default:
        originalDataPoints = widget.petProfile.healthChart.weight;
        break;
    }

    final List<ChartDataPoint> dataPoints = List.from(originalDataPoints);
    dataPoints.sort((a, b) => a.date.compareTo(b.date));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              _buildDataButton('체중'),
              _buildDataButton('활동량'),
              _buildDataButton('섭취량'),
            ],
          ),
        ),
        dataPoints.isEmpty
            ? _buildEmptyState()
            : Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildChartArea(dataPoints),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HealthDetailScreen(
                        petProfile: widget.petProfile,
                        token: widget.token,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    widget.onRecordAdded();
                  }
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('자세히 보기',
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _customLeftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
        color: kOnSurfaceColor, fontWeight: FontWeight.bold, fontSize: 12);
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

  Widget _buildChartArea(List<ChartDataPoint> dataPoints) {
    if (dataPoints.isEmpty) {
      return const AspectRatio(
          aspectRatio: 1.7, child: Center(child: Text("표시할 데이터가 없습니다.")));
    }

    final spots = List.generate(dataPoints.length,
            (index) => FlSpot(index.toDouble(), dataPoints[index].value));
    final dateLabels =
    dataPoints.map((p) => '${p.date.month}-${p.date.day}').toList();

    final double interval = _getIntervalForType(_selectedDataType);
    final double maxData = spots.isEmpty ? 0 : spots.map((e) => e.y).reduce(max);
    double maxY = (maxData / interval).ceil() * interval;
    if (maxY == 0) {
      maxY = interval * 5;
    }

    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding:
        const EdgeInsets.only(right: 28.0, left: 16.0, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
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
                        final sortedDetails = List.from(widget.petProfile.healthChart.weightDetails)..sort((a,b) => a.date.compareTo(b.date));
                        if (sortedDetails.length <= touchedIndex) return null;

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
                        final sortedDetails = List.from(widget.petProfile.healthChart.activityDetails)..sort((a,b) => a.date.compareTo(b.date));
                        if (sortedDetails.length <= touchedIndex) return null;

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
                        final sortedDetails = List.from(widget.petProfile.healthChart.intakeDetails)..sort((a,b) => a.date.compareTo(b.date));
                        if (sortedDetails.length <= touchedIndex) return null;

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
                },
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              show: true,
              rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  getTitlesWidget: _customLeftTitleWidgets,
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) => FlLine(
                  color: kSecondaryColor.withOpacity(0.7), strokeWidth: 1),
            ),
            minX: 0,
            maxX: (spots.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: kPrimaryColor.withOpacity(0.7),
                barWidth: 2,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return AspectRatio(
      aspectRatio: 1.7,
      child: InkWell(
        onTap: widget.onAddRecordPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: kBackgroundColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_chart_rounded, color: kOnSurfaceColor, size: 40),
              SizedBox(height: 16),
              Text(
                '여기를 눌러서 첫 건강 기록을 추가해보세요!',
                style: TextStyle(fontSize: 16, color: kOnSurfaceColor),
              ),
            ],
          ),
        ),
      ),
    );
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
                    : null),
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
}

class RecentRecordList extends StatefulWidget {
  final List<DiaryEntry> diaries;
  final List<MedicationAlarm> alarms;
  const RecentRecordList(
      {super.key, required this.diaries, required this.alarms});
  @override
  State<RecentRecordList> createState() => _RecentRecordListState();
}

class _RecentRecordListState extends State<RecentRecordList> {
  bool _isDiaryList = true;
  @override
  Widget build(BuildContext context) {
    // 최신순으로 정렬
    widget.diaries.sort((a,b) => b.date.compareTo(a.date));
    widget.alarms.sort((a,b) {
      int hourCompare = a.time.hour.compareTo(b.time.hour);
      if (hourCompare != 0) return hourCompare;
      return a.time.minute.compareTo(b.time.minute);
    });

    final listToDisplay = _isDiaryList ? widget.diaries : widget.alarms;

    return Column(
      children: [
        Container(
          color: kBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('날짜', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 40),
                const Expanded(
                    child: Text('내용',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                TextButton(
                  onPressed: () => setState(() => _isDiaryList = !_isDiaryList),
                  child: const Text('전환',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        if (listToDisplay.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Text(
              _isDiaryList ? '작성된 일기가 없습니다.' : '설정된 알람이 없습니다.',
              style: const TextStyle(color: kOnSurfaceColor),
            ),
          )
        else
          ...List.generate(min(5, listToDisplay.length), (index) { // 최근 5개만 표시
            final item = listToDisplay[index];
            String dateText, contentText;
            if (item is DiaryEntry) {
              dateText = '${item.date.month}/${item.date.day}';
              contentText = item.title;
            } else if (item is MedicationAlarm) {
              dateText = item.time.format(context);
              contentText = item.label;
            } else {
              dateText = '';
              contentText = '';
            }
            return _buildListItem(dateText, contentText, index);
          }),
      ],
    );
  }

  Widget _buildListItem(String date, String content, int index) {
    final bool isEven = index % 2 == 0;
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        color: isEven ? kBackgroundColor : Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
                width: 70,
                child: Text(date, style: const TextStyle(fontSize: 14))),
            Expanded(
                child: Text(content, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: kOnSurfaceColor),
          ],
        ));
  }
}