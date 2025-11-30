// lib/user_date_selection_screen.dart.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color kPrimaryColor = Color(0xFFC06362);

class DateSelectionScreen extends StatelessWidget {
  final List<DateTime> allDates;
  final DateTime initialDate;

  const DateSelectionScreen({
    super.key,
    required this.allDates,
    required this.initialDate,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 기록을 최신순으로 정렬 (이미 정렬되어 넘어오지만 확인 차원)
    final sortedDates = List<DateTime>.from(allDates)..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '기록 선택', // ✅ 타이틀 변경
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          // ✅ 선택된 기록을 정확한 시간까지 비교하도록 수정
          final bool isSelected = date == initialDate;

          return ListTile(
            title: Text(
              // ✅ 날짜 포맷에 'HH:mm' (시간:분)을 추가하여 모든 기록 표시
              DateFormat('yyyy년 M월 d일 (E) HH:mm', 'ko_KR').format(date),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? kPrimaryColor : Colors.black,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: kPrimaryColor)
                : null,
            onTap: () {
              Navigator.of(context).pop(date);
            },
          );
        },
      ),
    );
  }
}