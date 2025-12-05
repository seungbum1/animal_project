import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'hospital_approval_page.dart';
import 'product_page.dart';
import 'product_register_page.dart';
import 'user_manage_page.dart';
import 'product.dart';
import 'product_detail_page.dart';
import 'package:animal_project/user/api_config.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  List<Product> recentProducts = [];

  /// ============================================
  /// ✅ 서버에서 최근 상품 불러오기 (최신순 4개)
  /// ============================================
  Future<void> _fetchRecentProducts() async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/products"); // ⭐️ 변경된 부분

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final products = data.map((e) => Product.fromJson(e)).toList();

        setState(() {
          recentProducts = products.reversed.take(4).toList();
        });
      } else {
        print("❌ 상품 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 오류 발생: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRecentProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("큐라펫", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: const [
          Icon(Icons.notifications_none, color: Colors.black),
          SizedBox(width: 12),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// --------------------------------------------------------
            /// 병원 승인관리
            /// --------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("병원 승인관리",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const HospitalApprovalPage()));
                  },
                  child: const Text("확인하기 >", style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: _boxDecoration(),
              child: Column(
                children: [
                  _approvalItem("병원1 / 성함"),
                  _approvalItem("병원2 / 성함"),
                  _approvalItem("병원3 / 성함"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// --------------------------------------------------------
            /// 최근 상품 보기
            /// --------------------------------------------------------
            _sectionTitle("상품 확인하기"),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _boxDecoration(),
              child: Column(
                children: [
                  const Center(
                    child: Text("최근에 추가된 상품",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 200,
                    child: recentProducts.isEmpty
                        ? const Center(child: Text("등록된 상품이 없습니다."))
                        : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentProducts.length,
                      itemBuilder: (context, index) {
                        final product = recentProducts[index];
                        return _productCard(product, context);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProductRegisterPage(),
                          ),
                        );

                        if (result == true) {
                          _fetchRecentProducts();
                        }
                      },
                      child:
                      const Text("상품 등록", style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// --------------------------------------------------------
            /// 제재 목록
            /// --------------------------------------------------------
            _sectionTitle("제재 목록"),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _boxDecoration(),
              child: Column(
                children: [
                  _penaltyItem("김세찬", "손승범"),
                  _penaltyItem("김건희", "김곽철"),
                  _penaltyItem("조경훈", "김승빈"),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      /// --------------------------------------------------------
      /// 하단 네비게이션 바
      /// --------------------------------------------------------
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HospitalApprovalPage()),
            );
          }
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProductPage()),
            );
          }
          if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UserManagePage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "홈"),
          BottomNavigationBarItem(icon: Icon(Icons.verified), label: "병원승인"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "상품"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "사용자 관리"),
        ],
      ),
    );
  }

  /// --------------------------------------------------------
  /// 상품 카드 UI
  /// --------------------------------------------------------
  Widget _productCard(Product product, BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );

        if (result == true) {
          _fetchRecentProducts();
        }
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: product.images.isNotEmpty
                      ? DecorationImage(
                    image: NetworkImage(product.images.first),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: product.images.isEmpty
                    ? const Center(child: Text("상품 이미지"))
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(product.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text("${product.price}원",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(product.category, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------
  /// UI 컴포넌트 공통
  /// --------------------------------------------------------

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: const Color(0xFFFFF5C3),
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 6,
          offset: const Offset(2, 2),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (trailing != null)
            Text(trailing, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _approvalItem(String name) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person, color: Colors.grey),
        title: Text(name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {},
              child: const Text("승인", style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {},
              child: const Text("거절", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventItem(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _penaltyItem(String leftName, String rightName) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          "$leftName | $rightName",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}