// user_add_health_record_dialog.dart (수정 완료)

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ✅ 날짜 포맷을 위해 intl 패키지 추가
import 'package:animal_project/api_config.dart';

const Color kPrimaryColor = Color(0xFFC06362);
const Color kOnSurfaceColor = Color(0xFF333333);

class AddHealthRecordDialog extends StatefulWidget {
  final String token;
  const AddHealthRecordDialog({super.key, required this.token});

  @override
  State<AddHealthRecordDialog> createState() => _AddHealthRecordDialogState();
}

class _AddHealthRecordDialogState extends State<AddHealthRecordDialog> {
  final _bodyWeightController = TextEditingController();
  final _muscleMassController = TextEditingController();
  final _bodyFatMassController = TextEditingController();
  final _activityTimeController = TextEditingController();
  final _caloriesBurnedController = TextEditingController();
  final _foodAmountController = TextEditingController();
  final _waterAmountController = TextEditingController();

  // ✅ 이제 날짜와 시간을 모두 저장합니다.
  DateTime _selectedDateTime = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;

  String get _baseUrl => ApiConfig.baseUrl;

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

  Future<void> _saveRecord() async {
    setState(() => _errorMessage = null);

    if (_bodyWeightController.text.trim().isEmpty ||
        _activityTimeController.text.trim().isEmpty ||
        _foodAmountController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '필수 항목(*)을 모두 입력해주세요.';
      });
      return;
    }

    setState(() => _isSaving = true);

    try {
      // ✅ 문제점 4번 해결: toIso8601String() 대신, 서버가 이해할 수 있는
      // 현지 시간 기준으로 'YYYY-MM-DDTHH:mm:ss' 포맷의 문자열을 생성합니다.
      // 이렇게 하면 UTC 변환으로 인한 날짜 변경 문제가 발생하지 않습니다.
      String formattedDate = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(_selectedDateTime);

      final body = {
        'date': formattedDate,
        'weight': {
          'bodyWeight': double.tryParse(_bodyWeightController.text),
          'muscleMass': _muscleMassController.text.isNotEmpty ? double.tryParse(_muscleMassController.text) : null,
          'bodyFatMass': _bodyFatMassController.text.isNotEmpty ? double.tryParse(_bodyFatMassController.text) : null,
        },
        'activity': {
          'time': int.tryParse(_activityTimeController.text),
          'calories': _caloriesBurnedController.text.isNotEmpty ? int.tryParse(_caloriesBurnedController.text) : null,
        },
        'intake': {
          'food': int.tryParse(_foodAmountController.text),
          'water': _waterAmountController.text.isNotEmpty ? int.tryParse(_waterAmountController.text) : null,
        }
      };

      (body['weight'] as Map).removeWhere((key, value) => value == null);
      (body['activity'] as Map).removeWhere((key, value) => value == null);
      (body['intake'] as Map).removeWhere((key, value) => value == null);

      final response = await http.post(
        Uri.parse('$_baseUrl/users/me/health-record'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop(true);
      } else {
        final errorBody = json.decode(response.body);
        setState(() {
          _errorMessage = '저장 실패: ${errorBody['message'] ?? response.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '오류 발생: $e';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ 문제점 2번 해결: 날짜와 시간을 함께 선택하는 함수
  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      // ✅ 문제점 3번 해결을 위해 locale 속성을 추가할 수 있으나,
      //    앱 전체에 적용하는 것이 더 좋은 방법입니다. (아래 3단계 참고)
      // locale: const Locale('ko', 'KR'),
    );

    if (pickedDate == null) return; // 날짜 선택을 취소하면 아무것도 하지 않음

    if (!mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime == null) return; // 시간 선택을 취소하면 아무것도 하지 않음

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
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
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ✅ 선택된 날짜와 '시간'까지 함께 표시
                    Text(
                        DateFormat('yyyy.MM.dd (E) HH:mm', 'ko_KR').format(_selectedDateTime),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                    ),
                    TextButton(
                        onPressed: () => _selectDateTime(context),
                        child: const Text('날짜/시간 변경')
                    )
                  ]
              ),
              const Divider(),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              _buildSectionTitle('체중'),
              _buildInputField(controller: _bodyWeightController, label: '몸무게', unit: 'kg', isRequired: true),
              const SizedBox(height: 12),
              _buildInputField(controller: _muscleMassController, label: '근육량', unit: 'kg'),
              const SizedBox(height: 12),
              _buildInputField(controller: _bodyFatMassController, label: '체지방량', unit: 'kg'),
              _buildSectionTitle('활동량'),
              _buildInputField(controller: _activityTimeController, label: '활동 시간', unit: '분', isRequired: true),
              const SizedBox(height: 12),
              _buildInputField(controller: _caloriesBurnedController, label: '소모 칼로리', unit: 'kcal'),
              _buildSectionTitle('섭취량'),
              _buildInputField(controller: _foodAmountController, label: '사료양', unit: 'g', isRequired: true),
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