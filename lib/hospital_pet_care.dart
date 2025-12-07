// hospital_pet_care.dart
import 'dart:convert';
import 'dart:io' show File;

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
  State<HospitalPetCareListScreen> createState() =>
      _HospitalPetCareListScreenState();
}

enum _ViewMode { patients, care }

class _HospitalPetCareListScreenState
    extends State<HospitalPetCareListScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _http = http.Client();
  final Duration _timeout = const Duration(seconds: 10);

  final TextEditingController _searchCtrl = TextEditingController();
  String _sort = 'dateDesc';

  _ViewMode _mode = _ViewMode.patients;
  Patient? _selectedPatient;

  bool _loadingPatients = true;
  String? _patientsError;
  List<Patient> _patients = [];

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

  // =================== 환자 리스트 불러오기 ===================
  Future<void> _fetchPatients() async {
    setState(() {
      _loadingPatients = true;
      _patientsError = null;
    });

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/hospital-admin/patients'
            '?keyword=${Uri.encodeQueryComponent(_searchCtrl.text)}'
            '&sort=recent',
      );

      final res = await _http
          .get(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      )
          .timeout(_timeout);

      if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list =
        body is List ? body : (body['data'] as List? ?? <dynamic>[]);
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

  // =================== 케어 일지 리스트 불러오기 ===================
  Future<void> _fetchCareList() async {
    if (_selectedPatient == null) return;

    setState(() {
      _loadingCare = true;
      _careError = null;
      _careItems = [];
    });

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/hospital-admin/pet-care'
            '?patientId=${_selectedPatient!.id}'
            '&keyword=${Uri.encodeQueryComponent(_searchCtrl.text)}'
            '&sort=$_sort',
      );

      final res = await _http
          .get(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      )
          .timeout(_timeout);

      if (res.statusCode == 401) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list =
        body is List ? body : (body['data'] as List? ?? <dynamic>[]);
        _careItems = list.map((e) => CareEntry.fromJson(e)).toList();
      } else {
        _careError = '케어 일지 요청 실패 (${res.statusCode})';
      }
    } catch (e) {
      _careError = '네트워크 오류: $e';
    }

    if (mounted) {
      setState(() => _loadingCare = false);
    }
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

  void _openCreate({CareEntry? existing}) {
    if (_selectedPatient == null) return;

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => HospitalPetCareCreateScreen(
          token: widget.token,
          hospitalName: widget.hospitalName,
          patient: _selectedPatient!,
          existingEntry: existing,
        ),
      ),
    )
        .then((updated) {
      if (updated == true) _fetchCareList();
    });
  }

  Future<void> _confirmAndDelete(CareEntry e) async {
    await _deleteCare(e.id);
  }

  // =================== 케어 일지 삭제 ===================
  Future<void> _deleteCare(String id) async {
    try {
      final uri =
      Uri.parse('$_baseUrl/api/hospital-admin/pet-care/$id');

      final res = await _http
          .delete(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          // 서버에서 필요하다면 Content-Type 헤더 같이 추가
          // 'Content-Type': 'application/json; charset=utf-8',
        },
      )
          .timeout(_timeout);

      if (!mounted) return;

      if (res.statusCode == 200) {
        // 정상 삭제
        setState(() {
          _careItems.removeWhere((x) => x.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제되었습니다.')),
        );
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 만료되었습니다.')),
        );
        Navigator.of(context).pop();
      } else if (res.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('이 환자의 일지를 삭제할 권한이 없습니다.')),
        );
      } else if (res.statusCode == 404) {
        // 서버에 이미 없다고 하면 리스트에서도 제거
        setState(() {
          _careItems.removeWhere((x) => x.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('이미 삭제되었거나 존재하지 않습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패 (${res.statusCode})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    }
  }

  // =================== UI ===================
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
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onSubmitted: (_) => _searchNow(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText:
                          isCare ? '메모 검색' : '동물/사용자이름 검색',
                          border: InputBorder.none,
                          contentPadding:
                          const EdgeInsets.only(top: 8),
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
                              ? (_sort == 'dateDesc'
                              ? '날짜순'
                              : '날짜역순')
                              : '최근정보',
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                        const Icon(
                          Icons.expand_more,
                          color: Colors.black45,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _mode == _ViewMode.patients
                    ? _buildPatients()
                    : _buildCareGrid(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _mode == _ViewMode.care
          ? SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            height: 46,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openCreate(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7C8),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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

  // --------------- 환자 리스트 UI ---------------
  Widget _buildPatients() {
    if (_loadingPatients) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_patientsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _patientsError!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _fetchPatients,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_patients.isEmpty) {
      return const Center(
        child: Text('등록된 환자 명단이 없습니다.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _patients.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: Color(0xFFEFEFEF),
      ),
      itemBuilder: (_, i) {
        final p = _patients[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                ? Container(
              width: 44,
              height: 44,
              color: Colors.grey[300],
            )
                : Image.network(
              p.avatarUrl!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          title: Text(
            '${p.userName}/${p.petName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: p.note == null || p.note!.isEmpty
              ? null
              : Text(
            p.note!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: OutlinedButton(
            onPressed: () => _goCareFor(p),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF3F3F3),
              foregroundColor: Colors.black87,
              shape: const StadiumBorder(),
            ),
            child: const Text('일지작성'),
          ),
          onTap: () => _goCareFor(p),
        );
      },
    );
  }

  // --------------- 케어 일지 그리드 UI ---------------
  Widget _buildCareGrid() {
    if (_loadingCare) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_careError != null) {
      return Center(
        child: Text(
          _careError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_careItems.isEmpty) {
      return const Center(
        child: Text('등록된 케어 일지가 없습니다.'),
      );
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
      itemBuilder: (_, i) {
        final item = _careItems[i];
        return CareCard(
          entry: item,
          onDelete: () => _confirmAndDelete(item),
          onEdit: () => _openCreate(existing: item),
        );
      },
    );
  }
}

// =================== 모델 ===================
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

  factory Patient.fromJson(Map<String, dynamic> j) {
    return Patient(
      id: (j['_id'] ?? j['id']).toString(),
      userName: (j['userName'] ?? '').toString(),
      petName: (j['petName'] ?? '').toString(),
      avatarUrl: j['avatarUrl']?.toString(),
      note: j['note']?.toString(),
    );
  }
}

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
    final raw = (j['dateTime'] ?? j['createdAt'] ?? '').toString();
    final dt = DateTime.tryParse(raw) ?? DateTime.now();

    return CareEntry(
      id: (j['_id'] ?? j['id']).toString(),
      dateTime: dt,
      memo: (j['memo'] ?? '').toString(),
      imageUrl: j['imageUrl']?.toString(),
    );
  }
}

// =================== 카드 위젯 ===================
class CareCard extends StatelessWidget {
  final CareEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const CareCard({
    super.key,
    required this.entry,
    required this.onDelete,
    required this.onEdit,
  });

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
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: entry.imageUrl == null ||
                    entry.imageUrl!.isEmpty
                    ? Container(color: Colors.grey[300])
                    : Image.network(
                  entry.imageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: _CardMenu(
                  onDelete: onDelete,
                  onEdit: onEdit,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$date $time',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
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

class _CardMenu extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CardMenu({
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onSelected: (v) async {
        if (v == 'edit') {
          onEdit();
        } else if (v == 'delete') {
          // ❗ builder 파라미터 이름을 dialogContext로 두고,
          //    그걸 Navigator.pop에 써야 함
          final ok = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('삭제하시겠어요?'),
              content: const Text(
                '이 일지와 첨부된 사진이 모두 삭제됩니다. 되돌릴 수 없어요.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, true),
                  child: const Text('삭제'),
                ),
              ],
            ),
          );

          if (ok == true) {
            onDelete();
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Text('수정'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text('삭제'),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(6),
        child: const Icon(
          Icons.more_vert,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}


// =================== 작성/수정 화면 ===================
class HospitalPetCareCreateScreen extends StatefulWidget {
  final String token;
  final String hospitalName;
  final Patient patient;
  final CareEntry? existingEntry;

  const HospitalPetCareCreateScreen({
    super.key,
    required this.token,
    required this.hospitalName,
    required this.patient,
    this.existingEntry,
  });

  @override
  State<HospitalPetCareCreateScreen> createState() =>
      _HospitalPetCareCreateScreenState();
}

class _HospitalPetCareCreateScreenState
    extends State<HospitalPetCareCreateScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  DateTime _dateTime = DateTime.now();
  final TextEditingController _memoCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _memoCtrl.text = widget.existingEntry!.memo;
      _dateTime = widget.existingEntry!.dateTime;
    }
  }

  Future<void> _pickImages() async {
    final picked =
    await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  Future<void> _submit() async {
    if (_memoCtrl.text.trim().isEmpty) {
      _toast('설명을 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final isEdit = widget.existingEntry != null;
      final uri = isEdit
          ? Uri.parse(
        '$_baseUrl/api/hospital-admin/pet-care/${widget.existingEntry!.id}',
      )
          : Uri.parse(
        '$_baseUrl/api/hospital-admin/pet-care',
      );

      final req = http.MultipartRequest(
        isEdit ? 'PATCH' : 'POST',
        uri,
      )
        ..headers['Authorization'] =
            'Bearer ${widget.token}'
        ..fields['patientId'] = widget.patient.id
        ..fields['date'] = _yyyyMmDd(_dateTime)
        ..fields['time'] = _hhmm(_dateTime)
        ..fields['memo'] = _memoCtrl.text.trim();

      for (final x in _images) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'images',
            x.path,
          ),
        );
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        _toast(isEdit ? '수정되었습니다.' : '등록되었습니다.');
        Navigator.of(context).pop(true);
      } else {
        _toast('요청 실패 (${res.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('네트워크 오류: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _yyyyMmDd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingEntry != null;
    final title =
        '${widget.patient.userName}/${widget.patient.petName} · ${isEdit ? '일지 수정' : '일지 등록'}';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '설명',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memoCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _pickImages,
              child: const Text('사진 추가'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _images
                    .map(
                      (x) => Image.file(
                    File(x.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: SafeArea(
        child: Container(
          color: Colors.transparent,
          padding:
          const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7C8),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : Text(isEdit ? '수정 완료' : '등록하기'),
            ),
          ),
        ),
      ),
    );
  }
}
