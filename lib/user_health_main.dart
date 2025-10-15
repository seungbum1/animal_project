import 'package:animal_project/user_add_health_record_dialog.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:animal_project/user_health_detail_screen.dart';
import 'package:animal_project/user_health_diary_screen.dart';
import 'package:animal_project/user_medication_alarm_list_screen.dart';

// ==================== ⬇️ Data Models ⬇️ ====================

class WeightRecord {
  final DateTime date;
  final double? bodyWeight;
  WeightRecord({required this.date, this.bodyWeight});
  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    final dynamic weightValue = json['value'] ?? json['bodyWeight'];
    return WeightRecord(
      date: DateTime.parse(json['date']),
      bodyWeight: (weightValue as num?)?.toDouble(),
    );
  }
}

class ActivityRecord {
  final DateTime date;
  final int? time;
  ActivityRecord({required this.date, this.time});
  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    return ActivityRecord(
      date: DateTime.parse(json['date']),
      time: (json['value'] as num?)?.toInt(),
    );
  }
}

class IntakeRecord {
  final DateTime date;
  final int? food;
  IntakeRecord({required this.date, this.food});
  factory IntakeRecord.fromJson(Map<String, dynamic> json) {
    return IntakeRecord(
      date: DateTime.parse(json['date']),
      food: (json['value'] as num?)?.toInt(),
    );
  }
}

class PetProfile {
  final String name;
  final int age;
  final String gender;
  final List<DiaryEntry> diaries;
  final List<MedicationAlarm> alarms;
  final HealthChart healthChart;
  PetProfile(
      {required this.name,
        required this.age,
        required this.gender,
        required this.diaries,
        required this.alarms,
        required this.healthChart});
  factory PetProfile.fromJson(Map<String, dynamic> json) {
    var diaryList = json['diaries'] as List? ?? [];
    var alarmList = json['alarms'] as List? ?? [];
    return PetProfile(
      name: json['name'] ?? '이름 없음',
      age: json['age'] ?? 0,
      gender: json['gender'] ?? '',
      diaries: diaryList.map((d) => DiaryEntry.fromJson(d)).toList(),
      alarms: alarmList.map((a) => MedicationAlarm.fromJson(a)).toList(),
      healthChart: HealthChart.fromJson(json['healthChart'] ?? {}),
    );
  }
}

class HealthChart {
  final List<ChartDataPoint> weight;
  final List<ChartDataPoint> activity;
  final List<ChartDataPoint> intake;
  final List<WeightRecord> weightDetails;
  final List<ActivityRecord> activityDetails;
  final List<IntakeRecord> intakeDetails;
  HealthChart(
      {required this.weight,
        required this.activity,
        required this.intake,
        required this.weightDetails,
        required this.activityDetails,
        required this.intakeDetails});
  factory HealthChart.fromJson(Map<String, dynamic> json) {
    var activityList = json['activity'] as List? ?? [];
    var intakeList = json['intake'] as List? ?? [];
    var weightList = json['weight'] as List? ?? [];
    return HealthChart(
      weight: weightList.map((p) => ChartDataPoint.fromJson(p)).toList(),
      activity: activityList.map((p) => ChartDataPoint.fromJson(p)).toList(),
      intake: intakeList.map((p) => ChartDataPoint.fromJson(p)).toList(),
      weightDetails: weightList.map((p) => WeightRecord.fromJson(p)).toList(),
      activityDetails:
      activityList.map((p) => ActivityRecord.fromJson(p)).toList(),
      intakeDetails: intakeList.map((p) => IntakeRecord.fromJson(p)).toList(),
    );
  }
}

class ChartDataPoint {
  final DateTime date;
  final double value;
  ChartDataPoint({required this.date, required this.value});
  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    final dynamic value = json['value'] ?? json['bodyWeight'];
    return ChartDataPoint(
      date: DateTime.parse(json['date']),
      value: (value as num? ?? 0).toDouble(),
    );
  }
}

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String imagePath;
  DiaryEntry(
      {required this.id,
        required this.title,
        required this.content,
        required this.date,
        required this.imagePath});
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: DateTime.parse(json['date']),
      imagePath: json['imagePath'] ?? '',
    );
  }
}

class MedicationAlarm {
  final String id;
  final TimeOfDay time;
  final String label;
  final bool isActive;
  MedicationAlarm(
      {required this.id,
        required this.time,
        required this.label,
        required this.isActive});
  factory MedicationAlarm.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String? ?? '00:00').split(':');
    return MedicationAlarm(
      id: json['_id'] ?? '',
      time: TimeOfDay(
          hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1])),
      label: json['label'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }
}

// ==================== ⬆️ Data Models End ⬆️ ====================

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

  // ✅ 데이터를 새로고침하는 중앙 함수
  void _refreshData() {
    if (mounted) {
      setState(() {
        _petProfileFuture = fetchPetProfile();
      });
    }
  }

  // ✅ 기록 추가 다이얼로그는 이제 성공 시 중앙 함수를 호출
  void _showAddRecordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AddHealthRecordDialog(token: widget.token);
      },
    );
    if (result == true) {
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
                  // ✅ 새로고침 함수를 콜백으로 전달
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
  // ✅ 새로고침 콜백 함수를 받을 변수 추가
  final VoidCallback onRecordAdded;

  const HealthChartDashboard(
      {super.key,
        required this.petProfile,
        required this.token,
        required this.onAddRecordPressed,
        // ✅ 생성자에 콜백 함수 추가
        required this.onRecordAdded});
  @override
  State<HealthChartDashboard> createState() => _HealthChartDashboardState();
}

class _HealthChartDashboardState extends State<HealthChartDashboard> {
  String _selectedDataType = '체중';
  @override
  Widget build(BuildContext context) {
    List<ChartDataPoint> dataPoints;
    switch (_selectedDataType) {
      case '활동량':
        dataPoints = widget.petProfile.healthChart.activity;
        break;
      case '섭취량':
        dataPoints = widget.petProfile.healthChart.intake;
        break;
      case '체중':
      default:
        dataPoints = widget.petProfile.healthChart.weight;
        break;
    }
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
                  // ✅ 상세화면에서 기록 추가 후 돌아왔다면, 전달받은 콜백 함수를 실행
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
    const style = TextStyle(
        color: kOnSurfaceColor, fontWeight: FontWeight.bold, fontSize: 12);
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

  Widget _buildChartArea(List<ChartDataPoint> dataPoints) {
    if (dataPoints.isEmpty) {
      return const AspectRatio(
          aspectRatio: 1.7, child: Center(child: Text("표시할 데이터가 없습니다.")));
    }
    final spots = List.generate(dataPoints.length,
            (index) => FlSpot(index.toDouble(), dataPoints[index].value));
    final dateLabels =
    dataPoints.map((p) => '${p.date.month}-${p.date.day}').toList();
    double minData = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxData = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    double dataRange = maxData - minData;
    if (dataRange < 0.1) {
      dataRange = maxData * 0.2;
      if (dataRange < 1.0) dataRange = 1.0;
      minData = max(0, maxData - dataRange);
    }
    final padding = dataRange * 0.2;
    final minY = max(0, minData - padding);
    final maxY = maxData + padding;
    final chartRange = maxY - minY;
    final double interval = _getNiceInterval(chartRange);
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
                getTooltipColor: (spot) => Colors.black.withOpacity(0.8),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)} ${_getUnitForTooltip(_selectedDataType)}',
                      const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList();
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
                      interval: (dateLabels.length / 5)
                          .ceilToDouble()
                          .clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < dateLabels.length) {
                          return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8.0,
                              child: Text(dateLabels[index],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 10)));
                        }
                        return Container();
                      })),
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
            minY: minY.toDouble(),
            maxY: maxY.toDouble(),
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

  String _getUnitForTooltip(String dataType) {
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
          ...List.generate(listToDisplay.length, (index) {
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
                child: Text(content, style: const TextStyle(fontSize: 14))),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: kOnSurfaceColor),
          ],
        ));
  }
}