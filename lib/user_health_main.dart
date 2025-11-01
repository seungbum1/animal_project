// user_health_main.dart (하단 네비게이션 통일 버전)
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/user_add_health_record_dialog.dart';
import 'package:animal_project/user_health_detail_screen.dart';
import 'package:animal_project/user_health_diary_screen.dart';
import 'package:animal_project/user_medication_alarm_list_screen.dart';
import 'package:animal_project/user_diary_detail_screen.dart';
import 'package:animal_project/user_health_dashboard_viewmodel.dart';

import 'user_mainscreen.dart';
import 'user_myhospital_list.dart';

const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);

class HealthDashboardScreen extends StatefulWidget {
  final String? token;
  final bool showBottomNav;
  const HealthDashboardScreen({super.key, this.token, this.showBottomNav = true});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  late final HealthDashboardViewModel _viewModel;

  void _noAnimReplace(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _viewModel = HealthDashboardViewModel(token: widget.token ?? '');
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showAddRecordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AddHealthRecordDialog(token: widget.token ?? '');
      },
    );
    if (result == true) {
      _viewModel.fetchPetProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(),
          body: _buildBody(),
          bottomNavigationBar: widget.showBottomNav ? _buildBottomNavBar() : null,
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false, // 뒤로가기 제거
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 25, height: 15, decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            _viewModel.petProfile?.name ?? '건강관리',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }
    if (_viewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('데이터 로딩 실패: ${_viewModel.error}'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _viewModel.fetchPetProfile, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_viewModel.petProfile == null) {
      return const Center(child: Text('반려동물 프로필 정보가 없습니다.'));
    }

    final petProfile = _viewModel.petProfile!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_viewModel.medicationMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('건강 기록 대시보드',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          HealthChartDashboard(
            petProfile: petProfile,
            token: widget.token ?? '',
            onAddRecordPressed: _showAddRecordDialog,
            onRecordAdded: _viewModel.fetchPetProfile,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionCard(context, petProfile, icon: Icons.article_outlined, label: '일기', iconBackgroundColor: kSecondaryColor.withOpacity(0.5)),
                _buildActionCard(context, petProfile, icon: Icons.local_pharmacy_outlined, label: '복용량 설정', iconBackgroundColor: const Color(0xFFC06362).withOpacity(0.2)),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, PetProfile petProfile,
      {required IconData icon, required String label, required Color iconBackgroundColor}) {
    return InkWell(
      onTap: () {
        if (label == '일기') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => HealthDiaryScreen(token: widget.token ?? '')))
              .then((_) => _viewModel.fetchPetProfile());
        } else if (label == '복용량 설정') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => MedicationAlarmListScreen(initialAlarms: petProfile.alarms, token: widget.token ?? '')))
              .then((_) => _viewModel.fetchPetProfile());
        }
      },
      child: Container(
          width: MediaQuery.of(context).size.width / 2 - 30,
          height: 120,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kSecondaryColor, width: 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Container(padding: const EdgeInsets.all(8), child: Icon(icon, size: 44, color: kPrimaryColor)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kOnSurfaceColor))
          ])),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 1,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black45,
      onTap: (i) {
        switch (i) {
          case 0:
            _noAnimReplace(PetHomeScreen(token: widget.token ?? ''));
            break;
          case 1:
          // 현재 화면
            break;
          case 2:
            _noAnimReplace(UserMyHospitalListPage(token: widget.token));
            break;
          case 3:
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('마이페이지는 준비 중입니다.')));
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
        BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined), label: '내 병원'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
      ],
    );
  }
}

// 이하의 HealthChartDashboard, TabbableHealthChart, ActivityCalendar 등은 기존 그대로 유지
// (당신이 올린 최신 버전 그대로 복사)


// ======================================================================
// HealthChartDashboard 위젯
// ======================================================================
class HealthChartDashboard extends StatelessWidget {
  final PetProfile petProfile;
  final String token;
  final VoidCallback onAddRecordPressed;
  final VoidCallback onRecordAdded;

  const HealthChartDashboard({
    super.key,
    required this.petProfile,
    required this.token,
    required this.onAddRecordPressed,
    required this.onRecordAdded,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = petProfile.healthChart.weightDetails.isEmpty &&
        petProfile.healthChart.activityDetails.isEmpty &&
        petProfile.healthChart.intakeDetails.isEmpty;

    return isEmpty
        ? _buildEmptyState(context)
        : Column(
      children: [
        // ✅ [개선] 탭으로 분리된 차트 위젯을 호출합니다.
        TabbableHealthChart(petProfile: petProfile),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: _buildInteractiveCalendarSection(context),
        ),
      ],
    );
  }

  Widget _buildInteractiveCalendarSection(BuildContext context) {
    // ... (이하 코드는 기존과 동일)
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('주간 목표 및 기록 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
            SizedBox(
              height: 28,
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => HealthDetailScreen(petProfile: petProfile, token: token)));
                  if (result == true) onRecordAdded();
                },
                style: TextButton.styleFrom(backgroundColor: kPrimaryColor.withOpacity(0.1), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('자세히 보기', style: TextStyle(fontSize: 12, color: kPrimaryColor, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 10, color: kPrimaryColor),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ActivityCalendar(
          weightDetails: petProfile.healthChart.weightDetails,
          activityDetails: petProfile.healthChart.activityDetails,
          intakeDetails: petProfile.healthChart.intakeDetails,
          diaries: petProfile.diaries,
          onDateSelected: (date) => _showDailySummarySheet(context, date),
        ),
      ],
    );
  }

  void _showDailySummarySheet(BuildContext context, DateTime date) {
    // ... (기존 코드와 동일)
    final weightRecord = petProfile.healthChart.weightDetails.where((r) => isSameDay(r.date, date)).toList();
    final activityRecord = petProfile.healthChart.activityDetails.where((r) => isSameDay(r.date, date)).toList();
    final intakeRecord = petProfile.healthChart.intakeDetails.where((r) => isSameDay(r.date, date)).toList();
    final diaryEntry = petProfile.diaries.where((d) => isSameDay(d.date, date)).firstOrNull;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(DateFormat('M월 d일 (E) 요약', 'ko_KR').format(date), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (weightRecord.isNotEmpty) _buildSummaryRow('체중', '${weightRecord.first.bodyWeight?.toStringAsFixed(1) ?? 'N/A'}kg'),
              if (activityRecord.isNotEmpty) _buildSummaryRow('활동', '${activityRecord.first.time ?? 'N/A'}분'),
              if (intakeRecord.isNotEmpty) _buildSummaryRow('사료', '${intakeRecord.first.food ?? 'N/A'}g'),
              if (diaryEntry != null)
                _buildTappableSummaryRow(context, '일기', diaryEntry.title, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryDetailScreen(diaryEntry: diaryEntry, token: token)))
                      .then((_) => onRecordAdded());
                },
                ),
            ],
          ),
        );
      },
    );
  }

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  Widget _buildSummaryRow(String title, String value) {
    // ...
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kOnSurfaceColor), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
  Widget _buildTappableSummaryRow(BuildContext context, String title, String value, VoidCallback onTap) {
    // ...
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            Expanded(
              child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPrimaryColor), overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: kPrimaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: InkWell(
        onTap: onAddRecordPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(color: kBackgroundColor.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_chart_rounded, color: kOnSurfaceColor, size: 40),
            SizedBox(height: 16),
            Text('여기를 눌러서 첫 건강 기록을 추가해보세요!', style: TextStyle(fontSize: 16, color: kOnSurfaceColor)),
          ]),
        ),
      ),
    );
  }
}


// ✅✅✅ [신규] 탭으로 분리된 차트 위젯 ✅✅✅
// 기존의 정규화된 복합 차트 대신, 각 데이터를 명확하게 보여주는 개별 차트로 변경합니다.
class TabbableHealthChart extends StatelessWidget {
  final PetProfile petProfile;

  const TabbableHealthChart({super.key, required this.petProfile});

  static const Color kWeightLineColor = Color(0xFF547AA5);
  static const Color kActivityLineColor = Color(0xFF6A994E);
  static const Color kIntakeLineColor = Color(0xFFE9C46A);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: kPrimaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kPrimaryColor,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: '체중(kg)'),
              Tab(text: '활동량(분)'),
              Tab(text: '섭취량(g)'),
            ],
          ),
          SizedBox(
            height: 220, // 차트 영역의 높이를 고정
            child: TabBarView(
              children: [
                _buildSingleMetricChart(
                  records: petProfile.healthChart.weightDetails,
                  getValue: (record) => (record as WeightRecord).bodyWeight,
                  lineColor: kWeightLineColor,
                  unit: 'kg',
                ),
                _buildSingleMetricChart(
                  records: petProfile.healthChart.activityDetails,
                  getValue: (record) => (record as ActivityRecord).time,
                  lineColor: kActivityLineColor,
                  unit: '분',
                ),
                _buildSingleMetricChart(
                  records: petProfile.healthChart.intakeDetails,
                  getValue: (record) => (record as IntakeRecord).food,
                  lineColor: kIntakeLineColor,
                  unit: 'g',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 각 데이터 타입에 맞는 개별 차트를 그리는 재사용 가능한 메서드
  Widget _buildSingleMetricChart({
    required List<dynamic> records,
    required num? Function(dynamic) getValue,
    required Color lineColor,
    required String unit,
  }) {
    if (records.isEmpty) {
      return Center(child: Text('표시할 데이터가 없습니다.', style: TextStyle(color: Colors.grey[600])));
    }

    records.sort((a, b) => a.date.compareTo(b.date));
    final spots = records.asMap().entries.map((entry) {
      final index = entry.key;
      final value = getValue(entry.value);
      return FlSpot(index.toDouble(), value?.toDouble() ?? 0.0);
    }).toList();

    final allValues = records.map(getValue).whereType<num>().toList();
    double maxY = allValues.isNotEmpty ? allValues.reduce(max).toDouble() : 10.0;
    maxY = (maxY * 1.2); // Y축 상단에 여유 공간 확보

    return Padding(
      padding: const EdgeInsets.only(right: 28.0, left: 16.0, top: 24, bottom: 12),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              // ✅ [수정] 툴팁이 잘리지 않도록 하는 속성 추가
              fitInsideVertically: true,
              getTooltipColor: (_) => Colors.black.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final record = records[spot.spotIndex];
                  final value = getValue(record);
                  final isDouble = unit == 'kg';
                  final valueString = isDouble ? value?.toStringAsFixed(1) : value?.toInt().toString();

                  return LineTooltipItem(
                    '${DateFormat('MM/dd').format(record.date)}\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: '$valueString $unit',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: kSecondaryColor.withOpacity(0.5), strokeWidth: 1)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (value, meta) {
              if (value == meta.max || value == meta.min) return Container();
              return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.left);
            })),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= records.length) return Container();
              if (index == 0 || index == records.length - 1) {
                return Text(DateFormat('MM/dd').format(records[index].date), style: const TextStyle(color: Colors.grey, fontSize: 12));
              }
              return Container();
            })),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minX: 0,
          maxX: (records.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 3,
              dotData: FlDotData(show: spots.length < 20),
              belowBarData: BarAreaData(show: true, color: lineColor.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }
}


// ActivityCalendar 위젯 (기존 코드와 동일)
class ActivityCalendar extends StatefulWidget {
  // ...
  final List<WeightRecord> weightDetails;
  final List<ActivityRecord> activityDetails;
  final List<IntakeRecord> intakeDetails;
  final List<DiaryEntry> diaries;
  final Function(DateTime) onDateSelected;
  final int weeklyGoal = 5;

  const ActivityCalendar({
    super.key,
    required this.weightDetails,
    required this.activityDetails,
    required this.intakeDetails,
    required this.diaries,
    required this.onDateSelected,
  });

  @override
  State<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<ActivityCalendar> {
  // ... (이하 ActivityCalendar의 모든 코드는 기존과 동일합니다.)
  late DateTime _displayDate;

  @override
  void initState() {
    super.initState();
    _displayDate = DateTime.now();
  }

  int _calculateStreak(Set<DateTime> recordDays) {
    if (recordDays.isEmpty) return 0;
    int streak = 0;
    DateTime today = DateTime.now();
    DateTime currentDate = DateTime(today.year, today.month, today.day);
    if (!recordDays.contains(currentDate)) {
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    while (recordDays.contains(currentDate)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void _changeMonth(int month) {
    setState(() {
      _displayDate = DateTime(_displayDate.year, _displayDate.month + month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<DateTime, Set<String>> recordTypesByDay = {};
    for (var record in widget.weightDetails) {
      final day = DateTime(record.date.year, record.date.month, record.date.day);
      (recordTypesByDay[day] ??= {}).add('weight');
    }
    for (var record in widget.activityDetails) {
      final day = DateTime(record.date.year, record.date.month, record.date.day);
      (recordTypesByDay[day] ??= {}).add('activity');
    }
    for (var record in widget.intakeDetails) {
      final day = DateTime(record.date.year, record.date.month, record.date.day);
      (recordTypesByDay[day] ??= {}).add('intake');
    }
    for (var diary in widget.diaries) {
      final day = DateTime(diary.date.year, diary.date.month, diary.date.day);
      (recordTypesByDay[day] ??= {}).add('diary');
    }

    final today = DateTime.now();
    final startOfDisplayMonth = DateTime(_displayDate.year, _displayDate.month, 1);
    final calendarStartDate = startOfDisplayMonth.subtract(Duration(days: startOfDisplayMonth.weekday - 1));

    final streak = _calculateStreak(recordTypesByDay.keys.toSet());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeeklyGoalCard(recordTypesByDay),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: () => _changeMonth(-1)),
            Expanded(
              child: Text(
                DateFormat('yyyy년 M월', 'ko_KR').format(_displayDate),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: _displayDate.year == today.year && _displayDate.month == today.month ? null : () => _changeMonth(1),
            ),
          ],
        ),
        if (streak > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: Center(child: Text('🔥 $streak일 연속 기록 중!', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold))),
          ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final date = calendarStartDate.add(Duration(days: index));
            final dayKey = DateTime(date.year, date.month, date.day);
            final types = recordTypesByDay[dayKey];
            final hasRecord = types != null && types.isNotEmpty;
            final isCurrentMonth = date.month == _displayDate.month;

            Color color = hasRecord ? kPrimaryColor.withOpacity(0.3) : kSecondaryColor.withOpacity(0.5);
            if (hasRecord && types.length > 1) color = kPrimaryColor.withOpacity(min(0.3 + types.length * 0.1, 1.0));

            return GestureDetector(
              onTap: hasRecord ? () => widget.onDateSelected(date) : null,
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isCurrentMonth ? kOnSurfaceColor : Colors.grey.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: hasRecord ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (hasRecord) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (types.contains('weight')) _buildDot(TabbableHealthChart.kWeightLineColor),
                          if (types.contains('activity')) _buildDot(TabbableHealthChart.kActivityLineColor),
                          if (types.contains('intake')) _buildDot(TabbableHealthChart.kIntakeLineColor),
                          if (types.contains('diary')) const Icon(Icons.article, color: kPrimaryColor, size: 5),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeeklyGoalCard(Map<DateTime, Set<String>> recordTypesByDay) {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    int currentWeekRecordDays = 0;
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      if (day.isAfter(today)) continue;
      final dayKey = DateTime(day.year, day.month, day.day);
      if (recordTypesByDay.containsKey(dayKey)) {
        currentWeekRecordDays++;
      }
    }

    final progress = min(currentWeekRecordDays / widget.weeklyGoal, 1.0);
    final bool isGoalAchieved = progress >= 1.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBackgroundColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('이번 주 목표', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
              isGoalAchieved
                  ? const Text('목표 달성! 🏆', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPrimaryColor))
                  : Text('$currentWeekRecordDays / ${widget.weeklyGoal} 일', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: kSecondaryColor.withOpacity(0.5),
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 4, height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 0.5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}