// lib/user_health_detail_screen.dart (완전 복구 및 통합 버전)

import 'package:animal_project/user_add_health_record_dialog.dart' hide kPrimaryColor;
import 'package:animal_project/user_date_selection_screen.dart' hide kPrimaryColor;
import 'package:animal_project/widgets/draggable_ai_button.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';


import 'package:animal_project/models/user_ai_chat_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/user_diary_detail_screen.dart';
import 'package:animal_project/user_health_dashboard_viewmodel.dart';

// ======================================================================
// 상수 정의
// ======================================================================
const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);
const Color kLineColor1 = Color(0xFF547AA5);
const Color kLineColor2 = Color(0xFF6A994E);
const Color kLineColor3 = Color(0xFFE9C46A);

class HealthDetailScreen extends StatefulWidget {
  final HealthDashboardViewModel viewModel;
  final VoidCallback onShowUndoSnackbar;
  final AiChatViewModel aiChatViewModel;

  const HealthDetailScreen({
    super.key,
    required this.viewModel,
    required this.onShowUndoSnackbar,
    required this.aiChatViewModel, // 👈 필수 인자로 추가
  });

  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: widget.viewModel,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: _buildAppBar(context),
            body: widget.viewModel.isLoading
                ? _buildDetailSkeleton()
                : Stack( // 👈 Stack으로 감쌉니다.
              children: [
              SingleChildScrollView( // 👈 기존의 스크롤 가능한 본문
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DateNavigator(viewModel: widget.viewModel),
                  DataTypeSelector(viewModel: widget.viewModel),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: HealthLineChart(
                      key: ValueKey(
                          '${widget.viewModel.selectedDataType}-${widget.viewModel.hiddenLegendItems.length}-${widget.viewModel.filterStartDate}'),
                      viewModel: widget.viewModel,
                    ),
                  ),
                  _buildStatisticalSummary(),
                  _buildUnifiedDataLog(context),
                  const SizedBox(height: 20),
                  const SizedBox(height: 80), // 하단 버튼 공간 확보
                ],
              ),
            ),
                DraggableAiButton(
                  petProfile: widget.viewModel.petProfile,
                  token: widget.viewModel.token,
                  viewModel: widget.aiChatViewModel, // 👈 추가된 ViewModel을 전달합니다.
                ),
              ],
            ),
          );
        });
  }

  Widget _buildDetailSkeleton() {
    final skeletonColor = Colors.grey[200]!;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            height: 48,
            decoration: BoxDecoration(
                color: skeletonColor, borderRadius: BorderRadius.circular(8)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: List.generate(
                  3,
                      (index) => Expanded(
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  )),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            height: 300,
            decoration: BoxDecoration(
                color: skeletonColor, borderRadius: BorderRadius.circular(8)),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final canDelete = widget.viewModel.allRecordDates
        .any((d) => d == widget.viewModel.selectedDate);

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(widget.viewModel.petProfile?.name ?? '',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
              widget.viewModel.filterStartDate == null
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt,
              color: widget.viewModel.filterStartDate == null
                  ? Colors.black54
                  : kPrimaryColor),
          onPressed: () => _showFilterBottomSheet(context),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline,
              color: canDelete ? Colors.black54 : Colors.grey.shade300),
          onPressed: canDelete
              ? () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('기록 전체 삭제'),
                content: Text(
                    '${DateFormat('yy.MM.dd HH:mm').format(widget.viewModel.selectedDate!)}의\n모든 건강 기록(체중/활동/섭취)을\n삭제하시겠습니까?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('전체 삭제',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                ],
              ),
            );
            if (confirmed == true) {
              final success = await widget.viewModel.deleteDailyRecords(
                  widget.viewModel.selectedDate!);

              if (success && context.mounted) {
                widget.onShowUndoSnackbar();
              }
            }
          }
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.black54, size: 28),
          onPressed: () async {
            final result = await showDialog<bool>(
                context: context,
                builder: (_) => AddHealthRecordDialog(
                    token: widget.viewModel.token));
            if (result == true) widget.viewModel.fetchPetProfile();
          },
        ),
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Text('기간 설정',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                      label: const Text('최근 7일'),
                      onPressed: () {
                        final now = DateTime.now();
                        widget.viewModel.setFilterDates(
                            now.subtract(const Duration(days: 6)), now);
                        Navigator.pop(context);
                      }),
                  ActionChip(
                      label: const Text('최근 30일'),
                      onPressed: () {
                        final now = DateTime.now();
                        widget.viewModel.setFilterDates(
                            now.subtract(const Duration(days: 29)), now);
                        Navigator.pop(context);
                      }),
                  ActionChip(
                      label: const Text('올해'),
                      onPressed: () {
                        final now = DateTime.now();
                        widget.viewModel.setFilterDates(
                            DateTime(now.year, 1, 1), now);
                        Navigator.pop(context);
                      }),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(color: kSecondaryColor),
              const SizedBox(height: 15),
              TextButton(
                  child: const Text('기간 직접 선택'),
                  onPressed: () => _showCustomDateRangePicker(context)),
              TextButton(
                  child: const Text('전체 기간 보기 (필터 해제)'),
                  onPressed: () {
                    widget.viewModel.clearFilter();
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
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          title: const Text('기간 직접 선택',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 300,
            height: 350,
            child: SfDateRangePicker(
              selectionMode: DateRangePickerSelectionMode.range,
              backgroundColor: Colors.white,
              headerStyle: const DateRangePickerHeaderStyle(
                  backgroundColor: Colors.white,
                  textAlign: TextAlign.center,
                  textStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kOnSurfaceColor)),
              monthViewSettings: const DateRangePickerMonthViewSettings(
                  viewHeaderStyle: DateRangePickerViewHeaderStyle(
                      textStyle: TextStyle(fontSize: 12, color: Colors.grey))),
              selectionTextStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              rangeTextStyle: const TextStyle(color: kOnSurfaceColor),
              startRangeSelectionColor: kPrimaryColor,
              endRangeSelectionColor: kPrimaryColor,
              rangeSelectionColor: kPrimaryColor.withOpacity(0.2),
              todayHighlightColor: kPrimaryColor,
              initialSelectedRange:
              widget.viewModel.filterStartDate != null &&
                  widget.viewModel.filterEndDate != null
                  ? PickerDateRange(widget.viewModel.filterStartDate!,
                  widget.viewModel.filterEndDate!)
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
                    Navigator.pop(context,
                        DateTimeRange(start: startDate, end: endDate));
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
      widget.viewModel.setFilterDates(pickedRange.start, pickedRange.end);
    }
  }

  Widget _buildStatisticalSummary() {
    final stats =
    widget.viewModel.getStatisticalSummary(widget.viewModel.selectedDataType);
    if (stats.average == 'N/A') return Container();

    String summaryTitle = widget.viewModel.selectedDataType;
    if (widget.viewModel.selectedDataType == '활동량') summaryTitle = '활동 시간';
    if (widget.viewModel.selectedDataType == '섭취량') summaryTitle = '사료량';

    String title = '$summaryTitle 요약';
    if (widget.viewModel.filterStartDate != null) {
      title =
      '${DateFormat('MM/dd').format(widget.viewModel.filterStartDate!)} - ${DateFormat('MM/dd').format(widget.viewModel.filterEndDate!)} $title';
    } else {
      title = '전체 기간 $title';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kSecondaryColor, width: 1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kOnSurfaceColor)),
            const SizedBox(height: 12),
            _buildStatRow('총 변화량', stats.totalChange),
            _buildStatRow('평균', stats.average),
            _buildStatRow('최고', stats.maxRecord),
            _buildStatRow('최저', stats.minRecord),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kOnSurfaceColor)),
        ],
      ),
    );
  }

  Widget _buildUnifiedDataLog(BuildContext context) {
    final logItems = widget.viewModel.unifiedLogItems;
    if (logItems.isEmpty) return Container();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('통합 데이터 로그',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kOnSurfaceColor)),
          const SizedBox(height: 8),
          ListView.builder(
            itemCount: logItems.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final item = logItems[index];
              final date = (item as dynamic).date as DateTime;

              bool showDateHeader = true;
              if (index > 0) {
                final prevItem = logItems[index - 1];
                final prevDate = (prevItem as dynamic).date as DateTime;
                if (prevDate.year == date.year &&
                    prevDate.month == date.month &&
                    prevDate.day == date.day) {
                  showDateHeader = false;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: Text(
                          DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(date),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: kPrimaryColor)),
                    ),
                  _buildLogItem(context, item),
                ],
              );
            },
          ),
          if (widget.viewModel.hasMoreLogs)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: TextButton(
                  onPressed: widget.viewModel.loadMoreLogs,
                  child: const Text('이전 기록 더 보기',
                      style: TextStyle(
                          color: kPrimaryColor, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, dynamic item) {
    String time = DateFormat('HH:mm').format(item.date);
    String title = '';
    String content = '';
    Color color = Colors.grey;
    bool isDiary = false;
    String? targetDataType;

    if (item is DiaryEntry) {
      title = '[일기] ${item.title}';
      content = item.content;
      color = kPrimaryColor;
      isDiary = true;
    } else if (item is WeightRecord) {
      title = '[체중]';
      content =
      '체중: ${item.bodyWeight?.toStringAsFixed(1) ?? 'N/A'}kg, 근육량: ${item.muscleMass?.toStringAsFixed(1) ?? 'N/A'}kg, 체지방: ${item.bodyFatMass?.toStringAsFixed(1) ?? 'N/A'}kg';
      color = kLineColor1;
      targetDataType = '체중';
    } else if (item is ActivityRecord) {
      title = '[활동]';
      content =
      '활동 시간: ${item.time ?? 'N/A'}분, 소모 칼로리: ${item.calories ?? 'N/A'}kcal';
      color = kLineColor2;
      targetDataType = '활동량';
    } else if (item is IntakeRecord) {
      title = '[섭취]';
      content = '사료량: ${item.food ?? 'N/A'}g, 물: ${item.water ?? 'N/A'}ml';
      color = kLineColor3;
      targetDataType = '섭취량';
    }

    return InkWell(
      onTap: () {
        if (isDiary) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DiaryDetailScreen(
                      diaryEntry: item, viewModel: widget.viewModel)));
        } else if (targetDataType != null) {
          widget.viewModel.setSelectedDataType(targetDataType!);
          widget.viewModel.setSelectedDate(item.date);
          _scrollToTop();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kSecondaryColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(width: 12),
            Container(
                width: 4,
                height: 16,
                color: color,
                margin: const EdgeInsets.only(top: 2)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        content,
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (isDiary)
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// ✅ [복구] 누락되었던 헬퍼 클래스들
// ======================================================================

class DateNavigator extends StatelessWidget {
  final HealthDashboardViewModel viewModel;
  const DateNavigator({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final dates = viewModel.displayedDates;
    if (dates.isEmpty || viewModel.selectedDate == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
            child: Text("표시할 기록이 없습니다.",
                style: TextStyle(fontSize: 16, color: Colors.grey))),
      );
    }

    final currentIndex = dates.indexOf(viewModel.selectedDate!);
    final canGoPrevious = currentIndex > 0;
    final canGoNext = currentIndex != -1 && currentIndex < dates.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: canGoPrevious
                ? () => viewModel.setSelectedDate(dates[currentIndex - 1])
                : null,
            icon: Icon(Icons.arrow_back_ios,
                size: 18,
                color:
                canGoPrevious ? Colors.black : Colors.grey.shade300),
          ),
          InkWell(
            onTap: () async {
              final pickedDate = await Navigator.push<DateTime>(
                context,
                MaterialPageRoute(
                    builder: (_) => DateSelectionScreen(
                        allDates: dates, initialDate: viewModel.selectedDate!)),
              );
              if (pickedDate != null) viewModel.setSelectedDate(pickedDate);
            },
            child: Text(
              DateFormat('yy.MM.dd (E) HH:mm', 'ko_KR')
                  .format(viewModel.selectedDate!),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: canGoNext
                ? () => viewModel.setSelectedDate(dates[currentIndex + 1])
                : null,
            icon: Icon(Icons.arrow_forward_ios,
                size: 18,
                color: canGoNext ? Colors.black : Colors.grey.shade300),
          ),
        ],
      ),
    );
  }
}

class DataTypeSelector extends StatelessWidget {
  final HealthDashboardViewModel viewModel;
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
                    border: Border.all(
                        color: isSelected ? kPrimaryColor : kSecondaryColor),
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isSelected ? Colors.white : kOnSurfaceColor,
                        fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal),
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

class HealthLineChart extends StatelessWidget {
  final HealthDashboardViewModel viewModel;
  const HealthLineChart({super.key, required this.viewModel});

  String _formatValue(double value, String label) {
    if (label == '체중' || label == '근육량' || label == '체지방') {
      return '${value.toStringAsFixed(1)}kg';
    } else if (label == '활동 시간') {
      return '${value.toInt()}분';
    } else if (label == '소모 칼로리') {
      return '${value.toInt()}kcal';
    } else if (label == '사료량') {
      return '${value.toInt()}g';
    } else if (label == '물') {
      return '${value.toInt()}ml';
    } else {
      return value.toStringAsFixed(1);
    }
  }

  Widget _buildTappableLegend(Map<String, Color> legendData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: legendData.entries.map((entry) {
        final label = entry.key;
        final color = entry.value;
        final isHidden = viewModel.hiddenLegendItems.contains(label);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: InkWell(
            onTap: () {
              viewModel.toggleLegendItem(label);
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    color: isHidden ? Colors.grey[300] : color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isHidden ? Colors.grey[400] : kOnSurfaceColor,
                      decoration: isHidden
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (viewModel.petProfile == null) {
      return Container(height: 300);
    }

    final petProfile = viewModel.petProfile!;
    final dataType = viewModel.selectedDataType;

    List<dynamic> records;
    Map<String, (Color, num? Function(dynamic))> lineDataDefinitions;

    switch (dataType) {
      case '활동량':
        records = petProfile.healthChart.activityDetails;
        lineDataDefinitions = {
          '활동 시간': (kLineColor1, (r) => (r as ActivityRecord).time),
          '소모 칼로리': (kLineColor2, (r) => (r as ActivityRecord).calories),
        };
        break;
      case '섭취량':
        records = petProfile.healthChart.intakeDetails;
        lineDataDefinitions = {
          '사료량': (kLineColor1, (r) => (r as IntakeRecord).food),
          '물': (kLineColor2, (r) => (r as IntakeRecord).water),
        };
        break;
      default:
        records = petProfile.healthChart.weightDetails;
        lineDataDefinitions = {
          '체중': (kLineColor1, (r) => (r as WeightRecord).bodyWeight),
          '근육량': (kLineColor2, (r) => (r as WeightRecord).muscleMass),
          '체지방': (kLineColor3, (r) => (r as WeightRecord).bodyFatMass),
        };
    }

    List<DateTime> localTimeline =
    records.map((r) => (r as dynamic).date as DateTime).toList();

    if (viewModel.filterStartDate != null && viewModel.filterEndDate != null) {
      localTimeline = localTimeline.where((d) {
        final dateWithoutTime = DateTime(d.year, d.month, d.day);
        final startWithoutTime = DateTime(viewModel.filterStartDate!.year,
            viewModel.filterStartDate!.month, viewModel.filterStartDate!.day);
        final endWithoutTime = DateTime(viewModel.filterEndDate!.year,
            viewModel.filterEndDate!.month, viewModel.filterEndDate!.day);
        return !dateWithoutTime.isBefore(startWithoutTime) &&
            !dateWithoutTime.isAfter(endWithoutTime);
      }).toList();
    }

    localTimeline.sort((a, b) => a.compareTo(b));

    double maxY = 0;
    List<LineChartBarData> lineBarsData = [];
    final Map<DateTime, dynamic> recordMap = {
      for (var r in records) (r as dynamic).date as DateTime: r
    };
    final Map<String, Color> legendData = {};

    for (var def in lineDataDefinitions.entries) {
      final label = def.key;
      final color = def.value.$1;
      final getValue = def.value.$2;

      legendData[label] = color;

      if (viewModel.hiddenLegendItems.contains(label)) {
        continue;
      }

      final List<FlSpot> spots = [];
      for (int i = 0; i < localTimeline.length; i++) {
        final date = localTimeline[i];
        if (recordMap.containsKey(date)) {
          final record = recordMap[date];
          final value = getValue(record);
          if (value != null) {
            spots.add(FlSpot(i.toDouble(), value.toDouble()));
            if (value > maxY) maxY = value.toDouble();
          }
        }
      }

      if (spots.isNotEmpty) {
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

    final double interval = (maxY / 4.8).clamp(1.0, 1000.0);
    if (maxY > 0) {
      maxY = (maxY / interval).ceil() * interval;
      maxY = maxY * 1.2;
    } else {
      maxY = interval * 4;
    }

    if (localTimeline.isEmpty ||
        (lineBarsData.isEmpty &&
            legendData.keys.any(
                    (key) => !viewModel.hiddenLegendItems.contains(key)))) {
      return Container(
          height: 300,
          child: Center(
              child: Text('표시할 ${viewModel.selectedDataType} 데이터가 없습니다.',
                  style: const TextStyle(
                      fontSize: 16, color: kOnSurfaceColor))));
    }

    final int selectedIndex = viewModel.selectedDate != null
        ? localTimeline.indexWhere((d) => d == viewModel.selectedDate)
        : -1;

    return SizedBox(
      height: 300,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  right: 28.0, left: 16.0, top: 24, bottom: 12),
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      if (selectedIndex != -1)
                        VerticalLine(
                            x: selectedIndex.toDouble(),
                            color: Colors.blueGrey.withOpacity(0.7),
                            strokeWidth: 2,
                            dashArray: [5, 5]),
                    ],
                  ),
                  minX: -0.5,
                  maxX: (localTimeline.length - 1) + 0.5,
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: lineBarsData,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: interval,
                      getDrawingHorizontalLine: (value) => FlLine(
                          color: kSecondaryColor.withOpacity(0.7),
                          strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max) return Container();
                              return SideTitleWidget(
                                space: 4.0,
                                meta: meta,
                                child: Text(value.toInt().toString(),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 10),
                                    textAlign: TextAlign.left),
                              );
                            })),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (value != value.toInt().toDouble()) {
                                return Container();
                              }
                              final index = value.toInt();
                              if (index < 0 || index >= localTimeline.length)
                                return Container();

                              if (index == 0 ||
                                  index == localTimeline.length - 1 ||
                                  (localTimeline.length > 10 &&
                                      index % (localTimeline.length ~/ 5) ==
                                          0)) {
                                return SideTitleWidget(
                                  space: 8.0,
                                  meta: meta,
                                  child: Text(
                                      DateFormat('MM/dd')
                                          .format(localTimeline[index]),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                );
                              }
                              return Container();
                            })),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((spotIndex) {
                        return TouchedSpotIndicatorData(
                          FlLine(color: Colors.transparent),
                          FlDotData(
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 8,
                                  color: barData.color ?? kPrimaryColor,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                          ),
                        );
                      }).toList();
                    },
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => Colors.black.withOpacity(0.8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final LineBarSpot spot = entry.value;

                          final int timelineIndex = spot.x.toInt();
                          if (timelineIndex < 0 ||
                              timelineIndex >= localTimeline.length) {
                            return LineTooltipItem("", const TextStyle());
                          }
                          final date = localTimeline[timelineIndex];

                          final spotColor = spot.bar.color;
                          String label = 'N/A';
                          for (var legEntry in legendData.entries) {
                            if (legEntry.value == spotColor) {
                              label = legEntry.key;
                              break;
                            }
                          }

                          final valueText = _formatValue(spot.y, label);

                          final String dateHeader = index == 0
                              ? '${DateFormat('MM/dd (E)', 'ko_KR').format(date)}\n'
                              : '';

                          return LineTooltipItem(
                            dateHeader,
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            children: [
                              TextSpan(
                                text: '$label: $valueText',
                                style: TextStyle(
                                    color: spot.bar.color,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12),
                              ),
                            ],
                            textAlign: TextAlign.left,
                          );
                        }).toList();
                      },
                    ),
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent &&
                          response?.lineBarSpots?.isNotEmpty == true) {
                        final spotIndex = response!.lineBarSpots![0].spotIndex;
                        if (spotIndex < localTimeline.length) {
                          viewModel.setSelectedDate(localTimeline[spotIndex]);
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: _buildTappableLegend(legendData),
          )
        ],
      ),
    );
  }
}