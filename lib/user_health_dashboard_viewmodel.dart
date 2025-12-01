// lib/user_health_dashboard_viewmodel.dart (addNewDiary 타입 수정)

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // XFile 사용을 위해 필요

import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/api_config.dart';
import 'package:animal_project/user_diary_repository.dart';

// ======================================================================
// 상수 및 모델 클래스
// ======================================================================
const Color kLineColor1 = Color(0xFF547AA5);
const Color kLineColor2 = Color(0xFF6A994E);
const Color kLineColor3 = Color(0xFFE9C46A);

class StatisticalSummary {
  final String totalChange;
  final String average;
  final String maxRecord;
  final String minRecord;

  StatisticalSummary({
    this.totalChange = 'N/A',
    this.average = 'N/A',
    this.maxRecord = 'N/A',
    this.minRecord = 'N/A',
  });
}

class ChartDataCache {
  final List<LineChartBarData> lineBarsData;
  final double maxY;
  final Map<String, Color> legendData;

  ChartDataCache({
    required this.lineBarsData,
    required this.maxY,
    required this.legendData,
  });
}

// ======================================================================
// ViewModel (통합)
// ======================================================================

class HealthDashboardViewModel extends ChangeNotifier {
  final String token;
  String get _baseUrl => ApiConfig.baseUrl;

  late final DiaryRepository _diaryRepository;

  HealthDashboardViewModel({required this.token}) {
    _diaryRepository = DiaryRepository(token: token);
    fetchPetProfile();
  }

  // --- 1. 기본 상태 ---
  PetProfile? _petProfile;
  PetProfile? get petProfile => _petProfile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;
  void clearError() => _error = null;

  String _medicationMessage = '';
  String get medicationMessage => _medicationMessage;

  // --- 2. 화면 상태 ---
  TabController? tabController;
  double _tabViewHeight = 700.0;
  double get tabViewHeight => _tabViewHeight;

  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  String _selectedDataType = '체중';
  String get selectedDataType => _selectedDataType;

  DateTime? _filterStartDate;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? _filterEndDate;
  DateTime? get filterEndDate => _filterEndDate;

  final Set<String> _hiddenLegendItems = {};
  Set<String> get hiddenLegendItems => _hiddenLegendItems;

  Timer? _deleteTimer;
  dynamic _pendingDeleteRecord; // 단건 삭제 대기
  Map<String, dynamic>? _pendingDailyDeleteBackup; // 일괄 삭제 백업

  int _logPage = 1;
  final int _logPageSize = 15;
  bool _hasMoreLogs = false;
  bool get hasMoreLogs => _hasMoreLogs;

  bool _isSavingDiary = false;
  bool get isSavingDiary => _isSavingDiary;

  // --- 3. 캐시 데이터 ---
  List<DateTime> _masterTimeline = [];
  List<DateTime> get masterTimeline => _masterTimeline;

  List<dynamic> _fullUnifiedLogCache = [];
  List<dynamic> _unifiedLogItems = [];
  List<dynamic> get unifiedLogItems => _unifiedLogItems;

  Map<String, StatisticalSummary> _statsCache = {};
  Map<String, ChartDataCache> _chartCache = {};

  @override
  void dispose() {
    tabController?.dispose();
    _deleteTimer?.cancel();
    super.dispose();
  }

  void initTabController(TickerProvider vsync) {
    tabController = TabController(length: 4, vsync: vsync);
    tabController?.addListener(_handleTabSelection);
    _updateTabViewHeight();
  }

  Future<void> fetchPetProfile() async {
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
        _medicationMessage = data['user']['medicationMessage'] ?? '';
        _error = null;

        _updateAndCacheAllData();
      } else {
        _error = '데이터 로딩 실패 (코드: ${response.statusCode})';
      }
    } catch (e) {
      _error = '네트워크 오류: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateAndCacheAllData() {
    if (_petProfile == null) return;

    _masterTimeline = _calculateMasterTimeline();

    _logPage = 1;
    _fullUnifiedLogCache = _calculateFullUnifiedLog();
    _updatePaginatedLogs();

    _chartCache.clear();
    _chartCache['체중'] = _buildChartDataCache('체중');
    _chartCache['활동량'] = _buildChartDataCache('활동량');
    _chartCache['섭취량'] = _buildChartDataCache('섭취량');

    _statsCache.clear();
    _statsCache['체중'] = _calculateStatisticalSummary('체중');
    _statsCache['활동량'] = _calculateStatisticalSummary('활동량');
    _statsCache['섭취량'] = _calculateStatisticalSummary('섭취량');

    final allDates = allRecordDates;
    if (allDates.isNotEmpty) {
      if (_selectedDate == null || !allDates.contains(_selectedDate)) {
        _selectedDate = allDates.last;
      }
    } else {
      _selectedDate = DateTime.now();
    }
  }

  // --- 상태 변경 메서드 ---
  void _handleTabSelection() {
    if (tabController == null || !tabController!.indexIsChanging) return;
    _updateTabViewHeight();
    notifyListeners();
  }

  void _updateTabViewHeight() {
    if (tabController?.index == 0) {
      _tabViewHeight = 750.0;
    } else {
      _tabViewHeight = 250.0;
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
    _updateAndCacheAllData();
    notifyListeners();
  }

  void clearFilter() {
    _filterStartDate = null;
    _filterEndDate = null;
    _updateAndCacheAllData();
    notifyListeners();
  }

  void loadMoreLogs() {
    if (!_hasMoreLogs) return;
    _logPage++;
    _updatePaginatedLogs();
    notifyListeners();
  }

  void toggleLegendItem(String item) {
    if (_hiddenLegendItems.contains(item)) {
      _hiddenLegendItems.remove(item);
    } else {
      _hiddenLegendItems.add(item);
    }
    _updateAndCacheAllData();
    notifyListeners();
  }

  // --- 삭제 관련 로직 (단건 & 일괄) ---
  Future<bool> deleteRecord(String dataType, DateTime date) {
    _deleteTimer?.cancel();
    _pendingDeleteRecord = { 'type': dataType, 'date': date };
    _pendingDailyDeleteBackup = null;

    _removeRecordFromProfile(dataType, date);
    _updateAndCacheAllData();
    notifyListeners();

    _deleteTimer = Timer(const Duration(seconds: 4), () {
      _confirmDelete();
    });

    return Future.value(true);
  }

  // 🚀 [신규] 해당 날짜의 모든 기록 일괄 삭제
  Future<bool> deleteDailyRecords(DateTime date) async {
    _deleteTimer?.cancel();
    _pendingDeleteRecord = null;

    if (_petProfile == null) return false;

    final weightRecords = _petProfile!.healthChart.weightDetails.where((r) => r.date == date).toList();
    final activityRecords = _petProfile!.healthChart.activityDetails.where((r) => r.date == date).toList();
    final intakeRecords = _petProfile!.healthChart.intakeDetails.where((r) => r.date == date).toList();

    if (weightRecords.isEmpty && activityRecords.isEmpty && intakeRecords.isEmpty) return false;

    _pendingDailyDeleteBackup = {
      'date': date,
      'weight': weightRecords,
      'activity': activityRecords,
      'intake': intakeRecords,
    };

    _petProfile!.healthChart.weightDetails.removeWhere((r) => r.date == date);
    _petProfile!.healthChart.activityDetails.removeWhere((r) => r.date == date);
    _petProfile!.healthChart.intakeDetails.removeWhere((r) => r.date == date);

    _updateAndCacheAllData();
    notifyListeners();

    _deleteTimer = Timer(const Duration(seconds: 4), () {
      _confirmDailyDelete();
    });

    return true;
  }

  void undoDelete() {
    _deleteTimer?.cancel();
    _deleteTimer = null;

    if (_petProfile == null) return;

    if (_pendingDailyDeleteBackup != null) {
      final backup = _pendingDailyDeleteBackup!;
      _petProfile!.healthChart.weightDetails.addAll(backup['weight'] as List<WeightRecord>);
      _petProfile!.healthChart.activityDetails.addAll(backup['activity'] as List<ActivityRecord>);
      _petProfile!.healthChart.intakeDetails.addAll(backup['intake'] as List<IntakeRecord>);

      _petProfile!.healthChart.weightDetails.sort((a, b) => a.date.compareTo(b.date));
      _petProfile!.healthChart.activityDetails.sort((a, b) => a.date.compareTo(b.date));
      _petProfile!.healthChart.intakeDetails.sort((a, b) => a.date.compareTo(b.date));

      _pendingDailyDeleteBackup = null;
    } else if (_pendingDeleteRecord != null) {
      fetchPetProfile();
      _pendingDeleteRecord = null;
      return;
    }

    _updateAndCacheAllData();
    notifyListeners();
  }

  Future<void> _confirmDelete() async {
    if (_pendingDeleteRecord == null) return;
    final record = _pendingDeleteRecord;
    _pendingDeleteRecord = null;

    try {
      await http.delete(
        Uri.parse('$_baseUrl/users/health-record'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({
          'date': (record['date'] as DateTime).toUtc().toIso8601String(),
          'type': record['type']
        }),
      );
    } catch (e) {
      fetchPetProfile();
    }
  }

  Future<void> _confirmDailyDelete() async {
    if (_pendingDailyDeleteBackup == null) return;

    final date = _pendingDailyDeleteBackup!['date'] as DateTime;
    final hasWeight = (_pendingDailyDeleteBackup!['weight'] as List).isNotEmpty;
    final hasActivity = (_pendingDailyDeleteBackup!['activity'] as List).isNotEmpty;
    final hasIntake = (_pendingDailyDeleteBackup!['intake'] as List).isNotEmpty;

    _pendingDailyDeleteBackup = null;

    List<Future> deleteFutures = [];
    final dateStr = date.toUtc().toIso8601String();

    if (hasWeight) {
      deleteFutures.add(http.delete(
        Uri.parse('$_baseUrl/users/health-record'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'date': dateStr, 'type': '체중'}),
      ));
    }
    if (hasActivity) {
      deleteFutures.add(http.delete(
        Uri.parse('$_baseUrl/users/health-record'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'date': dateStr, 'type': '활동량'}),
      ));
    }
    if (hasIntake) {
      deleteFutures.add(http.delete(
        Uri.parse('$_baseUrl/users/health-record'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'date': dateStr, 'type': '섭취량'}),
      ));
    }

    try {
      await Future.wait(deleteFutures);
    } catch (e) {
      fetchPetProfile();
    }
  }

  void _removeRecordFromProfile(String dataType, DateTime date) {
    if (_petProfile == null) return;
    switch (dataType) {
      case '체중':
        _petProfile!.healthChart.weightDetails.removeWhere((r) => r.date == date);
        break;
      case '활동량':
        _petProfile!.healthChart.activityDetails.removeWhere((r) => r.date == date);
        break;
      case '섭취량':
        _petProfile!.healthChart.intakeDetails.removeWhere((r) => r.date == date);
        break;
    }
  }

  // ======================================================================
  // ✅ [복구 및 수정] 일기 관련 메서드 (다중 이미지 지원)
  // ======================================================================

  // ✅ [핵심] List<XFile>을 받도록 수정
  Future<bool> addNewDiary(String title, String content, DateTime date, List<XFile> imageFiles) async {
    _isSavingDiary = true;
    _error = null;
    notifyListeners();
    try {
      final newDiaryEntry = await _diaryRepository.addDiary(title, content, date, imageFiles);
      _petProfile?.diaries.add(newDiaryEntry);
      _updateAndCacheAllData();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSavingDiary = false;
      notifyListeners();
    }
  }

  Future<bool> updateExistingDiary(String id, String title, String content, DateTime date, XFile? newImageFile, bool imageRemoved) async {
    _isSavingDiary = true;
    _error = null;
    notifyListeners();
    try {
      final updatedDiaryEntry = await _diaryRepository.updateDiary(id, title, content, date, newImageFile, imageRemoved);
      final index = _petProfile?.diaries.indexWhere((d) => d.id == id) ?? -1;
      if (index != -1 && _petProfile != null) {
        _petProfile!.diaries[index] = updatedDiaryEntry;
      }
      _updateAndCacheAllData();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSavingDiary = false;
      notifyListeners();
    }
  }

  Future<bool> deleteExistingDiary(String id) async {
    _error = null;
    try {
      await _diaryRepository.deleteDiary(id);
      _petProfile?.diaries.removeWhere((d) => d.id == id);
      _updateAndCacheAllData();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ======================================================================
  // ✅ [복구] Getters (차트 및 날짜 관련)
  // ======================================================================

  List<DateTime> get allRecordDates {
    final allRecords = [
      ..._petProfile?.healthChart.weightDetails ?? [],
      ..._petProfile?.healthChart.activityDetails ?? [],
      ..._petProfile?.healthChart.intakeDetails ?? [],
    ];
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

  StatisticalSummary getStatisticalSummary(String dataType) {
    return _statsCache[dataType] ?? StatisticalSummary();
  }

  ChartDataCache getChartData(String dataType) {
    return _chartCache[dataType] ?? ChartDataCache(lineBarsData: [], maxY: 0, legendData: {});
  }

  // ✅ [복구] 일기 상세 화면에서 사용되는 메서드
  Map<String, String> getHealthRecordsForDate(DateTime date) {
    if (_petProfile == null) return {};

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final Map<String, String> records = {};

    final weightRecord = _petProfile!.healthChart.weightDetails.firstWhere(
          (r) => !r.date.isBefore(dayStart) && r.date.isBefore(dayEnd),
      orElse: () => WeightRecord(date: date),
    );
    if (weightRecord.bodyWeight != null) {
      records['체중'] = '${weightRecord.bodyWeight!.toStringAsFixed(1)}kg';
    }

    final activityRecord = _petProfile!.healthChart.activityDetails.firstWhere(
          (r) => !r.date.isBefore(dayStart) && r.date.isBefore(dayEnd),
      orElse: () => ActivityRecord(date: date),
    );
    if (activityRecord.time != null) {
      records['활동 시간'] = '${activityRecord.time}분';
    }

    final intakeRecord = _petProfile!.healthChart.intakeDetails.firstWhere(
          (r) => !r.date.isBefore(dayStart) && r.date.isBefore(dayEnd),
      orElse: () => IntakeRecord(date: date),
    );
    if (intakeRecord.food != null) {
      records['사료량'] = '${intakeRecord.food}g';
    }

    return records;
  }

  // ======================================================================
  // 캐시 계산 로직
  // ======================================================================

  List<DateTime> _calculateMasterTimeline() {
    if (_petProfile == null) return [];

    final Set<DateTime> allTimestamps = {};
    allTimestamps.addAll(_petProfile!.healthChart.weightDetails.map((r) => r.date));
    allTimestamps.addAll(_petProfile!.healthChart.activityDetails.map((r) => r.date));
    allTimestamps.addAll(_petProfile!.healthChart.intakeDetails.map((r) => r.date));
    allTimestamps.addAll(_petProfile!.diaries.map((r) => r.date));

    if (_filterStartDate != null && _filterEndDate != null) {
      final filteredStamps = allTimestamps.where((d) {
        final dateWithoutTime = DateTime(d.year, d.month, d.day);
        final startWithoutTime = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
        final endWithoutTime = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
        return !dateWithoutTime.isBefore(startWithoutTime) && !dateWithoutTime.isAfter(endWithoutTime);
      }).toList();
      return filteredStamps..sort((a, b) => a.compareTo(b));
    }

    return allTimestamps.toList()..sort((a, b) => a.compareTo(b));
  }

  List<dynamic> _calculateFullUnifiedLog() {
    if (_petProfile == null) return [];

    final timelineSet = _masterTimeline.toSet();
    List<dynamic> logItems = [];

    logItems.addAll(_petProfile!.healthChart.weightDetails.where((r) => timelineSet.contains(r.date)));
    logItems.addAll(_petProfile!.healthChart.activityDetails.where((r) => timelineSet.contains(r.date)));
    logItems.addAll(_petProfile!.healthChart.intakeDetails.where((r) => timelineSet.contains(r.date)));
    logItems.addAll(_petProfile!.diaries.where((r) => timelineSet.contains(r.date)));

    logItems.sort((a, b) => (b as dynamic).date.compareTo((a as dynamic).date));
    return logItems;
  }

  void _updatePaginatedLogs() {
    int endIndex = min(_logPage * _logPageSize, _fullUnifiedLogCache.length);
    _unifiedLogItems = _fullUnifiedLogCache.sublist(0, endIndex);
    _hasMoreLogs = _unifiedLogItems.length < _fullUnifiedLogCache.length;
  }

  StatisticalSummary _calculateStatisticalSummary(String dataType) {
    if (_petProfile == null || _masterTimeline.isEmpty) return StatisticalSummary();

    List<dynamic> records;
    num? Function(dynamic) getValue;
    String unit;
    bool isDouble;

    switch (dataType) {
      case '체중':
        records = _petProfile!.healthChart.weightDetails;
        getValue = (r) => (r as WeightRecord).bodyWeight;
        unit = 'kg'; isDouble = true;
        break;
      case '활동량':
        records = _petProfile!.healthChart.activityDetails;
        getValue = (r) => (r as ActivityRecord).time;
        unit = '분'; isDouble = false;
        break;
      case '섭취량':
        records = _petProfile!.healthChart.intakeDetails;
        getValue = (r) => (r as IntakeRecord).food;
        unit = 'g'; isDouble = false;
        break;
      default: return StatisticalSummary();
    }

    final timelineSet = _masterTimeline.toSet();
    final filteredRecords = records.where((r) => timelineSet.contains((r as dynamic).date)).toList()
      ..sort((a, b) => (a as dynamic).date.compareTo((b as dynamic).date));

    if (filteredRecords.isEmpty) return StatisticalSummary();
    final values = filteredRecords.map(getValue).whereType<num>().toList();
    if (values.isEmpty) return StatisticalSummary();

    String totalChange = 'N/A';
    final first = getValue(filteredRecords.first);
    final last = getValue(filteredRecords.last);
    if (first != null && last != null && filteredRecords.length > 1) {
      final change = last - first;
      totalChange = '${change > 0 ? '+' : ''}${isDouble ? change.toStringAsFixed(1) : change.toInt()}$unit';
    }

    final avg = values.reduce((a, b) => a + b) / values.length;
    final maxVal = values.reduce(max);
    final maxRecord = filteredRecords.firstWhere((r) => getValue(r) == maxVal);
    final minVal = values.reduce(min);
    final minRecord = filteredRecords.firstWhere((r) => getValue(r) == minVal);

    return StatisticalSummary(
      totalChange: totalChange,
      average: '${isDouble ? avg.toStringAsFixed(1) : avg.toInt()}$unit',
      maxRecord: '${isDouble ? maxVal.toStringAsFixed(1) : maxVal.toInt()}$unit (${DateFormat('MM/dd').format(maxRecord.date)})',
      minRecord: '${isDouble ? minVal.toStringAsFixed(1) : minVal.toInt()}$unit (${DateFormat('MM/dd').format(minRecord.date)})',
    );
  }

  ChartDataCache _buildChartDataCache(String dataType) {
    if (_petProfile == null || _masterTimeline.isEmpty) {
      return ChartDataCache(lineBarsData: [], maxY: 0, legendData: {});
    }

    List<dynamic> records;
    Map<String, (Color, num? Function(dynamic))> lineDataDefinitions;

    switch (dataType) {
      case '활동량':
        records = _petProfile!.healthChart.activityDetails;
        lineDataDefinitions = {
          '활동 시간': (kLineColor1, (r) => (r as ActivityRecord).time),
          '소모 칼로리': (kLineColor2, (r) => (r as ActivityRecord).calories),
        };
        break;
      case '섭취량':
        records = _petProfile!.healthChart.intakeDetails;
        lineDataDefinitions = {
          '사료량': (kLineColor1, (r) => (r as IntakeRecord).food),
          '물': (kLineColor2, (r) => (r as IntakeRecord).water),
        };
        break;
      default: // 체중
        records = _petProfile!.healthChart.weightDetails;
        lineDataDefinitions = {
          '체중': (kLineColor1, (r) => (r as WeightRecord).bodyWeight),
          '근육량': (kLineColor2, (r) => (r as WeightRecord).muscleMass),
          '체지방': (kLineColor3, (r) => (r as WeightRecord).bodyFatMass),
        };
    }

    double maxY = 0;
    List<LineChartBarData> lineBarsData = [];
    final Map<DateTime, dynamic> recordMap = { for (var r in records) (r as dynamic).date as DateTime: r };
    final Map<String, Color> legendData = {};

    for (var def in lineDataDefinitions.entries) {
      final label = def.key;
      final color = def.value.$1;
      final getValue = def.value.$2;

      legendData[label] = color;

      if (_hiddenLegendItems.contains(label)) {
        continue;
      }

      final List<FlSpot> spots = [];
      for (int i = 0; i < _masterTimeline.length; i++) {
        final date = _masterTimeline[i];
        if (recordMap.containsKey(date)) {
          final record = recordMap[date];
          final value = getValue(record);
          if (value != null) {
            spots.add(FlSpot(i.toDouble(), value.toDouble()));
            if (value > maxY) maxY = value.toDouble();
          }
        }
      }

      if(spots.isNotEmpty) {
        lineBarsData.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2,
          dotData: FlDotData(show: spots.length < 20),
          belowBarData: BarAreaData(show: false),
        ));
      }
    }

    final double interval = (maxY / 4).clamp(1.0, 1000.0);
    if (maxY > 0) {
      maxY = (maxY / interval).ceil() * interval;
      maxY = maxY * 1.2; // 20% 버퍼
    } else {
      maxY = interval * 4;
    }

    return ChartDataCache(
        lineBarsData: lineBarsData,
        maxY: maxY,
        legendData: legendData
    );
  }
}