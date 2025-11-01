// hospital_pet_care.dart
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';

class HospitalPetCareListScreen extends StatefulWidget {
  const HospitalPetCareListScreen({
    super.key,
    required this.token,
    required this.hospitalName,
  });

  final String token;
  final String hospitalName;

  @override
  State<HospitalPetCareListScreen> createState() => _HospitalPetCareListScreenState();
}

enum _ViewMode { patients, care }

class _HospitalPetCareListScreenState extends State<HospitalPetCareListScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // ------- http & common -------
  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  // ------- search/sort shared -------
  final TextEditingController _searchCtrl = TextEditingController();
  String _sort = 'dateDesc'; // dateDesc | dateAsc

  // ------- mode & selections -------
  _ViewMode _mode = _ViewMode.patients;
  Patient? _selectedPatient;

  // ------- patient list state -------
  bool _loadingPatients = true;
  String? _patientsError;
  List<Patient> _patients = [];

  // ------- care list state -------
  bool _loadingCare = false;
  String? _careError;
  List<CareEntry> _careItems = [];

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  @override
  void dispose() {
    _http.close();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ==================== Patients ====================
  Future<void> _fetchPatients() async {
    setState(() {
      _loadingPatients = true;
      _patientsError = null;
    });

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/hospital-admin/patients?keyword=${Uri.encodeQueryComponent(_searchCtrl.text)}&sort=recent',
      );
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);

      if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);
        _patients = list.map((e) => Patient.fromJson(e)).toList();
      } else {
        _patientsError = '명단 요청 실패 (${res.statusCode})';
      }
    } catch (e) {
      _patientsError = '네트워크 오류: $e';
    }

    if (mounted) {
      setState(() => _loadingPatients = false);
    }
  }

  void _goCareFor(Patient p) {
    setState(() {
      _selectedPatient = p;
      _mode = _ViewMode.care;
    });
    _fetchCareList();
  }

  // ==================== Care list ====================
  Future<void> _fetchCareList() async {
    if (_selectedPatient == null) return;

    setState(() {
      _loadingCare = true;
      _careError = null;
      _careItems = [];
    });

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/hospital-admin/pet-care?patientId=${_selectedPatient!.id}'
            '&keyword=${Uri.encodeQueryComponent(_searchCtrl.text)}&sort=$_sort',
      );
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);

      if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['data'] as List? ?? []);
        _careItems = list.map((e) => CareEntry.fromJson(e)).toList();
      } else {
        _careError = '케어 일지 요청 실패 (${res.statusCode})';
      }
    } catch (e) {
      _careError = '네트워크 오류: $e';
    }

    if (mounted) setState(() => _loadingCare = false);
  }

  void _backToPatients() {
    setState(() {
      _mode = _ViewMode.patients;
      _selectedPatient = null;
      _searchCtrl.clear();
    });
  }

  void _toggleSortAndReload() {
    setState(() {
      _sort = _sort == 'dateDesc' ? 'dateAsc' : 'dateDesc';
    });
    if (_mode == _ViewMode.care) {
      _fetchCareList();
    } else {
      _fetchPatients();
    }
  }

  void _searchNow() {
    if (_mode == _ViewMode.care) {
      _fetchCareList();
    } else {
      _fetchPatients();
    }
  }

  void _openCreate() {
    if (_selectedPatient == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => HospitalPetCareCreateScreen(
        token: widget.token,
        hospitalName: widget.hospitalName,
        patient: _selectedPatient!,
      ),
    ))
        .then((_) => _fetchCareList());
  }

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    final isCare = _mode == _ViewMode.care;
    final title = isCare && _selectedPatient != null
        ? '${_selectedPatient!.userName}/${_selectedPatient!.petName} · 입원 케어 일지'
        : '입원 케어 일지';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: isCare
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToPatients,
        )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_mode == _ViewMode.care) {
            await _fetchCareList();
          } else {
            await _fetchPatients();
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: [
              // 검색 + 정렬 (두 모드 공용)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onSubmitted: (_) => _searchNow(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: isCare ? '메모 검색' : '동물/사용자이름 검색',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(top: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _toggleSortAndReload,
                    child: Row(
                      children: [
                        const Icon(Icons.sort, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          isCare
                              ? (_sort == 'dateDesc' ? '날짜순' : '날짜역순')
                              : '최근정보',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const Icon(Icons.expand_more, color: Colors.black45, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 본문
              Expanded(
                child: _mode == _ViewMode.patients
                    ? _buildPatients()
                    : _buildCareGrid(),
              ),
            ],
          ),
        ),
      ),

      // 하단 버튼: 일지모드에서만 노출
      bottomNavigationBar: _mode == _ViewMode.care
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            height: 46,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7C8),
                foregroundColor: Colors.black87,
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('반려 일지 추가'),
            ),
          ),
        ),
      )
          : null,
    );
  }

  // ---- 환자 리스트 화면 ----
  Widget _buildPatients() {
    if (_loadingPatients) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_patientsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_patientsError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _fetchPatients,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            )
          ],
        ),
      );
    }
    if (_patients.isEmpty) {
      return const Center(child: Text('등록된 환자 명단이 없습니다.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _patients.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEFEFEF)),
      itemBuilder: (_, i) {
        final p = _patients[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                ? Container(width: 44, height: 44, color: Colors.grey[300])
                : Image.network(p.avatarUrl!, width: 44, height: 44, fit: BoxFit.cover),
          ),
          title: Text('${p.userName}/${p.petName}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: p.note == null || p.note!.isEmpty
              ? null
              : Text(p.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: OutlinedButton(
            onPressed: () => _goCareFor(p),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF3F3F3),
              foregroundColor: Colors.black87,
              shape: StadiumBorder(),
            ),
            child: const Text('일지작성'),
          ),
          onTap: () => _goCareFor(p),
        );
      },
    );
  }

  // ---- 케어 일지 그리드 ----
  Widget _buildCareGrid() {
    if (_loadingCare) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_careError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_careError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _fetchCareList,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            )
          ],
        ),
      );
    }
    if (_careItems.isEmpty) {
      return const Center(child: Text('등록된 케어 일지가 없습니다.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _careItems.length,
      itemBuilder: (_, i) => CareCard(entry: _careItems[i]),
    );
  }
}

/// 환자 데이터 모델
class Patient {
  final String id;
  final String userName;
  final String petName;
  final String? avatarUrl;
  final String? note;

  Patient({
    required this.id,
    required this.userName,
    required this.petName,
    this.avatarUrl,
    this.note,
  });

  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    id: (j['_id'] ?? j['id'] ?? '').toString(),
    userName: (j['userName'] ?? j['ownerName'] ?? j['name'] ?? '').toString(),
    petName: (j['petName'] ?? j['animalName'] ?? '').toString(),
    avatarUrl: (j['avatarUrl'] ?? j['petImageUrl'] ?? j['imageUrl'])?.toString(),
    note: (j['note'] ?? j['memo'])?.toString(),
  );
}

/// 케어일지 데이터 모델
class CareEntry {
  final String id;
  final DateTime dateTime;
  final String memo;
  final String? imageUrl;

  CareEntry({
    required this.id,
    required this.dateTime,
    required this.memo,
    this.imageUrl,
  });

  factory CareEntry.fromJson(Map<String, dynamic> j) {
    DateTime? dt;
    final d = j['date']?.toString();
    final t = j['time']?.toString();
    if (d != null && d.isNotEmpty && t != null && t.isNotEmpty) {
      dt = DateTime.tryParse('${d}T${t}');
    }
    dt ??= DateTime.tryParse((j['dateTime'] ?? '').toString()) ?? DateTime.now();

    String? thumb;
    if (j['imageUrl'] != null && j['imageUrl'].toString().isNotEmpty) {
      thumb = j['imageUrl'].toString();
    } else if (j['images'] is List && (j['images'] as List).isNotEmpty) {
      thumb = (j['images'][0] ?? '').toString();
    }

    return CareEntry(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      dateTime: dt,
      memo: (j['memo'] ?? j['comment'] ?? '').toString(),
      imageUrl: thumb,
    );
  }
}

/// 카드 UI
class CareCard extends StatelessWidget {
  const CareCard({super.key, required this.entry});
  final CareEntry entry;

  @override
  Widget build(BuildContext context) {
    final date =
        '${entry.dateTime.year}.${entry.dateTime.month.toString().padLeft(2, '0')}.${entry.dateTime.day.toString().padLeft(2, '0')}';
    final time =
        '${entry.dateTime.hour.toString().padLeft(2, '0')}:${entry.dateTime.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: entry.imageUrl == null || entry.imageUrl!.isEmpty
                ? Container(color: Colors.grey[300])
                : Image.network(entry.imageUrl!, fit: BoxFit.cover),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(time, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.memo,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 등록 화면 (선택된 환자에 종속)
class HospitalPetCareCreateScreen extends StatefulWidget {
  const HospitalPetCareCreateScreen({
    super.key,
    required this.token,
    required this.hospitalName,
    required this.patient,
  });

  final String token;
  final String hospitalName;
  final Patient patient;

  @override
  State<HospitalPetCareCreateScreen> createState() => _HospitalPetCareCreateScreenState();
}

class _HospitalPetCareCreateScreenState extends State<HospitalPetCareCreateScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  DateTime _dateTime = DateTime.now();
  final TextEditingController _memoCtrl = TextEditingController();
  bool _submitting = false;

  Future<void> _pickImages() async {
    if (_images.length >= 10) {
      _toast('최대 10장까지 첨부할 수 있어요.');
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isNotEmpty) {
      setState(() {
        final remain = 10 - _images.length;
        _images.addAll(picked.take(remain));
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '날짜 선택',
    );
    if (d != null) {
      setState(() {
        _dateTime = DateTime(d.year, d.month, d.day, _dateTime.hour, _dateTime.minute);
      });
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
      helpText: '시간 선택',
    );
    if (t != null) {
      setState(() {
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day, t.hour, t.minute);
      });
    }
  }

  Future<void> _submit() async {
    if (_memoCtrl.text.trim().isEmpty) {
      _toast('설명을 입력해 주세요.');
      return;
    }
    setState(() => _submitting = true);

    try {
      final uri = Uri.parse('$_baseUrl/api/hospital-admin/pet-care');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..fields['patientId'] = widget.patient.id
        ..fields['date'] = _yyyyMmDd(_dateTime)
        ..fields['time'] = _hhmm(_dateTime)
        ..fields['memo'] = _memoCtrl.text.trim();

      for (final x in _images) {
        req.files.add(await http.MultipartFile.fromPath('images', x.path));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200 || res.statusCode == 201) {
        _toast('등록되었습니다.');
        if (!mounted) return;
        Navigator.of(context).pop();
      } else if (res.statusCode == 401) {
        _toast('로그인이 만료되었습니다.');
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        _toast('등록 실패 (${res.statusCode})');
      }
    } catch (e) {
      _toast('네트워크 오류: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_dateTime.year}.${_dateTime.month.toString().padLeft(2, '0')}.${_dateTime.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          '${widget.patient.userName}/${widget.patient.petName} · 일지 등록',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('사진', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _ImagePickerGrid(
              images: _images,
              onAdd: _pickImages,
              onRemove: (i) => setState(() => _images.removeAt(i)),
            ),
            const SizedBox(height: 18),

            const Text('날짜 선택', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _FieldButton(
                    label: dateStr,
                    icon: Icons.calendar_today,
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FieldButton(
                    label: timeStr,
                    icon: Icons.access_time,
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Text('설명', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEAEAEA)),
              ),
              child: TextField(
                controller: _memoCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  hintText: '예) 보호자님, 오전 약은 잘 먹었고 지금은 편안히 휴식 중입니다 :)',
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: SafeArea(
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7C8),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('등록하기'),
            ),
          ),
        ),
      ),
    );
  }
}

/// 이미지 피커 그리드
class _ImagePickerGrid extends StatelessWidget {
  const _ImagePickerGrid({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> images;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final canAdd = images.length < 10;
    final length = images.length + (canAdd ? 1 : 0);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(length, (i) {
        if (canAdd && i == 0) {
          return InkWell(
            onTap: onAdd,
            child: Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD9D9D9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 26, color: Colors.black54),
                  const SizedBox(height: 4),
                  Text('${images.length}/10',
                      style: const TextStyle(color: Colors.black45, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        final idx = i - (canAdd ? 1 : 0);
        final x = images[idx];

        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(x.path),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: -8,
              top: -8,
              child: IconButton(
                onPressed: () => onRemove(idx),
                icon: const Icon(Icons.cancel, color: Colors.black54),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: Color(0xFFEAEAEA)),
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
