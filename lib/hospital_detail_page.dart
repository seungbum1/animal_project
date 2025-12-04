import 'dart:convert';
import 'dart:ui'; // 글래스모피즘 효과를 위해 추가
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 햅틱 피드백
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'route_finding_page.dart';
import 'place.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 👈 이 줄 추가

// 🎨 Pro Color Palette
const Color kPrimaryColor = Color(0xFFC06362);
const Color kPrimaryLight = Color(0xFFFDECEC);
const Color kBackgroundColor = Color(0xFFF9F9F9); // 더 밝고 깨끗한 배경
const Color kTextBlack = Color(0xFF222222); // 완전 블랙보다 세련된 다크 그레이
const Color kTextGrey = Color(0xFF888888);
const Color kSurfaceWhite = Colors.white;

class HospitalDetailPage extends StatefulWidget {
  final String? token;
  final String name;
  final String category;
  final String address;
  final double rating;
  final String phone;
  final String url;
  final double latitude;
  final double longitude;
  final double currentLat;
  final double currentLng;

  const HospitalDetailPage({
    super.key,
    required this.token,
    required this.name,
    required this.category,
    required this.address,
    this.rating = 4.8,
    this.phone = "02-1234-5678",
    this.url = "",
    this.latitude = 37.4979,
    this.longitude = 127.0276,
    required this.currentLat,
    required this.currentLng,
  });

  @override
  State<HospitalDetailPage> createState() => _HospitalDetailPageState();
}

class _HospitalDetailPageState extends State<HospitalDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  bool _isSaved = false;
  bool _isLoadingImages = true;

  // 네이버 API 키
  final String naverClientId = "pQH6nAMSamieCWngCpdQ";
  final String naverClientSecret = "YkaOM236tc";

  List<String> _images = [
    "https://cdn.pixabay.com/photo/2019/02/06/15/18/puppy-3979350_1280.jpg",
    "https://cdn.pixabay.com/photo/2017/09/25/13/12/cocker-spaniel-2785074_1280.jpg",
    "https://cdn.pixabay.com/photo/2016/12/13/05/15/puppy-1903313_1280.jpg",
  ];

  final List<Map<String, String>> _dummyReviews = [
    {
      "user": "초코맘",
      "date": "2025.10.01",
      "content": "원장님이 정말 친절하시고 설명도 자세해요! 😍 진료 내내 아이 눈맞춤 해주시는 게 너무 좋았습니다.",
      "tag": "친절해요"
    },
    {
      "user": "멍멍이",
      "date": "2025.09.28",
      "content": "시설이 호텔급으로 깨끗해서 안심이 됩니다. 주차장도 넓어서 대형견 데리고 오기 편해요.",
      "tag": "청결해요"
    },
    {
      "user": "냥냥펀치",
      "date": "2025.09.15",
      "content": "과잉진료 없이 딱 필요한 것만 해주셔서 믿음이 가요. 약 먹이는 법도 친절히 알려주심.",
      "tag": "가성비"
    },
    {
      "user": "골든리트",
      "date": "2025.09.10",
      "content": "우리 아이가 겁이 많은데 간식 주시면서 잘 달래주셨어요 ㅠㅠ 감동입니다.",
      "tag": "세심해요"
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = ScrollController();
    _isSaved = SavedPlacesManager.isSaved(widget.name);
    _fetchNaverInfo();
  }

  Future<void> _fetchNaverInfo() async {
    String query = "${widget.name} ${widget.category} 사진";
    try {
      final imageUrl = Uri.parse(
          "https://openapi.naver.com/v1/search/image?query=$query&display=20&sort=sim&filter=medium");
      final response = await http.get(imageUrl, headers: {
        "X-Naver-Client-Id": naverClientId,
        "X-Naver-Client-Secret": naverClientSecret,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["items"] != null && data["items"].isNotEmpty) {
          if (mounted) {
            setState(() {
              List<String> apiImages = data["items"]
                  .map<String>((item) => item["link"].toString())
                  .toList();
              // API 이미지 + 기본 이미지 섞어서 풍성하게
              List<String> fallbackImages = [
                "https://cdn.pixabay.com/photo/2016/12/13/05/15/puppy-1903313_1280.jpg",
                "https://cdn.pixabay.com/photo/2016/02/19/15/46/labrador-retriever-1210559_1280.jpg",
              ];
              _images = [...apiImages.take(5), ...fallbackImages];
              _isLoadingImages = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingImages = false);
    }
  }

  void _toggleSave() async {
    HapticFeedback.mediumImpact(); // 햅틱 피드백 추가 (손맛)

    Map<String, dynamic> placeData = {
      "place_name": widget.name,
      "category_name": widget.category,
      "road_address_name": widget.address,
      "phone": widget.phone,
      "y": widget.latitude.toString(),
      "x": widget.longitude.toString(),
      "thumbnail": _images.isNotEmpty ? _images.first : null,
    };

    bool isNowSaved =
    await SavedPlacesManager.toggleServer(placeData, widget.token ?? '');

    if (mounted) {
      setState(() {
        _isSaved = isNowSaved;
      });

      // 스낵바 디자인 개선
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _isSaved ? kPrimaryColor : Colors.grey[800],
          content: Row(
            children: [
              Icon(_isSaved ? Icons.check_circle : Icons.info_outline,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(_isSaved ? "보관함에 쏙! 저장되었어요 ❤️" : "저장이 해제되었습니다."),
            ],
          ),
        ),
      );
    }
  }

  void _makePhoneCall() async {
    final Uri telUri = Uri(scheme: 'tel', path: widget.phone);
    if (await canLaunchUrl(telUri)) await launchUrl(telUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      // 하단 버튼이 붕 떠있는 느낌을 주기 위해 Stack 사용 가능하지만,
      // 안정적인 스크롤을 위해 bottomNavigationBar 사용하되 디자인을 커스텀
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(), // iOS 스타일 쫀득한 스크롤
        slivers: [
          _buildSliverAppBar(),
          _buildHeaderInfo(),
          _buildStickyTabBar(),
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                color: kBackgroundColor,
                constraints: const BoxConstraints(minHeight: 500),
                child: AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    return IndexedStack(
                      index: _tabController.index,
                      children: [
                        _buildHomeTab(), // 높이 자동 조절을 위해 별도 위젯 대신 바로 렌더링 추천되나, 여기선 유지
                        _buildReviewTab(),
                        _buildPhotoTab(),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 100), // 하단 버튼 공간 확보
            ]),
          ),
        ],
      ),
      bottomNavigationBar: _buildFloatingBottomBar(),
    );
  }

  /// 1. 몰입형 헤더 (SliverAppBar)
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: kSurfaceWhite,
      elevation: 0,
      leading: IconButton(
        icon: _buildGlassIcon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: _buildGlassIcon(Icons.share_rounded),
          onPressed: () => Share.share("🐾 [${widget.name}] 여기 어때요?\n주소: ${widget.address}\n\n큐라펫에서 확인해보세요!"),
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: widget.name, // 리스트와 연결되는 히어로 태그
              child: PageView.builder(
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  // ✨ [수정] GestureDetector 추가하여 클릭 이벤트 감지
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImagePage(
                            images: _images,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Image.network(
                      _images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
            // (그라데이션 및 인디케이터 코드는 기존과 동일하므로 생략하거나 그대로 둡니다)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.6)],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text("${_images.length}장", style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
            if (_isLoadingImages) const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// 2. 글래스모피즘 아이콘 빌더
  Widget _buildGlassIcon(IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  /// 3. 헤더 정보 섹션 (카드 형태 아님, 자연스럽게 이어지도록)
  Widget _buildHeaderInfo() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          color: kSurfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        transform: Matrix4.translationValues(0, -20, 0),
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // (상단 타이틀/북마크 부분은 기존과 동일)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.category,
                          style: const TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.name,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kTextBlack, height: 1.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _toggleSave,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      // 1. Colors.grey[50] -> const Color(0xFFFAFAFA) 로 변경 (Null 안전성 확보)
                      color: _isSaved ? kPrimaryColor.withOpacity(0.1) : const Color(0xFFFAFAFA),
                      shape: BoxShape.circle,
                      // 2. 그림자를 아예 없애지 말고, 투명하게 만들어서 애니메이션 오류 방지
                      boxShadow: [
                        BoxShadow(
                          color: _isSaved ? kPrimaryColor.withOpacity(0.3) : Colors.transparent,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    // 3. Colors.grey[400] -> const Color(0xFFBDBDBD) 로 변경
                    child: Icon(
                        _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: _isSaved ? kPrimaryColor : const Color(0xFFBDBDBD),
                        size: 26
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✨ [수정] 평점 및 주소 라인 (주소 줄바꿈 허용)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 4),
                    Text("${widget.rating}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kTextBlack)),
                    const SizedBox(width: 8),
                    Text("리뷰 ${_dummyReviews.length * 13}개", style: const TextStyle(color: kTextGrey, fontSize: 14, decoration: TextDecoration.underline)),
                  ],
                ),
                const SizedBox(height: 8),

                // 주소 아이콘 + 텍스트 (여러 줄 표시 가능하게 수정)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // 아이콘을 텍스트 첫 줄 높이에 맞춤
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2), // 아이콘 미세 위치 조정
                      child: Icon(Icons.location_on_outlined, size: 16, color: kTextGrey),
                    ),
                    const SizedBox(width: 4),
                    Expanded( // 남은 공간 꽉 채우기
                      child: Text(
                        widget.address,
                        style: const TextStyle(color: kTextGrey, fontSize: 13, height: 1.4),
                        // maxLines 제거하여 전체 표시
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 4. 끈적이는 탭바 (Sticky Header)
  Widget _buildStickyTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: kTextBlack,
          unselectedLabelColor: Colors.grey[400],
          indicatorColor: kTextBlack,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          splashFactory: NoSplash.splashFactory,
          onTap: (index) {
            setState(() {}); // 탭 변경 시 화면 갱신
          },
          tabs: const [
            Tab(text: "홈"),
            Tab(text: "리뷰"),
            Tab(text: "사진"),
          ],
        ),
      ),
    );
  }

  /// 5. 탭 콘텐츠 - 홈
  Widget _buildHomeTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("기본 정보"),
          const SizedBox(height: 12),
          _buildInfoCard([
            _infoRow(Icons.location_on_outlined, widget.address),
            _infoRow(Icons.access_time_rounded, "매일 10:00 - 20:00 (연중무휴)"),
            _infoRow(Icons.phone_outlined, widget.phone),
            _infoRow(Icons.language, widget.url.isEmpty ? "홈페이지 정보 없음" : widget.url),
          ]),
          const SizedBox(height: 30),
          _buildSectionTitle("제공 서비스"),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ["주차 가능", "예약 가능", "Wi-Fi", "반려동물 동반", "남녀 화장실 구분", "대형견 가능"]
                .map((e) => _buildServiceChip(e))
                .toList(),
          ),
          const SizedBox(height: 30),
          _buildSectionTitle("위치 미리보기"),
          const SizedBox(height: 12),

          // ✨ [여기를 수정] 탭 이벤트 추가
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenMapPage(
                    name: widget.name,
                    address: widget.address,
                    lat: widget.latitude,
                    lng: widget.longitude,
                    currentLat: widget.currentLat,
                    currentLng: widget.currentLng,
                  ),
                ),
              );
            },
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 이미지 레이어 (안전장치 추가)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      "https://cdn.pixabay.com/photo/2020/06/07/02/09/map-5268480_1280.png",
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 🛡️ 이미지가 깨지거나 403 에러가 나면 이 화면이 뜹니다 (앱 안 죽음)
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
                          ),
                        );
                      },
                    ),
                  ),

                  // 2. 버튼 레이어
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_rounded, size: 16, color: kPrimaryColor),
                          SizedBox(width: 8),
                          Text("지도 크게 보기", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextBlack)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 6. 탭 콘텐츠 - 리뷰 (요약 카드 추가)
  Widget _buildReviewTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 리뷰 요약 카드
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kSurfaceWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text("${widget.rating}",
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                        children: List.generate(
                            5,
                                (i) => const Icon(Icons.star,
                                size: 16, color: Colors.amber))),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("방문자 만족도",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: 0.9,
                        backgroundColor: Colors.grey[200],
                        color: Colors.amber,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      Text("90%의 손님이 만족했어요!",
                          style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _dummyReviews.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 30, color: Color(0xFFEEEEEE)),
            itemBuilder: (context, index) {
              final review = _dummyReviews[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getRandomColor(index),
                        radius: 18,
                        child: Text(
                          review["user"]!.substring(0, 1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review["user"]!,
                              style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                          Text(review["date"]!,
                              style: const TextStyle(
                                  color: kTextGrey, fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.amber),
                            SizedBox(width: 2),
                            Text("5.0",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6)),
                    child: Text("👍 ${review["tag"]}",
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                  ),
                  const SizedBox(height: 8),
                  Text(review["content"]!,
                      style: const TextStyle(
                          height: 1.5, color: kTextBlack, fontSize: 14)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getRandomColor(int index) {
    const colors = [
      Color(0xFFE57373),
      Color(0xFF81C784),
      Color(0xFF64B5F6),
      Color(0xFFFFD54F)
    ];
    return colors[index % colors.length];
  }

  /// 7. 탭 콘텐츠 - 사진 (Grid)
  Widget _buildPhotoTab() {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImagePage(
                    images: _images,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: Hero(
              tag: "photo_$index",
              child: Image.network(
                _images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.grey[200]),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 8. 하단 플로팅 버튼바
  Widget _buildFloatingBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _makePhoneCall,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: const Icon(Icons.phone_in_talk, color: Colors.green),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteFindingPage(
                      destinationName: widget.name,
                      destinationLat: widget.latitude,
                      destinationLng: widget.longitude,
                      originLat: widget.currentLat,
                      originLng: widget.currentLng,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: kPrimaryColor.withOpacity(0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("길찾기 시작",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.near_me_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 18, color: kTextBlack));
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: kTextBlack, height: 1.4, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(label,
          style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}
// ... 기존 코드 끝 (FullScreenImagePage 아래에 추가)

/// 🗺️ [NEW] 인터랙티브 전체 화면 지도 페이지
class FullScreenMapPage extends StatefulWidget {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double currentLat;
  final double currentLng;

  const FullScreenMapPage({
    super.key,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.currentLat,
    required this.currentLng,
  });

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 전체 화면 네이버 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(widget.lat, widget.lng),
                zoom: 16, // 상세 보기니까 줌을 좀 더 당겨서 시작
              ),
              locationButtonEnable: true, // 내 위치 확인 가능하게
              logoClickEnable: false,
              consumeSymbolTapEvents: false,
            ),
            onMapReady: (controller) {
              // 병원 위치에 마커 찍기
              final marker = NMarker(
                id: "target_location",
                position: NLatLng(widget.lat, widget.lng),
                caption: NOverlayCaption(text: widget.name, color: kPrimaryColor),
                iconTintColor: kPrimaryColor,
                size: const Size(40, 50),
              );
              controller.addOverlay(marker);
            },
          ),

          // 2. 뒤로가기 버튼 (Glassmorphism)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(50),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: kTextBlack),
                  ),
                ),
              ),
            ),
          ),

          // 3. 하단 정보 카드 (Floating Island)
          Positioned(
            bottom: 34,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextBlack),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: kTextGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.address,
                          style: const TextStyle(fontSize: 14, color: kTextGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // 여기서 바로 길찾기로 연결 (UX 흐름의 완성)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RouteFindingPage(
                              destinationName: widget.name,
                              destinationLat: widget.lat,
                              destinationLng: widget.lng,
                              originLat: widget.currentLat,
                              originLng: widget.currentLng,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.directions_rounded, color: Colors.white),
                      label: const Text("여기까지 길찾기", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height + 1; // 구분선 공간
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1)), // 하단 구분선
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}



class FullScreenImagePage extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImagePage(
      {super.key, required this.images, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        itemCount: images.length,
        controller: PageController(initialPage: initialIndex),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: "photo_$index",
                child: Image.network(
                  images[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                      color: Colors.white, size: 50),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}