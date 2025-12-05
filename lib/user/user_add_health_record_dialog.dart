// lib/user_add_health_record_dialog.dart (시간 정밀도 유지 수정)

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:animal_project/user/api_config.dart';

const Color kPrimaryColor = Color(0xFFC06362);
const Color kOnSurfaceColor = Color(0xFF333333);

class AddHealthRecordDialog extends StatefulWidget {
  final String token;
  final DateTime? initialDate; // 수정 시 받아온 원본 시간
  final Map<String, dynamic>? initialWeight;
  final Map<String, dynamic>? initialActivity;
  final Map<String, dynamic>? initialIntake;

  const AddHealthRecordDialog({
    super.key,
    required this.token,
    this.initialDate,
    this.initialWeight,
    this.initialActivity,
    this.initialIntake,
  });

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

  late DateTime _selectedDateTime;
  bool _isSaving = false;
  String? _errorMessage;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    // ✅ [핵심] 원본 시간이 있으면(수정 모드) 밀리초까지 포함된 원본 그대로 사용
    _selectedDateTime = widget.initialDate ?? DateTime.now();

    // 기존 데이터 채워넣기
    if (widget.initialWeight != null) {
      if (widget.initialWeight!['bodyWeight'] != null) _bodyWeightController.text = widget.initialWeight!['bodyWeight'].toString();
      if (widget.initialWeight!['muscleMass'] != null) _muscleMassController.text = widget.initialWeight!['muscleMass'].toString();
      if (widget.initialWeight!['bodyFatMass'] != null) _bodyFatMassController.text = widget.initialWeight!['bodyFatMass'].toString();
    }

    if (widget.initialActivity != null) {
      if (widget.initialActivity!['time'] != null) _activityTimeController.text = widget.initialActivity!['time'].toString();
      if (widget.initialActivity!['calories'] != null) _caloriesBurnedController.text = widget.initialActivity!['calories'].toString();
    }

    if (widget.initialIntake != null) {
      if (widget.initialIntake!['food'] != null) _foodAmountController.text = widget.initialIntake!['food'].toString();
      if (widget.initialIntake!['water'] != null) _waterAmountController.text = widget.initialIntake!['water'].toString();
    }
  }

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

    if (_bodyWeightController.text.trim().isEmpty &&
        _activityTimeController.text.trim().isEmpty &&
        _foodAmountController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '적어도 하나의 기록(체중, 활동, 사료 등)을 입력해주세요.';
      });
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 🚀 [핵심 수정] .toUtc()를 추가했습니다.
      // 내 폰의 시간(22:34 KST)을 표준시(13:34 UTC)로 바꿔서 보냅니다.
      // 서버도 13:34 UTC를 가지고 있으므로, 이제야 둘이 "같은 시간"이라고 인식합니다.
      String formattedDate = _selectedDateTime.toUtc().toIso8601String();

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

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime == null) return;

    setState(() {
      // 날짜를 변경할 때는 어쩔 수 없이 새로 생성하지만,
      // 수정 모드에서 날짜를 안 건드리면 initState의 원본 시간이 유지됨
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required String unit}) {
    return TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
            label: Text(label, style: const TextStyle(color: kOnSurfaceColor)),
            suffixText: unit,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)));
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(top: 20.0, bottom: 12.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          (widget.initialWeight != null || widget.initialActivity != null || widget.initialIntake != null) ? '건강 기록 수정' : '건강 기록 추가',
          style: const TextStyle(fontWeight: FontWeight.bold)
      ),
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
              _buildInputField(controller: _bodyWeightController, label: '몸무게', unit: 'kg'),
              const SizedBox(height: 12),
              _buildInputField(controller: _muscleMassController, label: '근육량', unit: 'kg'),
              const SizedBox(height: 12),
              _buildInputField(controller: _bodyFatMassController, label: '체지방량', unit: 'kg'),

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