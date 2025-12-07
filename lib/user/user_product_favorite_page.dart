// =======================================
// UserProductFavoritePage.dart (최종본)
// =======================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/product.dart';
import 'user_product_detail_page.dart';
import 'user_payment_page.dart';
import 'package:animal_project/api_config.dart';

class UserProductFavoritePage extends StatefulWidget {
  const UserProductFavoritePage({super.key});

  @override
  State<UserProductFavoritePage> createState() =>
      _UserProductFavoritePageState();
}

class _UserProductFavoritePageState extends State<UserProductFavoritePage>
    with SingleTickerProviderStateMixin {
  List<Product> favoriteProducts = [];
  List<String> _selectedProducts = [];
  bool _isAllSelected = false;
  bool isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFavoriteProducts();
  }

  // -----------------------------
  // 찜상품 불러오기
  // -----------------------------
  Future<void> _fetchFavoriteProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return;

      final url = Uri.parse("${ApiConfig.baseUrl}/users/$userId/favorites");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          favoriteProducts =
              data.map((json) => Product.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        isLoading = false;
      }
    } catch (e) {
      isLoading = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // 화면 구조
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title:
        const Text("장바구니", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "날짜/병원명/진료명 검색",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 탭바
          Container(
            color: Colors.grey[100],
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: "일반상품"),
                Tab(text: "찜한상품"),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCartTabUI(),     // ← 새로 만든 일반상품 UI
                _buildFavoriteTab(),   // 기존 찜상품 UI 그대로
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // (1) 새롭게 완전히 대체된 "일반상품 UI"
  // ============================================================

  Widget _buildCartTabUI() {
    return FutureBuilder<List<Product>>(
      future: _fetchCartProducts(),
      builder: (context, snapshot) {
        // 로딩
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data ?? [];

        // 비었을 때
        if (products.isEmpty) {
          return const Center(
            child: Text("장바구니가 비어있습니다 🛒",
                style: TextStyle(color: Colors.grey)),
          );
        }

        // 총 금액
        int totalPrice = products
            .where((p) => _selectedProducts.contains(p.id))
            .fold(0, (sum, p) => sum + (p.price ?? 0) * (p.count ?? 1));

        return Column(
          children: [
            // ------------------------------
            // 상단 전체 선택 / 선택 삭제
            // ------------------------------
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Checkbox(
                    value: _isAllSelected,
                    onChanged: (value) {
                      setState(() {
                        _isAllSelected = value!;
                        if (_isAllSelected) {
                          _selectedProducts = products.map((p) => p.id).toList();
                        } else {
                          _selectedProducts.clear();
                        }
                      });
                    },
                  ),
                  const Text("전체 선택"),
                  const Spacer(),
                  GestureDetector(
                    onTap: _selectedProducts.isEmpty
                        ? null
                        : () async {
                      for (String id in _selectedProducts) {
                        await _removeFromCart(id);
                      }
                      setState(() {
                        _selectedProducts.clear();
                        _isAllSelected = false;
                      });
                    },
                    child: const Text("선택 삭제",
                        style: TextStyle(color: Colors.black)),
                  )
                ],
              ),
            ),

            // ------------------------------
            // 장바구니 상품 리스트
            // ------------------------------
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, idx) {
                  final item = products[idx];
                  final int count = item.count ?? 1;

                  return Container(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),

                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectedProducts.contains(item.id),
                          onChanged: (value) {
                            setState(() {
                              if (value!) {
                                _selectedProducts.add(item.id);
                              } else {
                                _selectedProducts.remove(item.id);
                              }
                              _isAllSelected = _selectedProducts.length == products.length;
                            });
                          },
                        ),

                        // 삭제 + 수량 조절
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () async => await _removeFromCart(item.id),
                              child: const Icon(Icons.close),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _qtyBtn("-", () async {
                                  if (count > 1) {
                                    await _updateCartCount(item.id, count - 1);
                                    setState(() {});
                                  }
                                }),
                                Padding(
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text("$count",
                                      style: const TextStyle(fontSize: 16)),
                                ),
                                _qtyBtn("+", () async {
                                  await _updateCartCount(item.id, count + 1);
                                  setState(() {});
                                }),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ------------------------------
            // 결제하기 버튼
            // ------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                child: Text("총 ${totalPrice}원 결제하기",
                    style: const TextStyle(fontSize: 18)),

                onPressed: () {
                  final selected = products
                      .where((p) => _selectedProducts.contains(p.id))
                      .toList();

                  if (selected.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("결제할 상품을 선택해주세요!")));
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserPaymentPage(
                        products: selected.map((p) => {
                          "product": p,
                          "count": p.count ?? 1,
                        }).toList(),
                        source: "cart",
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        );
      },
    );
  }

  // 버튼 스타일
  static Widget _qtyBtn(String label, Function onTap) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ============================================================
  // (2) 기존 찜상품 탭
  // ============================================================

  Widget _buildFavoriteTab() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (favoriteProducts.isEmpty) {
      return const Center(child: Text("찜한 상품이 없습니다."));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: favoriteProducts.length,
      itemBuilder: (context, i) {
        final product = favoriteProducts[i];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Expanded(
                child: product.images.isNotEmpty
                    ? Image.network(product.images.first, fit: BoxFit.cover)
                    : Container(color: Colors.grey),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("${product.price}원",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 서버 API 함수
  // ============================================================

  Future<List<Product>> _fetchCartProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("userId");
      if (userId == null) return [];

      final url = Uri.parse("${ApiConfig.baseUrl}/users/$userId/cart");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(res.body);
        return jsonData.map((e) => Product.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> _updateCartCount(String productId, int newCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("userId");
      if (userId == null) return;

      final url =
      Uri.parse("${ApiConfig.baseUrl}/users/$userId/cart/$productId");

      await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"count": newCount}),
      );
    } catch (_) {}
  }

  Future<void> _removeFromCart(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("userId");
      if (userId == null) return;

      final url =
      Uri.parse("${ApiConfig.baseUrl}/users/$userId/cart/$id");

      await http.delete(url);

      setState(() {});
    } catch (_) {}
  }
}
