import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'route_finding_page.dart';
import 'hospital_list_page.dart';

class HospitalDetailPage extends StatefulWidget {
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

  /// ✅ 즐겨찾기 동기화용
  final List<Map<String, dynamic>> savedPlaces;
  final Function(List<Map<String, dynamic>>) onUpdateSavedPlaces;

  const HospitalDetailPage({
    super.key,
    required this.name,
    required this.category,
    required this.address,
    this.rating = 4.9,
    this.phone = "전화번호 없음",
    this.url = "",
    this.latitude = 37.4979,
    this.longitude = 127.0276,
    required this.currentLat,
    required this.currentLng,
    required this.savedPlaces,
    required this.onUpdateSavedPlaces,
  });

  @override
  State<HospitalDetailPage> createState() => _HospitalDetailPageState();
}

class _HospitalDetailPageState extends State<HospitalDetailPage> {
  List<String> _images = [];
  String? _description;
  String? _naverLink;
  bool _isLoading = true;

  /// ✅ 즐겨찾기 상태
  late bool _isSaved;
  late List<Map<String, dynamic>> _savedPlaces;

  final String naverClientId = "pQH6nAMSamieCWngCpdQ";
  final String naverClientSecret = "YkaOM236tc";

  @override
  void initState() {
    super.initState();
    _savedPlaces = List<Map<String, dynamic>>.from(widget.savedPlaces);
    _isSaved = _savedPlaces.any((p) => p["place_name"] == widget.name);
    _fetchNaverInfo("${widget.name} ${widget.category}");
  }

  /// ✅ 즐겨찾기 추가/제거
  void _toggleSave() {
    setState(() {
      if (_isSaved) {
        _savedPlaces.removeWhere((p) => p["place_name"] == widget.name);
        _isSaved = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("저장 목록에서 제거되었습니다 🗑️")),
        );
      } else {
        final newPlace = {
          "place_name": widget.name,
          "category_name": widget.category,
          "road_address_name": widget.address,
          "phone": widget.phone,
          "place_url": widget.url,
          "y": widget.latitude.toString(),
          "x": widget.longitude.toString(),
          "thumbnail": _images.isNotEmpty ? _images.first : null,
        };
        _savedPlaces.add(newPlace);
        _isSaved = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("저장 목록에 추가되었습니다 ❤️")),
        );
      }

      /// ✅ 상위 페이지들에 갱신 전달
      widget.onUpdateSavedPlaces(_savedPlaces);
    });
  }

  /// ✅ 네이버에서 상세정보 + 이미지 가져오기
  Future<void> _fetchNaverInfo(String query) async {
    try {
      final localUrl = Uri.parse(
          "https://openapi.naver.com/v1/search/local.json?query=$query&display=1");
      final localRes = await http.get(localUrl, headers: {
        "X-Naver-Client-Id": naverClientId,
        "X-Naver-Client-Secret": naverClientSecret,
      });

      if (localRes.statusCode == 200) {
        final data = jsonDecode(localRes.body);
        if (data["items"] != null && data["items"].isNotEmpty) {
          final item = data["items"][0];
          _description = _stripHtmlTags(item["description"] ?? "");
          _naverLink = item["link"];
        }
      }

      final imageUrl = Uri.parse(
          "https://openapi.naver.com/v1/search/image?query=$query&display=10&sort=sim");
      final imageRes = await http.get(imageUrl, headers: {
        "X-Naver-Client-Id": naverClientId,
        "X-Naver-Client-Secret": naverClientSecret,
      });

      if (imageRes.statusCode == 200) {
        final imgData = jsonDecode(imageRes.body);
        if (imgData["items"] != null && imgData["items"].isNotEmpty) {
          _images = imgData["items"]
              .map<String>((item) => item["link"].toString())
              .toList();
        }
      }
    } catch (e) {
      print("❌ 네이버 API 오류: $e");
    }

    setState(() => _isLoading = false);
  }

  String _stripHtmlTags(String htmlText) {
    final regex = RegExp(r'<[^>]*>', multiLine: true);
    return htmlText.replaceAll(regex, '');
  }

  /// ✅ 전화 기능
  Future<void> _makePhoneCall() async {
    final phone = widget.phone;
    if (phone != "전화번호 없음" && phone.isNotEmpty) {
      final Uri telUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("전화 연결 실패")));
      }
    }
  }

  /// ✅ 공유 기능
  void _shareHospitalInfo() {
    String shareText = "${widget.name}\n📍 ${widget.address}";
    if (widget.phone != "전화번호 없음") shareText += "\n📞 ${widget.phone}";
    if (widget.url.isNotEmpty) {
      shareText += "\n🌐 ${widget.url}";
    } else if (_naverLink != null) {
      shareText += "\n🔗 $_naverLink";
    }
    Share.share(shareText, subject: "병원 정보 공유");
  }

  @override
  Widget build(BuildContext context) {
    final bool hasInfo = _description != null && _description!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          /// ✅ 스크롤 전체 내용
          SingleChildScrollView(
            child: Column(
              children: [
                /// ✅ 상단 이미지 슬라이드
                Stack(
                  children: [
                    _images.isNotEmpty
                        ? SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: PageView.builder(
                        itemCount: _images.length > 3 ? 3 : _images.length,
                        itemBuilder: (context, index) {
                          return Image.network(
                            _images[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => _fallbackImage(),
                          );
                        },
                      ),
                    )
                        : _fallbackImage(),

                    /// ✅ 왼쪽 상단 뒤로가기 버튼 (사진 위에 겹침)
                    Positioned(
                      top: 40,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),

                /// ✅ 기본정보 + 저장버튼
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                Text(widget.rating.toString()),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("📍 ${widget.address}",
                                style:
                                const TextStyle(color: Colors.black54)),
                            Text("📞 ${widget.phone}",
                                style:
                                const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color:
                          _isSaved ? Colors.orangeAccent : Colors.black54,
                          size: 28,
                        ),
                        onPressed: _toggleSave,
                      ),
                    ],
                  ),
                ),

                const Divider(),

                /// ✅ 기능 버튼 4개 (전화, 길찾기, 공유, 저장)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      InkWell(
                        onTap: _makePhoneCall,
                        child: const _IconWithLabel(
                            icon: Icons.call, label: "전화"),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RouteFindingPage(
                                destinationName: widget.name,
                                destinationLat: widget.latitude,
                                destinationLng: widget.longitude,
                                originLat: widget.currentLat,
                                originLng: widget.currentLng,
                              ),
                            ),
                          );
                        },
                        child: const _IconWithLabel(
                            icon: Icons.place, label: "길찾기"),
                      ),
                      InkWell(
                        onTap: _shareHospitalInfo,
                        child: const _IconWithLabel(
                            icon: Icons.share, label: "공유"),
                      ),
                      InkWell(
                        onTap: _toggleSave,
                        child: _IconWithLabel(
                          icon: _isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          label: _isSaved ? "저장됨" : "저장",
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 20),

                /// ✅ 탭 (정보 / 리뷰 / 사진)
                DefaultTabController(
                  length: hasInfo ? 3 : 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.black,
                        tabs: [
                          if (hasInfo) const Tab(text: "정보"),
                          const Tab(text: "리뷰"),
                          const Tab(text: "사진"),
                        ],
                      ),
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          children: [
                            if (hasInfo)
                              _InfoTab(
                                description: _description,
                                naverUrl: _naverLink,
                                onViewNaver: () async {
                                  if (_naverLink != null) {
                                    final uri = Uri.parse(_naverLink!);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                              ),
                            const _ReviewSection(),
                            _PhotoTab(images: _images),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

    );
  }

  Widget _fallbackImage() {
    return Container(
      height: 200,
      color: Colors.grey[300],
      child: const Icon(Icons.image_not_supported,
          color: Colors.grey, size: 50),
    );
  }
}

/// ✅ 공용 아이콘 + 라벨
class _IconWithLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IconWithLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.black),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

/// ✅ 정보 탭
class _InfoTab extends StatelessWidget {
  final String? description;
  final String? naverUrl;
  final VoidCallback? onViewNaver;
  const _InfoTab({this.description, this.naverUrl, this.onViewNaver});

  @override
  Widget build(BuildContext context) {
    if (description != null && description!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(description!,
            style: const TextStyle(fontSize: 15, height: 1.5)),
      );
    }
    return const Center(
        child:
        Text("상세정보를 불러올 수 없습니다.", style: TextStyle(color: Colors.grey)));
  }
}

/// ✅ 리뷰 탭
class _ReviewSection extends StatelessWidget {
  const _ReviewSection();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            title: const Text("리뷰 제목"),
            subtitle: const Text("리뷰 내용 예시입니다."),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text("2025-10-08"),
                const SizedBox(height: 8),
                Container(width: 30, height: 30, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ✅ 사진 탭
class _PhotoTab extends StatelessWidget {
  final List<String> images;
  const _PhotoTab({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const Center(
          child: Text("사진을 불러올 수 없습니다.",
              style: TextStyle(color: Colors.grey)));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => _PhotoGallery(
                    images: images, initialIndex: index),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ✅ 전체화면 사진 보기
class _PhotoGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _PhotoGallery({required this.images, required this.initialIndex});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  late PageController _pageController;
  late int _currentIndex;
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: widget.images.length,
              itemBuilder: (context, index) => InteractiveViewer(
                child: Image.network(widget.images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image_not_supported,
                            color: Colors.white54, size: 50))),
              ),
            ),
            Positioned(
              bottom: 30,
              child: Text("${_currentIndex + 1} / ${widget.images.length}",
                  style:
                  const TextStyle(color: Colors.white70, fontSize: 16)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}