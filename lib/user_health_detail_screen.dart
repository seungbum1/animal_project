// user_health_detail_screen.dart (에러 최종 수정 완료)

import 'package:animal_project/user_add_health_record_dialog.dart';
import 'package:animal_project/user_date_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/api_config.dart';

// ======================================================================
// 1. 상태 관리(State Management)를 위한 ViewModel 클래스
// ======================================================================

enum ComparisonType { previous, weekly, monthly }

class HealthDetailViewModel extends ChangeNotifier {
  PetProfile _petProfile;
  final String token;

  HealthDetailViewModel(this._petProfile, this.token) {
    // 생성자에서는 값을 읽지 않고 바로 할당하여 초기화 문제를 해결합니다.
    _allRecordDates = allRecordDates;
    if (_allRecordDates.isNotEmpty) {
      _selectedDate = _allRecordDates.last;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  // --- 상태 변수 ---
  String _selectedDataType = '체중';
  late DateTime _selectedDate;
  List<DateTime> _allRecordDates = [];
  bool _isLoading = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  ComparisonType _comparisonType = ComparisonType.previous;

  // --- UI에 데이터를 제공하는 Getter ---
  String get selectedDataType => _selectedDataType;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  ComparisonType get comparisonType => _comparisonType;
  PetProfile get petProfile => _petProfile;

  List<DateTime> get allRecordDates {
    final allRecords = _getAllRecords();
    final allDates = allRecords.map<DateTime>((r) => (r as dynamic).date).toSet().toList()..sort();
    return allDates;
  }

  List<DateTime> get displayedDates {
    if (_filterStartDate != null && _filterEndDate != null) {
      return allRecordDates.where((d) {
        final dateWithoutTime = DateTime(d.year, d.month, d.day);
        final startWithoutTime = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
        final endWithoutTime = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
        return !dateWithoutTime.isBefore(startWithoutTime) && !dateWithoutTime.isAfter(endWithoutTime);
      }).toList();
    } else {
      return allRecordDates;
    }
  }

  // --- 로직 및 메서드 ---
  String get _baseUrl => ApiConfig.baseUrl;

  List<dynamic> _getAllRecords() {
    return [
      ..._petProfile.healthChart.weightDetails,
      ..._petProfile.healthChart.activityDetails,
      ..._petProfile.healthChart.intakeDetails,
    ];
  }

  void _updateAndSetInitialDate() {
    final oldSelectedDate = _selectedDate; // 기존 선택 날짜 저장
    _allRecordDates = allRecordDates;
    if (_allRecordDates.isNotEmpty) {
      // 데이터 새로고침 후에도 기존 선택 날짜가 유효하면 유지, 아니면 마지막 날짜로 설정
      if (_allRecordDates.contains(oldSelectedDate)) {
        _selectedDate = oldSelectedDate;
      } else {
        _selectedDate = _allRecordDates.last;
      }
    } else {
      _selectedDate = DateTime.now();
    }
    notifyListeners();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _petProfile = PetProfile.fromJson(data['user']['petProfile'] ?? {});
        _updateAndSetInitialDate();
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedDate(DateTime date) {
    if (_selectedDate != date) {
      _selectedDate = date;
      notifyListeners();
    }
  }

  void setSelectedDataType(String type) {
    if (_selectedDataType != type) {
      _selectedDataType = type;
      notifyListeners();
    }
  }

  void setFilterDates(DateTime start, DateTime end) {
    _filterStartDate = start;
    _filterEndDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    notifyListeners();
  }

  void clearFilter() {
    _filterStartDate = null;
    _filterEndDate = null;
    notifyListeners();
  }

  void setComparisonType(ComparisonType type) {
    if (_comparisonType != type) {
      _comparisonType = type;
      notifyListeners();
    }
  }

  Future<bool> deleteRecord() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/health-record'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'date': _selectedDate.toUtc().toIso8601String(), 'type': _selectedDataType}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await refreshData();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting record: $e');
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }
}

// ======================================================================
// 2. 재사용 가능한 위젯으로 분리
// ======================================================================
const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);
const Color kLineColor1 = Color(0xFF547AA5);
const Color kLineColor2 = Color(0xFF6A994E);
const Color kLineColor3 = Color(0xFFE9C46A);

class HealthDetailScreen extends StatefulWidget {
  final PetProfile petProfile;
  final String token;

  const HealthDetailScreen({super.key, required this.petProfile, required this.token});

  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  late final HealthDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HealthDetailViewModel(widget.petProfile, widget.token);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(context),
          body: _viewModel.isLoading
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DateNavigator(viewModel: _viewModel),
                DataTypeSelector(viewModel: _viewModel),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: HealthLineChart(
                    key: ValueKey(_viewModel.selectedDataType),
                    viewModel: _viewModel,
                  ),
                ),
                ComparisonModeSelector(viewModel: _viewModel),
                DetailedComparisonSection(viewModel: _viewModel),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final canDelete = _viewModel.allRecordDates.any((d) => d == _viewModel.selectedDate);
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => Navigator.pop(context, true),
      ),
      title: Text(_viewModel.petProfile.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(_viewModel.filterStartDate == null ? Icons.filter_alt_outlined : Icons.filter_alt, color: _viewModel.filterStartDate == null ? Colors.black54 : kPrimaryColor),
          onPressed: () => _showFilterBottomSheet(context),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: canDelete ? Colors.black54 : Colors.grey.shade300),
          onPressed: canDelete ? () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('기록 삭제'),
                content: Text('${DateFormat('yy.MM.dd HH:mm').format(_viewModel.selectedDate)}의 ${_viewModel.selectedDataType} 기록을 정말 삭제하시겠습니까?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                ],
              ),
            );
            if (confirmed == true) {
              final success = await _viewModel.deleteRecord();
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_viewModel.selectedDataType} 기록이 삭제되었습니다.')));
              }
            }
          } : null,
        ),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.black54, size: 28),
          onPressed: () async {
            final result = await showDialog<bool>(context: context, builder: (_) => AddHealthRecordDialog(token: widget.token));
            if (result == true) _viewModel.refreshData();
          },
        ),
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Text('기간 설정', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
                children: [
                  ActionChip(label: const Text('최근 7일'), onPressed: () {
                    final now = DateTime.now();
                    _viewModel.setFilterDates(now.subtract(const Duration(days: 6)), now);
                    Navigator.pop(context);
                  }),
                  ActionChip(label: const Text('최근 30일'), onPressed: () {
                    final now = DateTime.now();
                    _viewModel.setFilterDates(now.subtract(const Duration(days: 29)), now);
                    Navigator.pop(context);
                  }),
                  ActionChip(label: const Text('올해'), onPressed: () {
                    final now = DateTime.now();
                    _viewModel.setFilterDates(DateTime(now.year, 1, 1), now);
                    Navigator.pop(context);
                  }),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(color: kSecondaryColor),
              const SizedBox(height: 15),
              TextButton(child: const Text('기간 직접 선택'), onPressed: () => _showCustomDateRangePicker(context)),
              TextButton(child: const Text('전체 기간 보기 (필터 해제)'), onPressed: () {
                _viewModel.clearFilter();
                Navigator.pop(context);
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCustomDateRangePicker(BuildContext context) async {
    if (Navigator.canPop(context)) Navigator.pop(context);

    final DateTimeRange? pickedRange = await showDialog<DateTimeRange>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          title: const Text('기간 직접 선택', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 300,
            height: 350,
            child: SfDateRangePicker(
              selectionMode: DateRangePickerSelectionMode.range,
              backgroundColor: Colors.white,
              headerStyle: const DateRangePickerHeaderStyle(backgroundColor: Colors.white, textAlign: TextAlign.center, textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
              monthViewSettings: const DateRangePickerMonthViewSettings(viewHeaderStyle: DateRangePickerViewHeaderStyle(textStyle: TextStyle(fontSize: 12, color: Colors.grey))),
              selectionTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              rangeTextStyle: const TextStyle(color: kOnSurfaceColor),
              startRangeSelectionColor: kPrimaryColor,
              endRangeSelectionColor: kPrimaryColor,
              rangeSelectionColor: kPrimaryColor.withOpacity(0.2),
              todayHighlightColor: kPrimaryColor,
              initialSelectedRange: _viewModel.filterStartDate != null && _viewModel.filterEndDate != null
                  ? PickerDateRange(_viewModel.filterStartDate!, _viewModel.filterEndDate!)
                  : null,
              maxDate: DateTime.now().add(const Duration(days: 365)),
              showActionButtons: true,
              cancelText: '취소',
              confirmText: '확인',
              onSubmit: (Object? value) {
                if (value is PickerDateRange) {
                  final startDate = value.startDate;
                  final endDate = value.endDate ?? value.startDate;
                  if (startDate != null && endDate != null) {
                    Navigator.pop(context, DateTimeRange(start: startDate, end: endDate));
                  } else {
                    Navigator.pop(context);
                  }
                } else {
                  Navigator.pop(context);
                }
              },
              onCancel: () => Navigator.pop(context),
            ),
          ),
        );
      },
    );

    if (pickedRange != null) {
      _viewModel.setFilterDates(pickedRange.start, pickedRange.end);
    }
  }
}

// --- 분리된 위젯들 ---

class DateNavigator extends StatelessWidget {
  final HealthDetailViewModel viewModel;
  const DateNavigator({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final dates = viewModel.displayedDates;
    if (dates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text("표시할 기록이 없습니다.", style: TextStyle(fontSize: 16, color: Colors.grey))),
      );
    }

    final currentIndex = dates.indexOf(viewModel.selectedDate);
    final canGoPrevious = currentIndex > 0;
    final canGoNext = currentIndex != -1 && currentIndex < dates.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: canGoPrevious ? () => viewModel.setSelectedDate(dates[currentIndex - 1]) : null,
            icon: Icon(Icons.arrow_back_ios, size: 18, color: canGoPrevious ? Colors.black : Colors.grey.shade300),
          ),
          InkWell(
            onTap: () async {
              final pickedDate = await Navigator.push<DateTime>(
                context,
                MaterialPageRoute(builder: (_) => DateSelectionScreen(allDates: dates, initialDate: viewModel.selectedDate)),
              );
              if (pickedDate != null) viewModel.setSelectedDate(pickedDate);
            },
            child: Text(
              DateFormat('yy.MM.dd (E) HH:mm', 'ko_KR').format(viewModel.selectedDate),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: canGoNext ? () => viewModel.setSelectedDate(dates[currentIndex + 1]) : null,
            icon: Icon(Icons.arrow_forward_ios, size: 18, color: canGoNext ? Colors.black : Colors.grey.shade300),
          ),
        ],
      ),
    );
  }
}

class DataTypeSelector extends StatelessWidget {
  final HealthDetailViewModel viewModel;
  const DataTypeSelector({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: ['체중', '활동량', '섭취량'].map((title) {
          final isSelected = viewModel.selectedDataType == title;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () => viewModel.setSelectedDataType(title),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor : kBackgroundColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: isSelected ? kPrimaryColor : kSecondaryColor),
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isSelected ? Colors.white : kOnSurfaceColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ComparisonModeSelector extends StatelessWidget {
  final HealthDetailViewModel viewModel;
  const ComparisonModeSelector({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SegmentedButton<ComparisonType>(
        segments: const [
          ButtonSegment(value: ComparisonType.previous, label: Text('선택된 기록'), icon: Icon(Icons.arrow_back)),
          ButtonSegment(value: ComparisonType.weekly, label: Text('주간 평균'), icon: Icon(Icons.calendar_view_week)),
          ButtonSegment(value: ComparisonType.monthly, label: Text('월간 평균'), icon: Icon(Icons.calendar_month)),
        ],
        selected: {viewModel.comparisonType},
        onSelectionChanged: (newSelection) {
          viewModel.setComparisonType(newSelection.first);
        },
        style: SegmentedButton.styleFrom(
            selectedBackgroundColor: kPrimaryColor.withOpacity(0.2),
            selectedForegroundColor: kPrimaryColor,
            textStyle: const TextStyle(fontSize: 12)
        ),
      ),
    );
  }
}

// ✅ [수정] 아래 HealthLineChart 위젯 전체를 복사하여 붙여넣으세요.

class HealthLineChart extends StatelessWidget {
  final HealthDetailViewModel viewModel;
  const HealthLineChart({super.key, required this.viewModel});

  String _formatValue(double value, String label) {
    switch (label) {
      case '체중':
      case '근육량':
      case '체지방':
        return '${value.toStringAsFixed(1)}kg';
      case '활동 시간':
        return '${value.toInt()}분';
      case '소모 칼로리':
        return '${value.toInt()}kcal';
      case '사료량':
        return '${value.toInt()}g';
      case '물':
        return '${value.toInt()}ml';
      default:
        return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final petProfile = viewModel.petProfile;
    final displayedDates = viewModel.displayedDates;
    List<LineChartBarData> lineBarsData = [];
    Map<String, Color> legendData = {};
    double maxY = 0;
    List<dynamic> recordsForChart = [];

    // --- 데이터 가공 로직 (기존과 동일) ---
    switch (viewModel.selectedDataType) {
      case '활동량':
        final typedRecords = petProfile.healthChart.activityDetails.where((r) => displayedDates.contains(r.date)).toList()..sort((a, b) => a.date.compareTo(b.date));
        recordsForChart = typedRecords;
        if (typedRecords.isNotEmpty) {
          final timeSpots = List.generate(typedRecords.length, (i) => FlSpot(i.toDouble(), typedRecords[i].time?.toDouble() ?? 0.0));
          final calSpots = List.generate(typedRecords.length, (i) => FlSpot(i.toDouble(), typedRecords[i].calories?.toDouble() ?? 0.0));
          final allValues = [...typedRecords.map((r) => r.time ?? 0), ...typedRecords.map((r) => r.calories ?? 0)];
          maxY = allValues.isNotEmpty ? allValues.reduce(max).toDouble() : 0;
          lineBarsData = [_buildLineChartBarData(timeSpots, kLineColor1), _buildLineChartBarData(calSpots, kLineColor2)];
          legendData = {'활동 시간': kLineColor1, '소모 칼로리': kLineColor2};
        }
        break;
      case '섭취량':
        final typedRecords = petProfile.healthChart.intakeDetails.where((r) => displayedDates.contains(r.date)).toList()..sort((a, b) => a.date.compareTo(b.date));
        recordsForChart = typedRecords;
        if (typedRecords.isNotEmpty) {
          final foodSpots = List.generate(typedRecords.length, (i) => FlSpot(i.toDouble(), typedRecords[i].food?.toDouble() ?? 0.0));
          final waterSpots = List.generate(typedRecords.length, (i) => FlSpot(i.toDouble(), typedRecords[i].water?.toDouble() ?? 0.0));
          final allValues = [...typedRecords.map((r) => r.food ?? 0), ...typedRecords.map((r) => r.water ?? 0)];
          maxY = allValues.isNotEmpty ? allValues.reduce(max).toDouble() : 0;
          lineBarsData = [_buildLineChartBarData(foodSpots, kLineColor1), _buildLineChartBarData(waterSpots, kLineColor2)];
          legendData = {'사료량': kLineColor1, '물': kLineColor2};
        }
        break;
      default: // 체중
        final typedRecords = petProfile.healthChart.weightDetails.where((r) => displayedDates.contains(r.date)).toList()..sort((a, b) => a.date.compareTo(b.date));
        recordsForChart = typedRecords;
        if (typedRecords.isNotEmpty) {
          final weightSpots = List.generate(typedRecords.length, (i) => FlSpot(i.toDouble(), typedRecords[i].bodyWeight ?? 0.0));
          final muscleSpots = List.generate(typedRecords.length, (i) => FlSpot(i.toDouble(), typedRecords[i].muscleMass ?? 0.0));
          final fatSpots = List.generate(typedRecords.length, (i) => FlSpot(i.toDouble(), typedRecords[i].bodyFatMass ?? 0.0));
          final allValues = [...typedRecords.map((r) => r.bodyWeight ?? 0.0), ...typedRecords.map((r) => r.muscleMass ?? 0.0), ...typedRecords.map((r) => r.bodyFatMass ?? 0.0)];
          maxY = allValues.isNotEmpty ? allValues.reduce(max) : 0;
          lineBarsData = [_buildLineChartBarData(weightSpots, kLineColor1), _buildLineChartBarData(muscleSpots, kLineColor2), _buildLineChartBarData(fatSpots, kLineColor3)];
          legendData = {'체중': kLineColor1, '근육량': kLineColor2, '체지방': kLineColor3};
        }
    }

    final double interval = (maxY / 5).clamp(1.0, 1000.0);
    if (maxY > 0) maxY = (maxY / interval).ceil() * interval; else maxY = interval * 5;

    final diaryDates = petProfile.diaries.map((d) => DateTime(d.date.year, d.date.month, d.date.day)).toSet();
    final List<int> diaryIndices = recordsForChart.asMap().entries.where((entry) {
      final recordDate = (entry.value as dynamic).date as DateTime;
      final recordDay = DateTime(recordDate.year, recordDate.month, recordDate.day);
      return diaryDates.contains(recordDay);
    }).map((entry) => entry.key).toList();

    final int selectedIndex = recordsForChart.indexWhere((r) => r.date == viewModel.selectedDate);

    if (lineBarsData.isNotEmpty) {
      lineBarsData = lineBarsData.map((barData) {
        return barData.copyWith(
          dotData: FlDotData(
            show: barData.spots.length < 20,
            getDotPainter: (spot, percent, barData, index) {
              if (diaryIndices.contains(index)) {
                return FlDotCirclePainter(radius: 7, color: kPrimaryColor.withOpacity(0.8), strokeWidth: 2, strokeColor: Colors.white);
              }
              return FlDotCirclePainter(radius: 3, color: barData.color ?? kPrimaryColor, strokeWidth: 0);
            },
          ),
        );
      }).toList();
    }

    return SizedBox(
      height: 300,
      child: lineBarsData.isEmpty
          ? Center(child: Text('표시할 ${viewModel.selectedDataType} 데이터가 없습니다.', style: const TextStyle(fontSize: 16, color: kOnSurfaceColor)))
          : Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 28.0, left: 16.0, top: 24, bottom: 12),
              child: LineChart(
                LineChartData(
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      if (selectedIndex != -1)
                        VerticalLine(x: selectedIndex.toDouble(), color: Colors.blueGrey.withOpacity(0.7), strokeWidth: 2, dashArray: [5, 5]),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((spotIndex) {
                        return TouchedSpotIndicatorData(
                          FlLine(color: Colors.transparent),
                          FlDotData(
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 8,
                              color: barData.color ?? kPrimaryColor,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    // HealthLineChart 위젯 내부

// ✅ [최종 수정] 아래 touchTooltipData 전체를 복사하여 붙여넣으세요.
                    // HealthLineChart 위젯 내부

// ✅ [최종 수정] 아래 touchTooltipData 전체를 복사하여 붙여넣으세요.
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.black.withOpacity(0.85),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        if (touchedSpots.isEmpty) {
                          return [];
                        }

                        // map 뒤에 <LineTooltipItem> 타입을 명시하여 타입 에러를 해결합니다.
                        return touchedSpots.asMap().entries.map<LineTooltipItem>((entry) {
                          final int index = entry.key;
                          final LineBarSpot spot = entry.value;

                          // 복잡한 TextSpan 대신, 하나의 문자열(String)으로 툴팁 내용을 만듭니다.
                          final record = recordsForChart[spot.spotIndex];
                          final dateText = index == 0
                              ? '${DateFormat('yy.MM.dd (E)', 'ko_KR').format(record.date)}\n'
                              : '';

                          final legendEntry = legendData.entries.elementAt(spot.barIndex);
                          final label = legendEntry.key;
                          final valueText = _formatValue(spot.y, label);

                          // 색상 표현은 불가능하므로 간단한 텍스트로 대체합니다.
                          final dataText = '● $label: $valueText';
                          final String fullText = '$dateText$dataText';

                          // 하나의 TextStyle만 사용합니다.
                          const TextStyle style = TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            height: 1.5,
                          );

                          // LineTooltipItem은 (String, TextStyle) 두 개의 인자만 가집니다.
                          return LineTooltipItem(fullText, style);

                        }).toList(); // 최종적으로 List<LineTooltipItem>을 반환합니다.
                      },
                    ),
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent && response?.lineBarSpots?.isNotEmpty == true) {
                        final spotIndex = response!.lineBarSpots![0].spotIndex;
                        if (spotIndex < recordsForChart.length) {
                          viewModel.setSelectedDate(recordsForChart[spotIndex].date);
                        }
                      }
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 30, interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= recordsForChart.length) return Container();
                          if (index == 0 || index == recordsForChart.length - 1 || (recordsForChart.length > 10 && index % (recordsForChart.length ~/ 5) == 0)) {
                            // ✅ [수정] SideTitleWidget에 'meta' 파라미터를 다시 추가합니다. (1.1.1 버전에서 필수)
                            return SideTitleWidget(
                              meta: meta,
                              space: 8.0,
                              child: Text(DateFormat('MM/dd').format(recordsForChart[index].date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            );
                          }
                          return Container();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 35, interval: interval,
                        getTitlesWidget: (value, meta) {
                          final style = const TextStyle(color: kOnSurfaceColor, fontWeight: FontWeight.bold, fontSize: 10);
                          if (value == meta.max) return Container();
                          // ✅ [수정] SideTitleWidget에 'meta' 파라미터를 다시 추가합니다. (1.1.1 버전에서 필수)
                          return SideTitleWidget(
                            meta: meta,
                            space: 10.0,
                            child: Text(value.toInt().toString(), style: style),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: interval, getDrawingHorizontalLine: (value) => FlLine(color: kSecondaryColor.withOpacity(0.7), strokeWidth: 1)),
                  minX: 0,
                  maxX: (recordsForChart.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: lineBarsData,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: legendData.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, color: entry.value),
                    const SizedBox(width: 4),
                    Text(entry.key, style: const TextStyle(fontSize: 12, color: kOnSurfaceColor)),
                  ],
                ),
              )).toList(),
            ),
          )
        ],
      ),
    );
  }
}

  LineChartBarData _buildLineChartBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: spots.length < 20),
      belowBarData: BarAreaData(show: false),
    );
  }


class DetailedComparisonSection extends StatelessWidget {
  final HealthDetailViewModel viewModel;
  const DetailedComparisonSection({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    dynamic currentRecord;
    List<dynamic> sortedRecords = [];

    switch (viewModel.selectedDataType) {
      case '체중': sortedRecords = viewModel.petProfile.healthChart.weightDetails..sort((a, b) => a.date.compareTo(b.date)); break;
      case '활동량': sortedRecords = viewModel.petProfile.healthChart.activityDetails..sort((a, b) => a.date.compareTo(b.date)); break;
      case '섭취량': sortedRecords = viewModel.petProfile.healthChart.intakeDetails..sort((a, b) => a.date.compareTo(b.date)); break;
    }

    final currentRecordIndex = sortedRecords.indexWhere((r) => r.date == viewModel.selectedDate);
    if (currentRecordIndex == -1) {
      return Container(padding: const EdgeInsets.all(16.0), alignment: Alignment.center, child: Text('선택된 시간의 ${viewModel.selectedDataType} 기록이 없습니다.'));
    }
    currentRecord = sortedRecords[currentRecordIndex];

    List<Widget> comparisonBars = [];
    if (currentRecord is WeightRecord) {
      comparisonBars = [
        _buildComparisonBar('체중', currentRecord.bodyWeight, 'kg', 15.0, sortedRecords, (r) => r.bodyWeight),
        _buildComparisonBar('근육량', currentRecord.muscleMass, 'kg', 10.0, sortedRecords, (r) => r.muscleMass),
        _buildComparisonBar('체지방', currentRecord.bodyFatMass, 'kg', 30.0, sortedRecords, (r) => r.bodyFatMass),
      ];
    } else if (currentRecord is ActivityRecord) {
      comparisonBars = [
        _buildComparisonBar('활동 시간', currentRecord.time, '분', 120.0, sortedRecords, (r) => r.time),
        _buildComparisonBar('소모 칼로리', currentRecord.calories, 'kcal', 500.0, sortedRecords, (r) => r.calories)
      ];
    } else if (currentRecord is IntakeRecord) {
      comparisonBars = [
        _buildComparisonBar('사료량', currentRecord.food, 'g', 500.0, sortedRecords, (r) => r.food),
        _buildComparisonBar('물', currentRecord.water, 'ml', 1000.0, sortedRecords, (r) => r.water)
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kSecondaryColor, width: 1)),
        child: Column(children: comparisonBars.isNotEmpty ? comparisonBars : [const Text('표시할 세부 데이터가 없습니다.')]),
      ),
    );
  }

  Widget _buildComparisonBar(String label, num? currentValue, String unit, double maxValue, List<dynamic> allSortedRecords, num? Function(dynamic) getValue) {
    if (currentValue == null) return Container();

    num? comparisonValue;
    String comparisonLabel = '(첫 기록)';
    final currentRecordIndex = allSortedRecords.indexWhere((r) => (r as dynamic).date == viewModel.selectedDate);

    switch (viewModel.comparisonType) {
      case ComparisonType.previous:
        if (currentRecordIndex > 0) comparisonValue = getValue(allSortedRecords[currentRecordIndex - 1]);
        comparisonLabel = '선택된 기록';
        break;
      case ComparisonType.weekly:
        final oneWeekAgo = viewModel.selectedDate.subtract(const Duration(days: 7));
        final weeklyRecords = allSortedRecords.where((r) => (r as dynamic).date.isAfter(oneWeekAgo) && (r as dynamic).date.isBefore(viewModel.selectedDate)).map(getValue).whereType<num>().toList();
        if (weeklyRecords.isNotEmpty) comparisonValue = weeklyRecords.reduce((a, b) => a + b) / weeklyRecords.length;
        comparisonLabel = '주간 평균';
        break;
      case ComparisonType.monthly:
        final oneMonthAgo = DateTime(viewModel.selectedDate.year, viewModel.selectedDate.month - 1, viewModel.selectedDate.day);
        final monthlyRecords = allSortedRecords.where((r) => (r as dynamic).date.isAfter(oneMonthAgo) && (r as dynamic).date.isBefore(viewModel.selectedDate)).map(getValue).whereType<num>().toList();
        if (monthlyRecords.isNotEmpty) comparisonValue = monthlyRecords.reduce((a, b) => a + b) / monthlyRecords.length;
        comparisonLabel = '월간 평균';
        break;
    }

    String changeText = comparisonValue == null ? '(비교 데이터 없음)' : '(-)';
    Color changeColor = Colors.grey;
    if (comparisonValue != null) {
      final double diff = currentValue.toDouble() - comparisonValue.toDouble();
      final bool isDouble = unit == 'kg';
      if (diff.abs() > (isDouble ? 0.01 : 0)) {
        changeText = '${diff > 0 ? '+' : ''}${isDouble ? diff.toStringAsFixed(1) : diff.toInt()}$unit';
        changeColor = diff > 0 ? Colors.red.shade400 : Colors.blue.shade400;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('${unit == 'kg' ? currentValue.toStringAsFixed(1) : currentValue.toInt()}$unit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(changeText, style: TextStyle(fontSize: 12, color: changeColor), textAlign: TextAlign.end),
              ),
            ])
          ]),
          const SizedBox(height: 4),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final barWidth = (currentValue.toDouble() / maxValue) * 100;
            return Stack(
              children: [
                Container(height: 8, decoration: BoxDecoration(color: kSecondaryColor, borderRadius: BorderRadius.circular(4))),
                Container(
                  height: 8,
                  width: constraints.maxWidth * (barWidth / 100).clamp(0, 1),
                  decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(4)),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}