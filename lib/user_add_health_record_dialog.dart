import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

const Color kPrimaryColor = Color(0xFFC06362);
const Color kOnSurfaceColor = Color(0xFF333333);

class AddHealthRecordDialog extends StatefulWidget {
  final String token; // API 호출을 위해 token을 전달받음
  const AddHealthRecordDialog({super.key, required this.token});

  @override
  State<AddHealthRecordDialog> createState() => _AddHealthRecordDialogState();
}

class _AddHealthRecordDialogState extends State<AddHealthRecordDialog> {
  // 컨트롤러들
  final _bodyWeightController = TextEditingController(); // 몸무게 (필수)
  final _muscleMassController = TextEditingController();
  final _bodyFatMassController = TextEditingController();
  final _activityTimeController = TextEditingController(); // 활동 시간 (필수)
  final _caloriesBurnedController = TextEditingController();
  final _foodAmountController = TextEditingController(); // 사료양 (필수)
  final _waterAmountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  String get _baseUrl =>
      Platform.isAndroid ? 'http://10.0.2.2:4000' : 'http://localhost:4000';

  @override
  void dispose() {
    _bodyWeightController.dispose();
    _muscleMassController.dispose();
    _bodyFatMassController.dispose();
    _activityTimeController.dispose();
    _caloriesBurnedController.dispose();
    _foodAmountController.dispose();
    _waterAmountController.dispose();
    super.dispose();
  }

  // ✅ '저장' 버튼을 눌렀을 때 실행될 함수
  Future<void> _saveRecord() async {
    // 필수 항목 검사
    if (_bodyWeightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목(*)인 몸무게를 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 서버로 보낼 데이터 구조 만들기
      final body = {
        'date': _selectedDate.toIso8601String(),
        'weight': {
          'bodyWeight': double.tryParse(_bodyWeightController.text),
          'muscleMass': double.tryParse(_muscleMassController.text),
          'bodyFatMass': double.tryParse(_bodyFatMassController.text),
        },
        'activity': {
          'time': int.tryParse(_activityTimeController.text),
          'calories': int.tryParse(_caloriesBurnedController.text),
        },
        'intake': {
          'food': int.tryParse(_foodAmountController.text),
          'water': int.tryParse(_waterAmountController.text),
        }
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/users/me/health-record'), // ✅ API 주소
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}', // ✅ 인증 토큰
        },
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('건강 기록이 저장되었습니다.')),
        );
        // ✅ 성공 시, true 값을 반환하며 모달을 닫습니다.
        Navigator.of(context).pop(true);
      } else {
        final errorBody = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${errorBody['message'] ?? response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- 나머지 UI 코드들은 이전 답변과 거의 동일합니다 ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required String unit, bool isRequired = false}) {
    return TextFormField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(label: RichText(text: TextSpan(text: label, style: const TextStyle(color: kOnSurfaceColor), children: isRequired ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [])), suffixText: unit, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)));
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(top: 20.0, bottom: 12.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('건강 기록 추가', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${_selectedDate.year}.${_selectedDate.month}.${_selectedDate.day}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), TextButton(onPressed: () => _selectDate(context), child: const Text('날짜 변경'))]),
              const Divider(),
              _buildSectionTitle('체중'),
              _buildInputField(controller: _bodyWeightController, label: '몸무게', unit: 'kg', isRequired: true),
              const SizedBox(height: 12),
              _buildInputField(controller: _muscleMassController, label: '근육량', unit: 'kg'),
              const SizedBox(height: 12),
              _buildInputField(controller: _bodyFatMassController, label: '체지방량', unit: '%'),
              _buildSectionTitle('활동량'),
              _buildInputField(controller: _activityTimeController, label: '활동 시간', unit: '분'),
              const SizedBox(height: 12),
              _buildInputField(controller: _caloriesBurnedController, label: '소모 칼로리', unit: 'kcal'),
              _buildSectionTitle('섭취량'),
              _buildInputField(controller: _foodAmountController, label: '사료양', unit: 'g'),
              const SizedBox(height: 12),
              _buildInputField(controller: _waterAmountController, label: '물양', unit: 'ml'),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(child: const Text('취소'), onPressed: _isSaving ? null : () => Navigator.of(context).pop()),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
          onPressed: _isSaving ? null : _saveRecord,
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('저장', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}