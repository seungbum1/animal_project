import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// 전역 테마 색상 참고
const Color kPrimaryColor = Color(0xFFC06362); // 버건디 (메인 포인트 색상)
const Color kBackgroundColor = Color(0xFFFFF7E7); // 연노랑 (베이스 배경 색상)
const Color kOnSurfaceColor = Color(0xFF616161); // 텍스트 색상
const Color kSecondaryColor = Color(0xFFD9D9D9); // 보조 경계선/회색

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  String _selectedDataType = '체중';
  bool _isDiaryList = true;

  // --- 임시 데이터 ---
  final String _petName = '동물 1';
  final String _nextAlarm = '3시간 뒤 약을 복용할 시간입니다.';

  final Map<String, List<FlSpot>> _graphData = {
    '체중': [
      const FlSpot(0, 5.2), const FlSpot(1, 5.1), const FlSpot(2, 5.0), const FlSpot(3, 5.1),
      const FlSpot(4, 5.3), const FlSpot(5, 5.4), const FlSpot(6, 5.2), const FlSpot(7, 5.5),
    ],
    '활동량': [
      const FlSpot(0, 45), const FlSpot(1, 60), const FlSpot(2, 55), const FlSpot(3, 70),
      const FlSpot(4, 85), const FlSpot(5, 75), const FlSpot(6, 65), const FlSpot(7, 90),
    ],
    '섭취량': [
      const FlSpot(0, 150), const FlSpot(1, 140), const FlSpot(2, 155), const FlSpot(3, 160),
      const FlSpot(4, 150), const FlSpot(5, 145), const FlSpot(6, 155), const FlSpot(7, 170),
    ],
  };

  final List<String> _dateLabels = [
    '25.07.01', '25.07.05', '25.07.09', '25.07.12',
    '25.07.15', '25.07.19', '25.07.23', '25.07.27',
  ];

  final List<Map<String, String>> _recentDiaries = [
    {'date': '10/21', 'content': '한별이랑 산책한 날'},
    {'date': '10/21', 'content': '컨디션이 좋아보임'},
    {'date': '10/20', 'content': '병원 진료 받은 날'},
    {'date': '10/19', 'content': '새로운 사료 급여 시작'},
    {'date': '10/17', 'content': '간식 너무 좋아하는 하루'},
  ];

  final List<Map<String, String>> _alarmList = [
    {'date': '오전 9:00', 'content': '심장약 복용'},
    {'date': '오후 6:00', 'content': '식사 급여 (사료 A)'},
    {'date': '오후 9:00', 'content': '영양제 복용'},
    {'date': '오전 8:00', 'content': '관절약 복용'},
    {'date': '오후 5:00', 'content': '간식 급여'},
  ];
  // -----------------

  // 단위 반환 함수
  String _getUnit(String dataType) {
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
  // -----------------

  // 건강 기록 버튼 위젯 (선택 시 연노랑 배경, 버건디 경계)
  Widget _buildDataButton(String title) {
    bool isSelected = (_selectedDataType == title);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: OutlinedButton(
          onPressed: () {
            setState(() {
              _selectedDataType = title;
            });
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected ? kBackgroundColor : Colors.white,
            side: BorderSide(
                color: isSelected ? kPrimaryColor.withOpacity(0.7) : kSecondaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? kPrimaryColor : kOnSurfaceColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // 일기/알람 리스트 항목 위젯 (연노랑 투명 배경)
  Widget _buildListItem(String date, String content) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
      margin: const EdgeInsets.only(bottom: 1.0),
      color: kBackgroundColor.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 80,
            child: Text(date, style: TextStyle(fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
          ),
          Expanded(
            child: Text(content, style: TextStyle(color: kOnSurfaceColor)),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listToDisplay = _isDiaryList ? _recentDiaries : _alarmList;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white, // 전체 Scaffold 배경은 흰색 유지 (AppBar와 일치)
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.arrow_back_ios, color: Colors.black),
            Row(
              children: [
                Container(
                  width: 15, height: 15,
                  decoration: BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(_petName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Icon(Icons.arrow_drop_down, color: Colors.black87),
              ],
            ),
            const SizedBox(width: 24),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 최근 알람 섹션 (포인트 색상)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _nextAlarm,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor),
              ),
            ),

            // 2. 건강 기록 대시보드 제목
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                '건강 기록 대시보드',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),

            // 3. 데이터 선택 버튼
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

            // 4. 그래프 영역 (FL Chart)
            _buildChartArea(),

            // 5. 기능 바로가기 버튼 (자세히보기 - 버건디 배경)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildShortcutButton(Icons.book, '일기', () => debugPrint('일기 페이지 이동')),
                  _buildShortcutButton(Icons.access_alarm, '복용 알람 설정', () => debugPrint('알람 설정 페이지 이동')),
                ],
              ),
            ),

            // 6. 최근 기록/알람 리스트 제목 및 전환 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('최근 기록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isDiaryList = !_isDiaryList; // 일기 <-> 알람 전환
                      });
                    },
                    child: const Text('전환', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // 리스트 본문 (연노랑 투명 배경)
            ...listToDisplay.map((item) => _buildListItem(item['date']!, item['content']!)).toList(),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(theme),
    );
  }

  // FL Chart를 포함하는 그래프 영역 위젯
  Widget _buildChartArea() {
    final data = _graphData[_selectedDataType] ?? [];

    if (data.isEmpty) {
      return Container(
        height: 250,
        margin: const EdgeInsets.all(16.0),
        child: const Center(child: Text('데이터가 없습니다.')),
      );
    }

    double minY = data.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 0.5;
    double maxY = data.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 0.5;

    // Y축 간격 설정을 위한 조건부 로직 추가
    double leftTitlesInterval;
    switch (_selectedDataType) {
      case '체중':
        leftTitlesInterval = 0.5; // 체중은 0.5kg 단위로 세분화
        break;
      case '활동량':
        leftTitlesInterval = 10; // 활동량은 10분 단위로 표시
        break;
      case '섭취량':
        leftTitlesInterval = 20; // 섭취량은 20g 단위로 표시
        break;
      default:
        leftTitlesInterval = 1;
    }


    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.only(right: 28.0, left: 12.0, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            // 1. 차트 테두리
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.shade300, width: 4),
            ),
            // 2. 제목 (X, Y축)
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              // X축 (날짜) 설정: 첫 번째와 마지막 날짜만 표시
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    // 첫 번째 (index 0) 또는 마지막 날짜만 표시
                    if (index == 0 || index == _dateLabels.length - 1) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8.0,
                        child: Text(_dateLabels[index], style: TextStyle(color: kOnSurfaceColor, fontSize: 14)),
                      );
                    }
                    return Container(); // 나머지 날짜는 숨김
                  },
                ),
              ),
              // Y축 (수치) 설정: reservedSize 확대 및 간격 동적 설정
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  // Y축 라벨 겹침 해결: reservedSize를 넓게 설정 (60)
                  reservedSize: 30,
                  // Y축 간격을 동적으로 설정
                  interval: leftTitlesInterval,
                  // Y축 라벨 겹침 문제 해결을 위해 커스텀 위젯을 사용합니다.
                  getTitlesWidget: (value, meta) => _customLeftTitleWidgets(value, meta, leftTitlesInterval),
                ),
              ),
            ),
            // 3. Grid Lines (격자)
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: leftTitlesInterval, // 격자도 Y축 간격에 맞춰 동적 설정
              verticalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            ),
            // 4. 범위 설정
            minX: 0,
            maxX: data.length.toDouble() - 1,
            minY: minY,
            maxY: maxY,
            // 5. Line Data (선 그래프)
            lineBarsData: [
              LineChartBarData(
                spots: data,
                isCurved: true,
                color: kPrimaryColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: kPrimaryColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(show: false),
              ),
            ],
            // 6. 툴팁 (수치 명시 대체)
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                // 배경색 파라미터 제거
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final unit = _getUnit(_selectedDataType);
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)}$unit',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Y축 타이틀 위젯 (겹침 문제 해결 로직 통합)
  Widget _customLeftTitleWidgets(double value, TitleMeta meta, double interval) {
    const style = TextStyle(
      color: kOnSurfaceColor,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    String text;

    // 1. 필터링 로직: 간격의 배수가 아니면 표시하지 않음
    // 부동소수점 오차를 고려하여 작은 허용 오차(tolerance)를 사용합니다.
    const double tolerance = 0.001;

    // 간격의 배수이거나 (오차 내), min/max 값일 때만 표시
    bool isMultiple = (value - meta.min).abs() % interval < tolerance || (interval - (value - meta.min).abs() % interval) < tolerance;

    if (!isMultiple && value != meta.min && value != meta.max) {
      return Container();
    }


    // 2. 데이터 타입에 따라 소수점 처리 방식 변경
    if (_selectedDataType == '체중') {
      text = value.toStringAsFixed(1); // 체중은 소수점 첫째 자리까지 표시
    } else {
      // 활동량, 섭취량은 정수로 표시
      text = value.toStringAsFixed(0);
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10.0, // 라벨 겹침 방지를 위해 충분한 공간 확보
      child: Text(text, style: style),
    );
  }

  // 일기/알람 바로가기 버튼 위젯
  Widget _buildShortcutButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kPrimaryColor, // 버건디색 배경
              border: Border.all(color: kPrimaryColor, width: 1),
            ),
            child: Icon(icon, size: 30, color: Colors.white), // const 제거
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: kOnSurfaceColor)), // const 제거
        ],
      ),
    );
  }

  // 하단 네비게이션 바 위젯
  Widget _buildBottomNavBar(ThemeData theme) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: kPrimaryColor, // 포인트 색상
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      currentIndex: 1, // 건강관리 탭
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '건강관리'),
        BottomNavigationBarItem(icon: Icon(Icons.local_hospital), label: '내 병원'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이페이지'),
      ],
    );
  }
}