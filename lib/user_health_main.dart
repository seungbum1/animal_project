// lib/user_health_main.dart (교수님 피드백 완벽 반영 및 섹션 분리 버전)

import 'package:animal_project/user_diary_add_screen.dart';
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
import 'package:animal_project/widgets/draggable_ai_button.dart';
import 'package:animal_project/models/user_ai_chat_viewmodel.dart';

import 'user_mainscreen.dart';
import 'user_myhospital_list.dart';

const Color kPrimaryColor = Color(0xFFC06362);
const Color kBackgroundColor = Color(0xFFFFFBE6);
const Color kOnSurfaceColor = Color(0xFF333333);
const Color kSecondaryColor = Color(0xFFE0E0E0);
const Color kWeightLineColor = Color(0xFF547AA5);
const Color kActivityLineColor = Color(0xFF6A994E);
const Color kIntakeLineColor = Color(0xFFE9C46A);


class HealthDashboardScreen extends StatefulWidget {
  final String? token;
  final bool showBottomNav;
  const HealthDashboardScreen({super.key, this.token, this.showBottomNav = true});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> with SingleTickerProviderStateMixin {
  late final HealthDashboardViewModel _viewModel;
  late final AiChatViewModel _aiChatViewModel;

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
    _viewModel.initTabController(this);

    _aiChatViewModel = AiChatViewModel(
      token: widget.token ?? '',
      petProfile: _viewModel.petProfile,
    );
    _viewModel.addListener(_handlePetProfileUpdate);
  }

  void _handlePetProfileUpdate() {
    _aiChatViewModel.updatePetProfile(_viewModel.petProfile);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handlePetProfileUpdate);
    _viewModel.dispose();
    _aiChatViewModel.dispose();
    super.dispose();
  }

  void _showAddRecordDialog({
    DateTime? targetDate,
    Map<String, dynamic>? initialWeight,
    Map<String, dynamic>? initialActivity,
    Map<String, dynamic>? initialIntake,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AddHealthRecordDialog(
          token: widget.token ?? '',
          initialDate: targetDate,
          initialWeight: initialWeight,
          initialActivity: initialActivity,
          initialIntake: initialIntake,
        );
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
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0, // ✅ 이 줄을 추가하세요! (스크롤 시 색상 변경 방지)
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
      return _buildMainSkeleton();
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

    return Stack(
      children: [
        SingleChildScrollView(
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
                viewModel: _viewModel,
                onAddRecordPressed: () => _showAddRecordDialog(),
                onRecordAdded: _viewModel.fetchPetProfile,
                onShowUndoSnackbar: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('기록이 삭제되었습니다.'),
                      action: SnackBarAction(
                        label: '실행 취소',
                        onPressed: () {
                          _viewModel.undoDelete();
                        },
                      ),
                    ),
                  );
                },
                aiChatViewModel: _aiChatViewModel,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionCard(context, petProfile, icon: Icons.article_outlined, label: '일기', iconBackgroundColor: kSecondaryColor.withOpacity(0.5)),
                    _buildActionCard(context, petProfile, icon: Icons.local_pharmacy_outlined, label: '복용 알람 설정', iconBackgroundColor: const Color(0xFFC06362).withOpacity(0.2)),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        DraggableAiButton(
          petProfile: petProfile,
          token: widget.token ?? '',
          viewModel: _aiChatViewModel,
        ),
      ],
    );
  }

  Widget _buildMainSkeleton() {
    final skeletonColor = Colors.grey[200]!;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.all(16.0),
            height: 20, width: 250,
            decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(4)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            height: 700,
            decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(8)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, PetProfile petProfile,
      {required IconData icon, required String label, required Color iconBackgroundColor}) {
    return InkWell(
      onTap: () {
        if (label == '일기') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => HealthDiaryScreen(viewModel: _viewModel)));
        } else if (label == '복용 알람 설정') {
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

  void _showDailySummarySheet(BuildContext context, DateTime date) {
    final petProfile = _viewModel.petProfile!;
    final weightRecords = petProfile.healthChart.weightDetails.where((r) => isSameDay(r.date, date)).toList();
    final activityRecords = petProfile.healthChart.activityDetails.where((r) => isSameDay(r.date, date)).toList();
    final intakeRecords = petProfile.healthChart.intakeDetails.where((r) => isSameDay(r.date, date)).toList();
    final diaryEntry = petProfile.diaries.where((d) => isSameDay(d.date, date)).firstOrNull;

    final bool hasAnyHealthRecord = weightRecords.isNotEmpty || activityRecords.isNotEmpty || intakeRecords.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('M월 d일 (E)', 'ko_KR').format(date),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: kBackgroundColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickActionButton(
                        context,
                        icon: Icons.add_circle_outline,
                        label: '기록 추가',
                        onTap: () {
                          Navigator.pop(context);
                          _showAddRecordDialog(targetDate: date);
                        },
                      ),
                      _buildQuickActionButton(
                        context,
                        icon: Icons.book,
                        label: '일기 쓰기',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryAddScreen(viewModel: _viewModel, initialDate: date)));
                        },
                      ),
                      _buildQuickActionButton(
                        context,
                        icon: Icons.alarm_add,
                        label: '알람 설정',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => MedicationAlarmListScreen(initialAlarms: petProfile.alarms, token: widget.token ?? '')))
                              .then((_) => _viewModel.fetchPetProfile());
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('기록 요약', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    if (hasAnyHealthRecord)
                      SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            List<DateTime> allTimes = [];
                            if (weightRecords.isNotEmpty) allTimes.add(weightRecords.last.date);
                            if (activityRecords.isNotEmpty) allTimes.add(activityRecords.last.date);
                            if (intakeRecords.isNotEmpty) allTimes.add(intakeRecords.last.date);
                            allTimes.sort();
                            final DateTime targetTime = allTimes.isNotEmpty ? allTimes.last : date;

                            final lastWeight = weightRecords.isNotEmpty ? weightRecords.last : null;
                            final lastActivity = activityRecords.isNotEmpty ? activityRecords.last : null;
                            final lastIntake = intakeRecords.isNotEmpty ? intakeRecords.last : null;

                            _showAddRecordDialog(
                              targetDate: targetTime,
                              initialWeight: lastWeight != null ? {'bodyWeight': lastWeight.bodyWeight, 'muscleMass': lastWeight.muscleMass, 'bodyFatMass': lastWeight.bodyFatMass} : null,
                              initialActivity: lastActivity != null ? {'time': lastActivity.time, 'calories': lastActivity.calories} : null,
                              initialIntake: lastIntake != null ? {'food': lastIntake.food, 'water': lastIntake.water} : null,
                            );
                          },
                          icon: const Icon(Icons.edit, size: 14, color: Colors.black87),
                          label: const Text('전체 수정', style: TextStyle(fontSize: 12, color: Colors.black87)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (!hasAnyHealthRecord && diaryEntry == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('이 날짜에 기록된 데이터가 없습니다.\n\'기록 추가\' 버튼을 눌러보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                  ),

                ...weightRecords.map((r) => _buildSimpleSummaryRow('체중', '${r.bodyWeight?.toStringAsFixed(1) ?? 'N/A'}kg')),
                ...activityRecords.map((r) => _buildSimpleSummaryRow('활동', '${r.time ?? 'N/A'}분')),
                ...intakeRecords.map((r) => _buildSimpleSummaryRow('사료', '${r.food ?? 'N/A'}g')),

                if (diaryEntry != null)
                  _buildTappableSummaryRow(context, '일기', diaryEntry.title, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryDetailScreen(diaryEntry: diaryEntry, viewModel: _viewModel)));
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: kSecondaryColor),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, color: kPrimaryColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
        ],
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildSimpleSummaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
        ],
      ),
    );
  }

  Widget _buildTappableSummaryRow(BuildContext context, String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
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
}

// ======================================================================
// HealthChartDashboard: 섹션 분리 및 UI 구조 재정의 (교수님 피드백 반영)
// ======================================================================
class HealthChartDashboard extends StatefulWidget {
  final HealthDashboardViewModel viewModel;
  final VoidCallback onAddRecordPressed;
  final VoidCallback onRecordAdded;
  final VoidCallback onShowUndoSnackbar;
  final AiChatViewModel aiChatViewModel;

  const HealthChartDashboard({
    super.key,
    required this.viewModel,
    required this.onAddRecordPressed,
    required this.onRecordAdded,
    required this.onShowUndoSnackbar,
    required this.aiChatViewModel,
  });

  @override
  State<HealthChartDashboard> createState() => _HealthChartDashboardState();
}

class _HealthChartDashboardState extends State<HealthChartDashboard> {
  bool _isListView = false;

  // 텍스트 기반 토글 버튼 (하단 섹션 전용)
  Widget _buildViewModeToggle() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(label: '달력', isSelected: !_isListView, onTap: () => setState(() => _isListView = false)),
          Container(width: 1, height: 16, color: Colors.grey[300]), // 구분선
          _buildToggleButton(label: '리스트', isSelected: _isListView, onTap: () => setState(() => _isListView = true)),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[500],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = widget.viewModel.masterTimeline.isEmpty;

    if (isEmpty) return _buildEmptyState(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ========================================================
        // 1️⃣ [섹션 1] 차트형 건강 기록 (헤더 + 상세 분석 버튼)
        // ========================================================
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart, size: 20, color: kOnSurfaceColor),
                  SizedBox(width: 8),
                  Text('차트형 건강 기록', // ✨ 교수님 요청: 명확한 명시
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
                ],
              ),
              // ✨ "상세 분석" 버튼을 차트 제목 옆으로 이동 (차트의 상세라는 문맥 부여)
              InkWell(
                onTap: () async {
                  await Navigator.push<bool>(context, MaterialPageRoute(
                      builder: (context) => HealthDetailScreen(
                        viewModel: widget.viewModel,
                        onShowUndoSnackbar: widget.onShowUndoSnackbar,
                        aiChatViewModel: widget.aiChatViewModel,
                      )
                  ));
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Text('상세 분석', // '자세히 보기' -> '상세 분석' (목적 명확화)
                          style: TextStyle(fontSize: 12, color: kPrimaryColor, fontWeight: FontWeight.bold)),
                      Icon(Icons.keyboard_arrow_right, size: 16, color: kPrimaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 차트 본문
        TabbableHealthChart(viewModel: widget.viewModel),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(height: 40, thickness: 1, color: kSecondaryColor),
        ),

        // ========================================================
        // 2️⃣ [섹션 2] 캘린더형 건강 기록 (헤더 + 뷰 모드 토글)
        // ========================================================
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 20, color: kOnSurfaceColor),
                  SizedBox(width: 8),
                  Text('캘린더형 건강 기록', // ✨ 교수님 요청: 명확한 명시
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
                ],
              ),
              // ✨ 뷰 모드 토글 (달력/리스트)을 여기로 배치하여 달력 섹션 컨트롤임을 명시
              _buildViewModeToggle(),
            ],
          ),
        ),

        // 캘린더 or 리스트 본문
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isListView
              ? RecordedHistoryList(
            key: const ValueKey('list'),
            viewModel: widget.viewModel,
            onDateSelected: (date) {
              final state = context.findAncestorStateOfType<_HealthDashboardScreenState>();
              state?._showDailySummarySheet(context, date);
            },
          )
              : ActivityCalendar(
            key: const ValueKey('calendar'),
            weightDetails: widget.viewModel.petProfile!.healthChart.weightDetails,
            activityDetails: widget.viewModel.petProfile!.healthChart.activityDetails,
            intakeDetails: widget.viewModel.petProfile!.healthChart.intakeDetails,
            diaries: widget.viewModel.petProfile!.diaries,
            onDateSelected: (date) {
              final state = context.findAncestorStateOfType<_HealthDashboardScreenState>();
              state?._showDailySummarySheet(context, date);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: InkWell(
        onTap: widget.onAddRecordPressed,
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

// ======================================================================
// RecordedHistoryList: 건강기록 + 일기 포함 모아보기
// ======================================================================
class RecordedHistoryList extends StatelessWidget {
  final HealthDashboardViewModel viewModel;
  final Function(DateTime) onDateSelected;

  const RecordedHistoryList({
    super.key,
    required this.viewModel,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final Set<DateTime> dateSet = {};

    for(var r in viewModel.petProfile!.healthChart.weightDetails) dateSet.add(DateTime(r.date.year, r.date.month, r.date.day));
    for(var r in viewModel.petProfile!.healthChart.activityDetails) dateSet.add(DateTime(r.date.year, r.date.month, r.date.day));
    for(var r in viewModel.petProfile!.healthChart.intakeDetails) dateSet.add(DateTime(r.date.year, r.date.month, r.date.day));
    for(var d in viewModel.petProfile!.diaries) {
      dateSet.add(DateTime(d.date.year, d.date.month, d.date.day));
    }

    final allDates = dateSet.toList()..sort((a, b) => b.compareTo(a));

    if (allDates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30.0),
        child: Center(child: Text('아직 기록된 날짜가 없습니다.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: allDates.length,
        itemBuilder: (context, index) {
          final date = allDates[index];

          final hasWeight = viewModel.petProfile!.healthChart.weightDetails.any((r) => isSameDay(r.date, date));
          final hasActivity = viewModel.petProfile!.healthChart.activityDetails.any((r) => isSameDay(r.date, date));
          final hasIntake = viewModel.petProfile!.healthChart.intakeDetails.any((r) => isSameDay(r.date, date));
          final hasDiary = viewModel.petProfile!.diaries.any((r) => isSameDay(r.date, date));

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () => onDateSelected(date),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kSecondaryColor.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: kBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(DateFormat('dd').format(date),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                          Text(DateFormat('E', 'ko_KR').format(date),
                              style: const TextStyle(fontSize: 12, color: kOnSurfaceColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('yyyy년 M월').format(date),
                              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (hasWeight) _buildMiniIcon(Icons.monitor_weight_outlined, kWeightLineColor),
                              if (hasActivity) _buildMiniIcon(Icons.directions_run, kActivityLineColor),
                              if (hasIntake) _buildMiniIcon(Icons.restaurant_menu, kIntakeLineColor),
                              if (hasDiary) _buildMiniIcon(Icons.book, kPrimaryColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniIcon(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: Icon(icon, size: 18, color: color),
    );
  }

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

// ======================================================================
// TabbableHealthChart (기존 유지)
// ======================================================================
class TabbableHealthChart extends StatelessWidget {
  final HealthDashboardViewModel viewModel;
  const TabbableHealthChart({super.key, required this.viewModel});

  static const Color kLineColor1 = Color(0xFF547AA5);
  static const Color kLineColor2 = Color(0xFF6A994E);
  static const Color kLineColor3 = Color(0xFFE9C46A);

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

  @override
  Widget build(BuildContext context) {
    if (viewModel.tabController == null) return Container(height: 700);

    return Column(
      children: [
        TabBar(
          controller: viewModel.tabController,
          labelColor: kPrimaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimaryColor,
          indicatorSize: TabBarIndicatorSize.label,
          isScrollable: false,
          tabs: const [
            Tab(text: '전체 보기'),
            Tab(text: '체중(kg)'),
            Tab(text: '활동량(분)'),
            Tab(text: '섭취량(g)'),
          ],
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: viewModel.tabViewHeight,
          child: TabBarView(
            controller: viewModel.tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSmallMultiplesView(),
              Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildSmallChart(dataType: '체중')),
              Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildSmallChart(dataType: '활동량')),
              Padding(padding: const EdgeInsets.only(top: 16.0), child: _buildSmallChart(dataType: '섭취량')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallMultiplesView() {
    if (viewModel.masterTimeline.isEmpty) {
      return Container(
          height: 250,
          child: Center(child: Text('표시할 데이터가 없습니다.', style: TextStyle(color: Colors.grey[600])))
      );
    }
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      children: [
        _buildSmallChart(dataType: '체중'),
        _buildSmallChart(dataType: '활동량'),
        _buildSmallChart(dataType: '섭취량'),
      ],
    );
  }

  Widget _buildTappableLegend(Map<String, Color> legendData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: legendData.entries.map((entry) {
        final label = entry.key;
        final color = entry.value;
        final isHidden = viewModel.hiddenLegendItems.contains(label);

        return Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: InkWell(
            onTap: () {
              viewModel.toggleLegendItem(label);
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  Container(width: 10, height: 10, color: isHidden ? Colors.grey[300] : color),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 11, color: isHidden ? Colors.grey[400] : kOnSurfaceColor, decoration: isHidden ? TextDecoration.lineThrough : TextDecoration.none)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSmallChart({ required String dataType }) {
    if (viewModel.petProfile == null) return Container(height: 220);

    final petProfile = viewModel.petProfile!;
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

    List<DateTime> localTimeline = records.map((r) => (r as dynamic).date as DateTime).toList();
    if (viewModel.filterStartDate != null && viewModel.filterEndDate != null) {
      localTimeline = localTimeline.where((d) {
        final dateWithoutTime = DateTime(d.year, d.month, d.day);
        final startWithoutTime = DateTime(viewModel.filterStartDate!.year, viewModel.filterStartDate!.month, viewModel.filterStartDate!.day);
        final endWithoutTime = DateTime(viewModel.filterEndDate!.year, viewModel.filterEndDate!.month, viewModel.filterEndDate!.day);
        return !dateWithoutTime.isBefore(startWithoutTime) && !dateWithoutTime.isAfter(endWithoutTime);
      }).toList();
    }
    localTimeline.sort((a, b) => a.compareTo(b));

    double maxY = 0;
    List<LineChartBarData> lineBarsData = [];
    final Map<DateTime, dynamic> recordMap = { for (var r in records) (r as dynamic).date as DateTime: r };
    final Map<String, Color> legendData = {};

    for (var def in lineDataDefinitions.entries) {
      final label = def.key;
      final color = def.value.$1;
      final getValue = def.value.$2;
      legendData[label] = color;

      if (viewModel.hiddenLegendItems.contains(label)) continue;

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
      if(spots.isNotEmpty) {
        lineBarsData.add(LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 2, dotData: FlDotData(show: spots.length < 20), belowBarData: BarAreaData(show: false)));
      }
    }

    final double interval = (maxY / 4.8).clamp(1.0, 1000.0);
    if (maxY > 0) {
      maxY = (maxY / interval).ceil() * interval;
      maxY = maxY * 1.2;
    } else {
      maxY = interval * 4;
    }

    if (localTimeline.isEmpty || (lineBarsData.isEmpty && legendData.keys.any((key) => !viewModel.hiddenLegendItems.contains(key)))) {
      return Container(
          height: 220,
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dataType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kOnSurfaceColor)), _buildTappableLegend(legendData)]),
              Expanded(child: Center(child: Text("표시할 데이터가 없습니다.", style: TextStyle(color: Colors.grey[600])))),
            ],
          )
      );
    }

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dataType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kOnSurfaceColor)), _buildTappableLegend(legendData)]),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  minX: -0.5, maxX: (localTimeline.length - 1) + 0.5, minY: 0, maxY: maxY,
                  lineBarsData: lineBarsData, borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: interval, getDrawingHorizontalLine: (value) => FlLine(color: kSecondaryColor.withOpacity(0.7), strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: interval, getTitlesWidget: (value, meta) {
                      if (value == meta.max) return Container();
                      return SideTitleWidget(space: 4.0, meta: meta, child: Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.left));
                    })),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (value, meta) {
                      if (value != value.toInt().toDouble()) return Container();
                      final index = value.toInt();
                      if (index < 0 || index >= localTimeline.length) return Container();
                      if (index == 0 || index == localTimeline.length - 1 || (localTimeline.length > 10 && index % (localTimeline.length ~/ 5) == 0)) {
                        return SideTitleWidget(space: 8.0, meta: meta, child: Text(DateFormat('MM/dd').format(localTimeline[index]), style: const TextStyle(color: Colors.grey, fontSize: 12)));
                      }
                      return Container();
                    })),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true, fitInsideVertically: true,
                      getTooltipColor: (_) => Colors.black.withOpacity(0.8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final LineBarSpot spot = entry.value;
                          final int timelineIndex = spot.x.toInt();
                          if (timelineIndex < 0 || timelineIndex >= localTimeline.length) return LineTooltipItem("", const TextStyle());
                          final date = localTimeline[timelineIndex];
                          final spotColor = spot.bar.color;
                          String label = 'N/A';
                          for (var legEntry in legendData.entries) {
                            if (legEntry.value == spotColor) {
                              label = legEntry.key;
                              break;
                            }
                          }
                          String valueText = _formatValue(spot.y, label);
                          final String dateHeader = index == 0 ? '${DateFormat('MM/dd (E)', 'ko_KR').format(date)}\n' : '';
                          return LineTooltipItem(dateHeader, const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), children: [TextSpan(text: '$label: $valueText', style: TextStyle(color: spot.bar.color, fontWeight: FontWeight.normal, fontSize: 12))]);
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ======================================================================
// ActivityCalendar (목표 텍스트 수정 버전)
// ======================================================================
class ActivityCalendar extends StatefulWidget {
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
  late DateTime _displayDate;

  // ✨ [추가] 한국 시간(KST) 구하는 헬퍼 함수
  // 기기 설정과 무관하게 무조건 한국 시간을 반환합니다.
  DateTime get _nowKst {
    return DateTime.now().toUtc().add(const Duration(hours: 9));
  }

  @override
  void initState() {
    super.initState();
    // 초기 화면도 한국 시간 기준의 '이번 달'로 설정
    _displayDate = _nowKst;
  }

  int _calculateStreak(Set<DateTime> recordDays) {
    if (recordDays.isEmpty) return 0;
    int streak = 0;

    // ✨ [수정] 오늘 날짜도 KST 기준으로 계산
    DateTime today = _nowKst;
    DateTime currentDate = DateTime(today.year, today.month, today.day);

    // 만약 오늘 기록이 없다면 어제부터 스트릭 확인 (오늘 기록 안 했다고 스트릭이 끊기진 않게 처리하는 로직)
    if (!recordTypesByDay.containsKey(currentDate)) {
      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    while (recordTypesByDay.containsKey(currentDate)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  final Map<DateTime, Set<String>> recordTypesByDay = {};

  // ... (didChangeDependencies, _updateRecordTypesByDay, _changeMonth, _pickYearMonth 기존과 동일) ...
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateRecordTypesByDay();
  }

  void _updateRecordTypesByDay() {
    recordTypesByDay.clear();
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
  }

  void _changeMonth(int month) {
    setState(() {
      _displayDate = DateTime(_displayDate.year, _displayDate.month + month, 1);
    });
  }

  Future<void> _pickYearMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _displayDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
      helpText: '연도와 월을 선택하세요',
    );
    if (picked != null) {
      setState(() {
        _displayDate = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateRecordTypesByDay();

    // ✨ [수정] 여기서도 KST 기준 '오늘'을 가져옵니다.
    final today = _nowKst;

    final startOfDisplayMonth = DateTime(_displayDate.year, _displayDate.month, 1);
    final int daysToSubtract = startOfDisplayMonth.weekday == 7 ? 0 : startOfDisplayMonth.weekday;
    final calendarStartDate = startOfDisplayMonth.subtract(Duration(days: daysToSubtract));

    final streak = _calculateStreak(recordTypesByDay.keys.toSet());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeeklyGoalCard(recordTypesByDay),

        const SizedBox(height: 20),

        // 캘린더 컨트롤 (월 이동)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: () => _changeMonth(-1)),

            InkWell(
              onTap: _pickYearMonth,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      DateFormat('yyyy년 M월', 'ko_KR').format(_displayDate),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kOnSurfaceColor),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: kPrimaryColor),
                  ],
                ),
              ),
            ),

            Row(
              children: [
                if (_displayDate.month != today.month || _displayDate.year != today.year)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _displayDate = _nowKst; // ✨ '오늘' 버튼 눌렀을 때도 KST로 이동
                      });
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 30)),
                    child: const Text('오늘', style: TextStyle(fontSize: 12, color: kPrimaryColor)),
                  ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: _displayDate.year == today.year && _displayDate.month == today.month ? null : () => _changeMonth(1),
                ),
              ],
            ),
          ],
        ),

        if (streak > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: Center(child: Text('🔥 $streak일 연속 기록 중!', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold))),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['일', '월', '화', '수', '목', '금', '토']
              .map((day) => Text(day, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)))
              .toList(),
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

            // ✨ [수정] 오늘 날짜 하이라이트 비교 로직 (KST 기준)
            final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

            Color color = hasRecord ? kPrimaryColor.withOpacity(0.3) : kSecondaryColor.withOpacity(0.5);
            if (hasRecord && types.length > 1) color = kPrimaryColor.withOpacity(min(0.3 + types.length * 0.1, 1.0));

            Color textColor = isCurrentMonth ? kOnSurfaceColor : Colors.grey.withOpacity(0.6);
            if(date.weekday == 7) textColor = isCurrentMonth ? Colors.red.shade700 : Colors.red.withOpacity(0.6);
            if(date.weekday == 6) textColor = isCurrentMonth ? Colors.blue.shade700 : Colors.blue.withOpacity(0.6);

            return GestureDetector(
              onTap: () => widget.onDateSelected(date),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: isToday ? Border.all(color: kPrimaryColor, width: 2) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: hasRecord ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (hasRecord) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (types.contains('weight')) _buildDot(kWeightLineColor),
                          if (types.contains('activity')) _buildDot(kActivityLineColor),
                          if (types.contains('intake')) _buildDot(kIntakeLineColor),
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
    // ✨ [수정] 여기도 KST 기준으로 변경해야 정확한 목표 계산 가능
    final today = _nowKst;

    final int daysToSubtract = today.weekday == 7 ? 0 : today.weekday;
    final startOfWeek = DateTime(today.year, today.month, today.day).subtract(Duration(days: daysToSubtract));

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBackgroundColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSecondaryColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('이번 주 기록 목표', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
              isGoalAchieved
                  ? const Text('목표 달성! 🏆', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPrimaryColor))
                  : Text('$currentWeekRecordDays / ${widget.weeklyGoal} 일', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kOnSurfaceColor)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          const Text('꾸준한 기록이 건강 관리의 시작입니다!', style: TextStyle(fontSize: 11, color: Colors.grey)),
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