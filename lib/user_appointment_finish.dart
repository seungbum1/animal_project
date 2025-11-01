// user_appointment_finish.dart.
import 'package:flutter/material.dart';
import 'user_myhospital_mainscreen.dart';
import 'api_config.dart';

class UserAppointmentFinishScreen extends StatelessWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;

  /// 요약 정보
  final String petName;       // 다롱이 같은 반려동물 이름
  final String service;       // 예: 일반진료
  final String doctorName;    // 예: 김철수 원장
  final DateTime date;        // 방문 날짜 (연-월-일)
  final String time;          // 방문 시간 (HH:mm)

  const UserAppointmentFinishScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
    required this.petName,
    required this.service,
    required this.doctorName,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8);
    final pet = petName.isNotEmpty ? petName : '반려동물';

    return WillPopScope(
      // 뒤로가기 눌러도 동일하게 메인으로 이동
      onWillPop: () async {
        _goToMyHospital(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: topYellow,
          elevation: 0,
          centerTitle: true,
          title: const Text('진료 예약 완료',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
          iconTheme: const IconThemeData(color: Colors.black87),
          leading: const SizedBox.shrink(), // 상단 뒤로가기 제거(완료화면)
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '$pet님(의) 진료 예약 신청이\n정상적으로 처리되었습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              const _DividerBar(),

              _TitleRow('진료 항목'),
              _BulletLine(service),
              const _DividerBar(),

              _TitleRow('진료의'),
              _BulletLine(doctorName),
              const _DividerBar(),

              _TitleRow('방문 날짜'),
              _BulletLine(_fmtKDate(date)),
              const _DividerBar(),

              _TitleRow('방문 시간'),
              _BulletLine(time),
              const _DividerBar(),

              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 120,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _goToMyHospital(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAEAEA),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text('닫기'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToMyHospital(BuildContext context) {
    // 스택을 정리하고 "내 병원" 메인으로 이동
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => UserMyHospitalMainScreen(
          token: token,
          hospitalId: hospitalId,
          hospitalName: hospitalName,
        ),
      ),
          (route) => false,
    );
  }

  static String _fmtKDate(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일';
}

class _TitleRow extends StatelessWidget {
  final String t;
  const _TitleRow(this.t);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.circle, size: 10, color: Colors.black87),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DividerBar extends StatelessWidget {
  const _DividerBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      margin: const EdgeInsets.symmetric(vertical: 14),
      color: const Color(0xFFFFF4B8),
    );
  }
}
