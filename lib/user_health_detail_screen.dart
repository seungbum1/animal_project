// user_health_detail_screen.dart (수정 완료)

import 'package:animal_project/user_add_health_record_dialog.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;


import 'package:syncfusion_flutter_datepicker/datepicker.dart';
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

  void _updateAndSetInitialDate() {
    final allDatesWithDuplicates = [
      ..._currentPetProfile.healthChart.weightDetails.map((r) => r.date),
      ..._currentPetProfile.healthChart.activityDetails.map((r) => r.date),
      ..._currentPetProfile.healthChart.intakeDetails.map((r) => r.date),
    ];
    _allRecordDates = allDatesWithDuplicates.toSet().toList();
    _allRecordDates.sort();

    if (_allRecordDates.isNotEmpty) {
      _selectedDate = _allRecordDates.last;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // 날짜를 적용하고 시트를 닫는 헬퍼 함수
        void applyFilterAndClose(DateTime start, DateTime end) {
          setState(() {
            _filterStartDate = start;
            _filterEndDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
          });
          Navigator.pop(context);
        }

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 핸들
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '기간 설정',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // 빠른 선택 버튼들
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _buildFilterChip('최근 7일', () {
                    final now = DateTime.now();
                    applyFilterAndClose(now.subtract(const Duration(days: 6)), now);
                  }),
                  _buildFilterChip('최근 30일', () {
                    final now = DateTime.now();
                    applyFilterAndClose(now.subtract(const Duration(days: 29)), now);
                  }),
                  _buildFilterChip('올해', () {
                    final now = DateTime.now();
                    applyFilterAndClose(DateTime(now.year, 1, 1), now);
                  }),
                ],
              ),
              const SizedBox(height: 15),
              // 구분선
              const Divider(color: kSecondaryColor),
              const SizedBox(height: 15),
              // 직접 선택 및 필터 해제 버튼
              _buildTextButton('기간 직접 선택', _showCustomDateRangePicker),
              _buildTextButton('전체 기간 보기 (필터 해제)', () {
                _clearFilter();
                Navigator.pop(context);
              }),
            ],
          ),
        );
      },
    );
  }

  // 바텀시트 내부 버튼 UI를 만드는 헬퍼 위젯
  Widget _buildFilterChip(String label, VoidCallback onPressed) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: kBackgroundColor,
      labelStyle: const TextStyle(color: kOnSurfaceColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: kSecondaryColor),
      ),
    );
  }

  Widget _buildTextButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
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
            final oldSelectedDate = _selectedDate;
            _currentPetProfile = PetProfile.fromJson(user['petProfile'] ?? {});

            final allDatesWithDuplicates = [
              ..._currentPetProfile.healthChart.weightDetails.map((r) => r.date),
              ..._currentPetProfile.healthChart.activityDetails.map((r) => r.date),
              ..._currentPetProfile.healthChart.intakeDetails.map((r) => r.date),
            ];
            _allRecordDates = allDatesWithDuplicates.toSet().toList();
            _allRecordDates.sort();

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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('데이터를 불러오는데 실패했습니다.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== ⬇️ 기능 추가 ⬇️ ====================

  /// 날짜 범위 필터 선택 함수
  Future<void> _showCustomDateRangePicker() async {
    // 바텀 시트가 열려있으면 닫아줍니다.
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    DateTimeRange? pickedRange = await showDialog<DateTimeRange>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(16),
          // AlertDialog의 기본 타이틀 대신 직접 UI를 구성합니다.
          title: const Text('기간 직접 선택', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 300,
            height: 350,
            child: SfDateRangePicker(
              // --- UI 스타일링 ---
              selectionMode: DateRangePickerSelectionMode.range,
              backgroundColor: Colors.white,
              headerStyle: const DateRangePickerHeaderStyle(
                textAlign: TextAlign.center,
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kOnSurfaceColor),
              ),
              monthViewSettings: const DateRangePickerMonthViewSettings(
                viewHeaderStyle: DateRangePickerViewHeaderStyle(
                  textStyle: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              selectionTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              rangeTextStyle: const TextStyle(color: kOnSurfaceColor),
              startRangeSelectionColor: kPrimaryColor,
              endRangeSelectionColor: kPrimaryColor,
              rangeSelectionColor: kPrimaryColor.withOpacity(0.2),
              todayHighlightColor: kPrimaryColor,

              // --- 기능 ---
              initialSelectedRange: _filterStartDate != null && _filterEndDate != null
                  ? PickerDateRange(_filterStartDate!, _filterEndDate!)
                  : null,
              maxDate: DateTime.now().add(const Duration(days: 365)),
              showActionButtons: true,
              cancelText: '취소',
              confirmText: '확인',
              onSubmit: (Object? value) {
                if (value is PickerDateRange) {
                  final startDate = value.startDate;
                  final endDate = value.endDate ?? value.startDate; // 종료일이 없으면 시작일과 동일하게 처리
                  if (startDate != null && endDate != null) {
                    Navigator.pop(context, DateTimeRange(start: startDate, end: endDate));
                  }
                }
              },
              onCancel: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _filterStartDate = pickedRange.start;
        _filterEndDate = DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day, 23, 59, 59);
      });
    }
  }

  /// 필터 초기화 함수
  void _clearFilter() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  /// 현재 선택된 날짜의 기록을 삭제하는 함수
  Future<void> _deleteRecord() async {
    final korDataType = _selectedDataType;
    final engDataType = {
      '체중': 'weight',
      '활동량': 'activity',
      '섭취량': 'intake'
    }[korDataType];

    if (engDataType == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 전체 삭제'),
        content: Text('${DateFormat('yy.MM.dd HH:mm').format(_selectedDate)}의 $korDataType 기록을 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/health-record'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'date': _selectedDate.toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('해당 날짜의 모든 기록이 삭제되었습니다.')));
        }
        await _refreshData();
      } else {
        String errorMessage = '삭제에 실패했습니다. (오류 코드: ${response.statusCode})';
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          try {
            final errorBody = json.decode(utf8.decode(response.bodyBytes));
            errorMessage = '삭제 실패: ${errorBody['message'] ?? '알 수 없는 서버 오류입니다.'}';
          } catch (e) {
            errorMessage = '서버 응답을 처리하는 중 오류가 발생했습니다.';
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('네트워크 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // ==========================================================

  void _goToPreviousDay(List<DateTime> displayedDates) {
    final currentIndex = displayedDates.indexOf(_selectedDate);
    if (currentIndex > 0) {
      setState(() {
        _selectedDate = displayedDates[currentIndex - 1];
      });
    }
  }

  void _goToNextDay(List<DateTime> displayedDates) {
    final currentIndex = displayedDates.indexOf(_selectedDate);
    if (currentIndex != -1 && currentIndex < displayedDates.length - 1) {
      setState(() {
        _selectedDate = displayedDates[currentIndex + 1];
      });
    }
  }

  void _selectDate(List<DateTime> displayedDates) async {
    final DateTime? pickedDate = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DateSelectionScreen(
          allDates: displayedDates.toSet().toList(),
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

    List<ChartDataPoint> originalDataPoints;
    dynamic originalDetailedRecords;
    switch (_selectedDataType) {
      case '활동량':
        originalDataPoints = petProfile.healthChart.activity;
        originalDetailedRecords = petProfile.healthChart.activityDetails;
        break;
      case '섭취량':
        originalDataPoints = petProfile.healthChart.intake;
        originalDetailedRecords = petProfile.healthChart.intakeDetails;
        break;
      case '체중':
      default:
        originalDataPoints = petProfile.healthChart.weight;
        originalDetailedRecords = petProfile.healthChart.weightDetails;
        break;
    }

    // ✅ [수정됨] 필터링 로직 적용
    final List<ChartDataPoint> filteredDataPoints;
    final dynamic filteredDetailedRecords;
    final List<DateTime> displayedDates;

    if (_filterStartDate != null && _filterEndDate != null) {
      filteredDataPoints = originalDataPoints.where((p) {
        return p.date.isAfter(_filterStartDate!) && p.date.isBefore(_filterEndDate!);
      }).toList();
      filteredDetailedRecords = (originalDetailedRecords as List).where((r) {
        return r.date.isAfter(_filterStartDate!) && r.date.isBefore(_filterEndDate!);
      }).toList();
      displayedDates = _allRecordDates.where((d) {
        return d.isAfter(_filterStartDate!) && d.isBefore(_filterEndDate!);
      }).toList();
    } else {
      filteredDataPoints = originalDataPoints;
      filteredDetailedRecords = originalDetailedRecords;
      displayedDates = _allRecordDates;
    }


    final List<ChartDataPoint> currentDataPoints = List.from(filteredDataPoints);
    currentDataPoints.sort((a, b) => a.date.compareTo(b.date));

    if (filteredDetailedRecords is List) {
      filteredDetailedRecords.sort((a,b) => a.date.compareTo(b.date));
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

    final currentIndex = displayedDates.indexOf(_selectedDate);
    final canGoPrevious = currentIndex > 0;
    final canGoNext = currentIndex != -1 && currentIndex < displayedDates.length - 1;

    // ✅ [수정됨] 삭제 버튼 활성화 조건
    final bool canDelete = (filteredDetailedRecords as List).any((r) => r.date == _selectedDate);

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
          // ✅ [수정됨] 필터 버튼 추가
          IconButton(
            icon: Icon(
              _filterStartDate == null ? Icons.filter_alt_outlined : Icons.filter_alt,
              color: _filterStartDate == null ? Colors.black54 : kPrimaryColor,
            ),
            onPressed: _showFilterBottomSheet,
          ),
          // ✅ [추가됨] 필터 초기화 버튼
          if (_filterStartDate != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined, color: Colors.black54),
              onPressed: _clearFilter,
            ),
          // ✅ [수정됨] 삭제 버튼 추가
          IconButton(
            icon: Icon(Icons.delete_outline, color: canDelete ? Colors.black54 : Colors.grey.shade300),
            onPressed: canDelete ? _deleteRecord : null,
          ),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      onPressed: canGoPrevious ? () => _goToPreviousDay(displayedDates) : null,
                      icon: Icon(
                        Icons.arrow_back_ios,
                        size: 18,
                        color: canGoPrevious ? Colors.black : Colors.grey.shade300,
                      )),
                  InkWell(
                    onTap: () => _selectDate(displayedDates),
                    child: Text(
                      displayedDates.isNotEmpty
                          ? DateFormat('yy.MM.dd (E) HH:mm', 'ko_KR')
                          .format(_selectedDate)
                          : '기록 없음',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                      onPressed: canGoNext ? () => _goToNextDay(displayedDates) : null,
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
                      handleBuiltInTouches: true,
                      touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                        if (event is FlTapUpEvent) {
                          if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
                            return;
                          }
                          final spotIndex = response.lineBarSpots![0].spotIndex;
                          if (spotIndex < currentDataPoints.length) {
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
                                  if (filteredDetailedRecords is! List<WeightRecord> || filteredDetailedRecords.length <= touchedIndex) return null;

                                  final List<WeightRecord> sortedDetails = filteredDetailedRecords;
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
                                  if (filteredDetailedRecords is! List<ActivityRecord> || filteredDetailedRecords.length <= touchedIndex) return null;

                                  final List<ActivityRecord> sortedDetails = filteredDetailedRecords;
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
                                  if (filteredDetailedRecords is! List<IntakeRecord> || filteredDetailedRecords.length <= touchedIndex) return null;

                                  final List<IntakeRecord> sortedDetails = filteredDetailedRecords;
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
                                child: Text(dateLabels[index], style: const TextStyle(color: Colors.grey, fontSize: 16)),
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
              detailedRecords: filteredDetailedRecords,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedComparisonSection({required dynamic detailedRecords}) {
    // detailedRecords는 이미 List 타입임이 보장됩니다.
    final currentRecordIndex = (detailedRecords as List).indexWhere(
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
          _buildComparisonBar('체지방', record.bodyFatMass, prev?.bodyFatMass, 'kg', 30),
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