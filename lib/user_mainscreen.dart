// user_mainscreen.dart (PetHomeScreen)
// 홈 화면에서 병원 예약 캘린더 + 복약 알림 미리보기 포함 버전

import 'dart:convert';
import 'dart:io' show Platform;
import 'user_mypage.dart';
import '../admin/product.dart'; // Product 클래스
import 'package:animal_project/user/user_product_detail_page.dart';
import 'api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'user_myhospital_list.dart';
import 'login.dart';
import 'user_pet_report.dart';
import 'user_hospital_connection.dart';
import 'package:animal_project/user/user_product_page.dart';
import '../hospital_list_page.dart';
import 'user_health_main.dart';
import 'user_notification.dart';
import 'package:animal_project/user/user_payment_page.dart';

// ✅ 복약 알림/펫 프로필 모델
import 'package:animal_project/models/user_health_models.dart';

class PetHomeScreen extends StatefulWidget {
  final String token; // 로그인에서 받은 JWT
  final bool showBottomNav;
  const PetHomeScreen({super.key, required this.token, this.showBottomNav = true});

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // ─────────────────────────────────────────────
  // 상품 섹션 상태
  List<dynamic> _allProducts = [];
  List<dynamic> _randomProducts = [];
  String _selectedCategory = '전체';

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(Uri.parse("$_baseUrl/products"));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allProducts = data; // 서버에서 createdAt -1 정렬로 옴
          // 필요하면 여기서 _randomProducts도 채우고 싶으면 추가 가능
          // _randomProducts = List.of(data)..shuffle();
        });
      } else {
        print("상품 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 상품 불러오기 오류: $e");
    }
  }

  // Map → Product
  Product _mapToProduct(Map<String, dynamic> p) {
    return Product(
      id: p['_id'] ?? '',
      name: p['name'] ?? '',
      category: p['category'] ?? '',
      description: p['description'] ?? '',
      quantity: p['quantity'] ?? 0,
      price: p['price'] ?? 0,
      images: List<String>.from(p['images'] ?? []),
      averageRating: (p['averageRating'] ?? 0).toDouble(),
    );
  }

  void _goToPayment(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPaymentPage(
          products: [
            {
              "product": product,
              "count": 1,
            }
          ],
          source: "home",
        ),
      ),
    );
  }

  // 메인 화면에서 쓸 상품 카드 UI (1열 카드)
  Widget _homeProductCard(Map<String, dynamic> p) {
    final product = _mapToProduct(p);
    final img = product.images.isNotEmpty ? product.images.first : null;
    final price = NumberFormat('#,###').format(product.price);
    final rating = product.averageRating;

    return InkWell(
      onTap: () => _goToPayment(product),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: img != null
                  ? Image.network(
                img,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image,
                      size: 30, color: Colors.grey),
                ),
              )
                  : Container(
                width: 70,
                height: 70,
                color: Colors.grey[200],
                child: const Icon(Icons.image,
                    size: 30, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 10),

            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.category,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.star,
                          size: 14, color: Colors.amber),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$price원",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 프로필 + 복약 알림 상태
  String petName = '';
  int petAge = 0;
  String petGender = '';
  String petSpecies = '';
  String avatarUrl = '';

  bool loading = true;
  String? error;

  // ✅ 홈 상단에 보여줄 "가장 가까운 복약 알림"
  MedicationAlarm? _nextAlarm;
  DateTime? _nextAlarmDateTime;

  int _currentIndex = 0; // 하단 네비 현재 탭

  void _noAnimReplace(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 홈 화면 캘린더(모든 병원 예약 합산) 상태
  final _http = http.Client();
  final Duration _timeout = const Duration(seconds: 8);

  bool _homeCalLoading = true;
  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, List<_Appt>> _homeApptsByDate = {};

  @override
  void initState() {
    super.initState();
    _fetchMyProfile();
    _fetchProducts();
    _loadMonthlyAppointmentsHome(_calMonth);
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  // ✅ 시간 포맷 (오전/오후 6:40)
  String _formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? '오전' : '오후';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period ${hour.toString().padLeft(2, ' ')}:$minute';
  }

  Future<void> _fetchMyProfile() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = (data['user'] as Map<String, dynamic>? ?? {});
        final petJson = (user['petProfile'] as Map<String, dynamic>? ?? {});

        // 🔥 1) UI에 쓰는 값들은 예전처럼 JSON에서 바로 꺼내오기
        setState(() {
          petName = (petJson['name'] ?? '') as String;
          petAge = (petJson['age'] ?? 0) as int;
          petGender = (petJson['gender'] ?? '') as String;
          petSpecies = (petJson['species'] ?? '') as String;
          avatarUrl = (petJson['avatarUrl'] ?? '') as String;
          loading = false;
        });

        // 🔥 2) 알람은 PetProfile 모델로 파싱해서 사용
        final petProfile = PetProfile.fromJson(petJson);
        _computeNextAlarm(petProfile);
      } else {
        setState(() {
          error = '불러오기 실패 (${resp.statusCode})';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = '네트워크 오류: $e';
        loading = false;
      });
    }
  }

  // ✅ 활성화된 알람들 중 앞으로 다가올 알람 하나 계산
  void _computeNextAlarm(PetProfile petProfile) {
    final alarms = petProfile.alarms.where((a) => a.isActive).toList();
    if (alarms.isEmpty) {
      setState(() {
        _nextAlarm = null;
        _nextAlarmDateTime = null;
      });
      return;
    }

    final now = DateTime.now();
    DateTime? bestTime;
    MedicationAlarm? bestAlarm;

    for (final alarm in alarms) {
      // 최대 7일 이내에서 가장 가까운 시간을 찾는다.
      for (int offset = 0; offset < 7; offset++) {
        final day = DateTime(now.year, now.month, now.day)
            .add(Duration(days: offset));

        // 반복 요일 지정된 알람이면 요일 체크
        if (alarm.repeatDays.isNotEmpty &&
            !alarm.repeatDays.contains(day.weekday)) {
          continue;
        }
        // 반복 없음 알람은 "오늘"만 의미 있다고 보고, 내일 이후는 스킵
        if (alarm.repeatDays.isEmpty && offset > 0) break;

        final dt = DateTime(
          day.year,
          day.month,
          day.day,
          alarm.time.hour,
          alarm.time.minute,
        );

        if (dt.isBefore(now)) continue;

        if (bestTime == null || dt.isBefore(bestTime)) {
          bestTime = dt;
          bestAlarm = alarm;
        }
        break; // 이 알람의 가장 빠른 날짜 찾았으면 다음 알람으로
      }
    }

    setState(() {
      _nextAlarm = bestAlarm;
      _nextAlarmDateTime = bestTime;
    });
  }

  // ─────────────────────────────────────────────
  // 다단계 호출 (예약 캘린더)
  Future<void> _loadMonthlyAppointmentsHome(DateTime month) async {
    if (mounted) {
      setState(() {
        _homeCalLoading = true;
        _homeApptsByDate.clear();
      });
    }

    final y = month.year;
    final m = month.month.toString().padLeft(2, '0');

    Future<List<Map<String, dynamic>>> _decodeList(http.Response res) async {
      if (res.statusCode != 200) {
        debugPrint("❌ home monthly ${res.statusCode} ${res.body}");
        return [];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      if (decoded is Map && decoded['appointments'] is List) {
        return (decoded['appointments'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }

    try {
      // 1️⃣ 기본 monthly
      final uri1 =
      Uri.parse('$_baseUrl/api/users/me/appointments/monthly?month=$y-$m');
      final res1 = await _http
          .get(uri1, headers: {'Authorization': 'Bearer ${widget.token}'})
          .timeout(_timeout);
      var raw = await _decodeList(res1);

      // 2️⃣ all=true
      if (raw.isEmpty) {
        final uri2 = Uri.parse(
            '$_baseUrl/api/users/me/appointments/monthly?month=$y-$m&all=true');
        final res2 = await _http
            .get(uri2, headers: {'Authorization': 'Bearer ${widget.token}'})
            .timeout(_timeout);
        raw = await _decodeList(res2);
      }

      // 3️⃣ 병원별 폴백
      if (raw.isEmpty) {
        final hospitalsRes = await _http
            .get(Uri.parse('$_baseUrl/api/users/me/hospitals'),
            headers: {'Authorization': 'Bearer ${widget.token}'})
            .timeout(_timeout);

        final hospitals = (jsonDecode(hospitalsRes.body) as List?) ?? [];
        final all = <Map<String, dynamic>>[];

        for (final h in hospitals) {
          final hid = (h is Map && (h['id'] ?? h['_id']) != null)
              ? (h['id'] ?? h['_id']).toString()
              : null;
          if (hid == null) continue;

          final u = Uri.parse(
              '$_baseUrl/api/users/me/appointments/monthly?month=$y-$m&hospitalId=$hid');
          final r = await _http
              .get(u, headers: {'Authorization': 'Bearer ${widget.token}'})
              .timeout(_timeout);
          final list = await _decodeList(r);
          final name = (h['name'] ?? h['hospitalName'] ?? '').toString();
          for (final e in list) {
            e['hospitalName'] ??= name;
          }
          all.addAll(list);
        }
        raw = all;
      }

      final parsed = raw.map((e) => _Appt.fromJson(e)).toList();
      if (!mounted) return;
      setState(() {
        _homeApptsByDate = _groupByDate(parsed);
        _homeCalLoading = false;
      });
    } catch (e) {
      debugPrint('❌ home monthly error: $e');
      if (mounted) {
        setState(() {
          _homeApptsByDate = {};
          _homeCalLoading = false;
        });
      }
    }
  }

  Map<String, List<_Appt>> _groupByDate(List<_Appt> list) {
    final map = <String, List<_Appt>>{};
    for (final a in list) {
      map.putIfAbsent(a.dateKey, () => []).add(a);
    }
    for (final v in map.values) {
      v.sort((a, b) => a.visit.compareTo(b.visit));
    }
    return map;
  }

  // ───────────────────── 상단 프로필 카드 + 빈 프로필 배너
  Widget _profileCard() {
    final hasProfile =
        petName.isNotEmpty || petAge > 0 || petGender.isNotEmpty || petSpecies.isNotEmpty;

    return Column(
      children: [
        // 상단 프로필 카드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2B6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 📌 Row → Wrap 으로 변경해서 작은 화면에서도 줄바꿈 되도록
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text('나이 : ${petAge > 0 ? '$petAge살' : '-'}'),
                    Text(petSpecies.isNotEmpty ? petSpecies : '종 : -'),
                    Text('성별 : ${petGender.isNotEmpty ? petGender : '-'}'),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  image: avatarUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.pets, size: 24, color: Colors.black54)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 프로필이 비어있으면 안내 배너
        if (!hasProfile)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('반려동물 프로필이 비어 있습니다. 등록해 주세요.')),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserPetReportPage(token: widget.token),
                      ),
                    );
                    if (mounted) _fetchMyProfile();
                  },
                  child: const Text('프로필 등록'),
                )
              ],
            ),
          ),
      ],
    );
  }

  // ✅ 프로필 카드 아래에 보여줄 "가장 가까운 복약 알림" 카드
  Widget _nextAlarmCard() {
    if (_nextAlarm == null || _nextAlarmDateTime == null) {
      return const SizedBox.shrink();
    }
    final alarm = _nextAlarm!;
    final dt = _nextAlarmDateTime!;
    final dateStr = DateFormat('yyyy.MM.dd').format(dt);
    final timeStr =
    _formatTime(TimeOfDay(hour: dt.hour, minute: dt.minute));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E4EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.medication, color: Color(0xFFC06362)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateStr  $timeStr',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alarm.label.isNotEmpty ? alarm.label : '복약 알림',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7E9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '복약 알림',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────── 아이콘 + 라벨 위젯
  // ✅ 친구 코드 반영: HospitalListPage에 token 같이 전달
  Widget _roundMapIcon(IconData icon, String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HospitalListPage(
              category: label,
              token: widget.token,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEAEA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.red.shade600, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ───────────────────── 병원 스케줄 영역
  Widget _hospitalSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              '병원 스케줄 관리',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(10),
          child: _homeCalLoading
              ? const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          )
              : _HomeScheduleCalendar(
            month: _calMonth,
            apptsByDate: _homeApptsByDate,
            onChangeMonth: (m) async {
              setState(() => _calMonth = m);
              await _loadMonthlyAppointmentsHome(m);
            },
            onTapDay: (date, items) {
              _openHomeDaySheet(date, items);
            },
          ),
        ),
      ],
    );
  }

  // ───────────────────── 홈 바텀시트(날짜별 예약 요약)
  void _openHomeDaySheet(DateTime date, List<_Appt> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(249, 246, 255, 0.98),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final ymd =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(ctx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(999)),
                ),
                Text('$ymd 일정',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('등록된 예약이 없습니다.',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  )
                else
                  ...items.map((a) {
                    final label = statusLabelForUser(a.status);
                    final who = [
                      if ((a.userName ?? '').isNotEmpty) a.userName!,
                      if ((a.petName ?? '').isNotEmpty) a.petName!,
                      if (a.doctor.isNotEmpty) a.doctor,
                    ].join(' / ');
                    final subtitle = [
                      if (a.hospitalName != null && a.hospitalName!.isNotEmpty)
                        a.hospitalName!,
                      if (who.isNotEmpty) who,
                      label,
                    ].join(' · ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE7E4EC)),
                        color: Colors.white,
                      ),
                      child: ListTile(
                        title: Text('${a.service} - ${a.hhmm}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(subtitle),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _noAnimReplace(
                              UserMyHospitalListPage(token: widget.token));
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Colors.black26),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('내 병원에서 예약 관리'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────── 랜덤 추천 섹션
  Widget _randomProductSection() {
    if (_randomProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘의 추천 상품 💡',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _randomProducts.length,
            itemBuilder: (context, index) {
              final p = _randomProducts[index];
              final img = (p['images'] != null && p['images'].isNotEmpty)
                  ? "http://127.0.0.1:5000/uploads/${p['images'][0].replaceAll('\\', '/').split('/').last}"
                  : null;
              final price = NumberFormat('#,###').format(p['price'] ?? 0);
              final rating = p['averageRating'] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    final product = _mapToProduct(p);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProductDetailPage(
                          product: product,
                          isFavorite: false,
                          onToggleFavorite: (_) {},
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
                          child: img != null
                              ? Image.network(
                            img,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image,
                                  size: 40, color: Colors.grey),
                            ),
                          )
                              : Container(
                            height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['name'] ?? '상품 이름',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p['category'] ?? '카테고리 없음',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.star,
                                      size: 12, color: Colors.amber),
                                  Text(rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$price원",
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ───────────────────── 카테고리 필터 버튼
  Widget _categoryFilter() {
    final categories = ['전체', '사료', '간식', '용품'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFF2B6) : Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                    isSelected ? Colors.orange.shade700 : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ───────────────────── 다롱님의 필요한 물품 섹션
  Widget _shopSection() {
    final filtered = _selectedCategory == '전체'
        ? _allProducts
        : _allProducts
        .where((p) => (p['category'] ?? '') == _selectedCategory)
        .toList();

    final limited = filtered.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _categoryFilter(),
        const SizedBox(height: 10),
        const Text(
          '다롱님의 필요한 물품 어때요?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        if (limited.isEmpty)
          const Text(
            "등록된 상품이 없습니다.",
            style: TextStyle(color: Colors.grey),
          )
        else
          Column(
            children: limited
                .map((p) => _homeProductCard(p))
                .toList(),
          ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 120,
            height: 36,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProductPage()),
                );
              },
              child: const Text('더보기'),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────── 본문(스크롤)
  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileCard(),
          const SizedBox(height: 8),
          _nextAlarmCard(), // 🔥 프로필 아래 복약 알림 카드
          if (_nextAlarm != null && _nextAlarmDateTime != null)
            const SizedBox(height: 8),
          _hospitalSchedule(),
          const SizedBox(height: 18),

          const Text('다롱이와 함께 떠나는 즐거운 나들이!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _roundMapIcon(Icons.local_cafe, '카페'),
              _roundMapIcon(Icons.restaurant, '식당'),
              _roundMapIcon(Icons.hotel, '숙소'),
              _roundMapIcon(Icons.local_play, '유치원'),
            ],
          ),
          const SizedBox(height: 18),

          _randomProductSection(),
          _shopSection(),
        ],
      ),
    );
  }

  // ───────────────────── Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF2B6),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          petName.isNotEmpty ? petName : '내 반려동물',
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null
          ? Center(
          child: Text(error!,
              style: const TextStyle(color: Colors.red)))
          : _body()),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        onTap: (i) {
          switch (i) {
            case 0:
              break;
            case 1:
              _noAnimReplace(HealthDashboardScreen(token: widget.token));
              break;
            case 2:
              _noAnimReplace(UserMyHospitalListPage(token: widget.token));
              break;
            case 3:
              _noAnimReplace(UserMyPageScreen(token: widget.token));
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "홈"),
          BottomNavigationBarItem(
              icon: Icon(Icons.health_and_safety_outlined), label: '건강관리'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_hospital_outlined), label: "내 병원"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: "마이페이지"),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 아래부터는 달력/모델/라벨 유틸 (높이만 살짝 조정)

class _HomeScheduleCalendar extends StatelessWidget {
  const _HomeScheduleCalendar({
    required this.month,
    required this.apptsByDate,
    required this.onChangeMonth,
    required this.onTapDay,
  });

  final DateTime month;
  final Map<String, List<_Appt>> apptsByDate;
  final ValueChanged<DateTime> onChangeMonth;
  final void Function(DateTime, List<_Appt>) onTapDay;

  @override
  Widget build(BuildContext context) {
    final ym = DateTime(month.year, month.month);
    final first = DateTime(ym.year, ym.month, 1);
    final daysInMonth = DateTime(ym.year, ym.month + 1, 0).day;
    final firstWeekday = first.weekday;
    final leading = (firstWeekday + 6) % 7;
    final totalCells = leading + daysInMonth;
    final rows = ((totalCells + 6) ~/ 7).clamp(5, 6);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final prev = DateTime(ym.year, ym.month - 1, 1);
                onChangeMonth(prev);
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${ym.year}년 ${ym.month}월',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final next = DateTime(ym.year, ym.month + 1, 1);
                onChangeMonth(next);
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        const _HomeDowRow(),
        const SizedBox(height: 4),
        for (int r = 0; r < rows; r++)
          Row(
            children: [
              for (int c = 0; c < 7; c++)
                _HomeCalendarCell(
                  ym: ym,
                  leading: leading,
                  index: r * 7 + c,
                  daysInMonth: daysInMonth,
                  apptsByDate: apptsByDate,
                  onTapDay: onTapDay,
                ),
            ],
          ),
      ],
    );
  }
}

class _HomeCalendarCell extends StatelessWidget {
  const _HomeCalendarCell({
    required this.ym,
    required this.leading,
    required this.index,
    required this.daysInMonth,
    required this.apptsByDate,
    required this.onTapDay,
  });

  final DateTime ym;
  final int leading;
  final int index;
  final int daysInMonth;
  final Map<String, List<_Appt>> apptsByDate;
  final void Function(DateTime, List<_Appt>) onTapDay;

  @override
  Widget build(BuildContext context) {
    final dayNum = index - leading + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const Expanded(child: SizedBox(height: 64)); // 높이 ↑
    }

    final date = DateTime(ym.year, ym.month, dayNum);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final list = apptsByDate[key] ?? const <_Appt>[];

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final isPast = date.isBefore(todayStart);
    final hasAppt = list.isNotEmpty;

    return Expanded(
      child: InkWell(
        onTap: isPast ? null : () => onTapDay(date, list),
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: isPast ? 0.4 : 1.0,
          child: Container(
            height: 64, // 🔥 52 → 64 로 늘림
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: hasAppt ? const Color(0xFFF6F7FF) : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFECECEC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isPast ? Colors.grey : Colors.black,
                  ),
                ),
                const Spacer(),
                if (hasAppt)
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2, right: 2),
                      child: Text('•',
                          style: TextStyle(
                              fontSize: 20,
                              height: .8,
                              color: Color(0xFF5B5CE2))),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDowRow extends StatelessWidget {
  const _HomeDowRow();
  @override
  Widget build(BuildContext context) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: labels.map((_) {
        return const Expanded(
          child: SizedBox(
            height: 24,
            child: Center(child: Text('', style: TextStyle(fontSize: 0))),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// 상태 라벨 + 모델
String statusLabelForUser(String raw) {
  final s = (raw).trim().toLowerCase();
  if (s.contains('approve') ||
      s.contains('confirm') ||
      s.contains('accept') ||
      s == 'ok' ||
      s.contains('확정') ||
      s.contains('승인')) return '예약 확정';
  if (s.contains('reject') ||
      s.contains('deny') ||
      s.contains('cancel') ||
      s.contains('fail') ||
      s.contains('거절') ||
      s.contains('실패') ||
      s.contains('취소')) return '예약 실패';
  return '예약 대기';
}

class _Appt {
  final String id;
  final DateTime visit;
  final String service;
  final String doctor;
  final String status;
  final String? userName;
  final String? petName;
  final String? hospitalName;

  _Appt({
    required this.id,
    required this.visit,
    required this.service,
    required this.doctor,
    required this.status,
    this.userName,
    this.petName,
    this.hospitalName,
  });

  String get dateKey {
    final y = visit.year.toString();
    final m = visit.month.toString().padLeft(2, '0');
    final d = visit.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get hhmm =>
      '${visit.hour.toString().padLeft(2, '0')}:${visit.minute.toString().padLeft(2, '0')}';

  factory _Appt.fromJson(Map<String, dynamic> m) {
    DateTime? dt;
    final dateStr = (m['date'] ?? '').toString();
    final timeStr = (m['time'] ?? '').toString();
    if (dateStr.isNotEmpty && timeStr.isNotEmpty) dt = _parseLocalDateTime(m);
    if (dt == null) {
      final raw = (m['visitDateTime'] ?? '').toString();
      final parsed = raw.isNotEmpty ? DateTime.tryParse(raw) : null;
      if (parsed != null) dt = parsed.isUtc ? parsed.toLocal() : parsed;
    }
    dt ??= DateTime.now();

    String? _clean(String? v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      if (t == '미입력' || t.toLowerCase() == 'unknown' || t == '사용자/미입력') {
        return null;
      }
      return t;
    }

    return _Appt(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      visit: dt,
      service: (m['service'] ?? '진료').toString(),
      doctor: (m['doctorName'] ?? m['doctor'] ?? '의사').toString(),
      status: (m['status'] ?? 'PENDING').toString(),
      userName:
      _clean((m['userName'] ?? m['clientName'] ?? m['user'])?.toString()),
      petName: _clean((m['petName'] ?? m['pet'])?.toString()),
      hospitalName: _clean(m['hospitalName']?.toString()),
    );
  }

  static DateTime _parseLocalDateTime(Map<String, dynamic> m) {
    final dateStr = (m['date'] ?? '').toString();
    final timeStr = (m['time'] ?? '').toString();

    try {
      if (dateStr.isNotEmpty) {
        if (timeStr.isNotEmpty) {
          final combined = '$dateStr $timeStr';
          final parsed = DateTime.tryParse(combined);
          if (parsed != null) return parsed;
        }

        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) return parsed;
      }
    } catch (e) {
      debugPrint('❌ 날짜 파싱 오류: $e');
    }

    return DateTime.now();
  }
}
