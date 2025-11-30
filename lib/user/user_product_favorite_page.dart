import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/product.dart';
import 'user_product_detail_page.dart';
import 'user_payment_page.dart';


class UserProductFavoritePage extends StatefulWidget {
  const UserProductFavoritePage({super.key});

  @override
  State<UserProductFavoritePage> createState() => _UserProductFavoritePageState();
}

class _UserProductFavoritePageState extends State<UserProductFavoritePage>
    with SingleTickerProviderStateMixin {
  List<Product> favoriteProducts = [];
  List<String> _selectedProducts = []; // ✅ 선택된 상품들의 ID 저장
  bool _isAllSelected = false; // ✅ 전체 선택 상태
  bool isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFavoriteProducts();

    // ✅ 기본적으로 전체 선택 ON
    _isAllSelected = true;
  }

  /// ✅ 서버에서 찜 목록 불러오기
  Future<void> _fetchFavoriteProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그인이 필요합니다.")),
        );
        return;
      }

      final url = Uri.parse("http://127.0.0.1:5000/users/$userId/favorites");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          favoriteProducts = data.map((e) => Product.fromJson(e)).toList();
          isLoading = false;
        });
      } else {
        print("❌ 찜 목록 불러오기 실패: ${response.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ 오류 발생: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("장바구니", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          /// 🔍 검색창
          Padding(
            padding: const EdgeInsets.all(12.0),
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

          /// ✅ 탭바
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

          /// ✅ 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNormalProductTab(),
                _buildFavoriteProductTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 일반상품 탭 (UI만)
  /// ✅ 장바구니 상품 탭
  /// ✅ 장바구니 상품 탭 (수량 반영)
  Widget _buildNormalProductTab() {
    return FutureBuilder<List<Product>>(
      future: _fetchCartProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("장바구니가 비어 있습니다 🛒",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }

        final cartProducts = snapshot.data!;
        int totalPrice = cartProducts.fold(
            0, (sum, p) => sum + (p.price ?? 0) * (p.count ?? 1));

        return Column(
          children: [
            // 상단 전체 선택 / 삭제 UI
            // ✅ 전체 선택 / 선택 삭제 UI
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
                          _selectedProducts = cartProducts.map((p) => p.id).toList();
                        } else {
                          _selectedProducts.clear();
                        }
                      });
                    },
                  ),
                  const Text("전체 선택"),
                  const Spacer(),
                  TextButton(
                    onPressed: _selectedProducts.isEmpty
                        ? null
                        : () async {
                      for (var productId in _selectedProducts) {
                        await _removeFromCart(productId);
                      }
                      setState(() {
                        _selectedProducts.clear();
                        _isAllSelected = false;
                      });
                    },
                    child: const Text(
                      "선택 삭제",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),


            // 장바구니 상품 리스트
            Expanded(
              child: ListView.builder(
                itemCount: cartProducts.length,
                itemBuilder: (context, index) {
                  final product = cartProducts[index];
                  int count = product.count ?? 1;

                  return Container(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _selectedProducts.contains(product.id),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedProducts.add(product.id);
                              } else {
                                _selectedProducts.remove(product.id);
                              }

                              // ✅ 전체 선택 상태 자동 갱신
                              _isAllSelected =
                                  _selectedProducts.length == cartProducts.length;
                            });
                          },
                        ),

                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                            image: product.images.isNotEmpty
                                ? DecorationImage(
                              image: NetworkImage(product.images.first),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(product.category,
                                  style:
                                  const TextStyle(color: Colors.black54)),
                              Text("${product.price}원",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () async {
                                await _removeFromCart(product.id);
                              },
                              icon: const Icon(Icons.close),
                            ),
                            Row(
                              children: [
                                _quantityButton("-", () async {
                                  if (count > 1) {
                                    await _updateCartCount(
                                        product.id, count - 1);
                                    setState(() {});
                                  }
                                }),
                                Padding(
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text("$count",
                                      style: const TextStyle(fontSize: 16)),
                                ),
                                _quantityButton("+", () async {
                                  await _updateCartCount(
                                      product.id, count + 1);
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

            // 결제하기 버튼
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  // ✅ 선택된 상품만 필터링
                  final selectedProductsForPayment = cartProducts
                      .where((p) => _selectedProducts.contains(p.id))
                      .map((p) => {
                    "product": p,
                    "count": p.count ?? 1,
                  })
                      .toList();

                  // ✅ 아무것도 선택 안 했을 때 안내
                  if (selectedProductsForPayment.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("결제할 상품을 선택해주세요 🛒")),
                    );
                    return;
                  }

                  // ✅ 선택된 상품만 결제 페이지로 전달
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserPaymentPage(
                        products: selectedProductsForPayment,
                        source: "favorite", // ✅ 선택상품만 결제 후 삭제
                      ),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _fetchCartProducts(); // ✅ 결제 후 장바구니 새로고침
                      setState(() {
                        _selectedProducts.clear();
                        _isAllSelected = false;
                      });
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "총 ${_calculateSelectedTotal(cartProducts)}원 결제하기",
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        );
      },
    );
  }



  /// ✅ 찜한상품 탭 (현재 코드)
  Widget _buildFavoriteProductTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (favoriteProducts.isEmpty) {
      return _buildEmptyView(context);
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
      itemBuilder: (context, index) {
        final product = favoriteProducts[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProductDetailPage(
                  product: product,
                  isFavorite: true,
                  onToggleFavorite: (_) => _fetchFavoriteProducts(),
                ),
              ),
            );
          },
          child: Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      image: product.images.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(product.images.first),
                        fit: BoxFit.cover,
                      )
                          : null,
                      color: Colors.grey[300],
                    ),
                    child: product.images.isEmpty
                        ? const Center(child: Icon(Icons.image, size: 40))
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () async {
                              await _removeFromFavorite(product.id);
                            },
                          ),
                        ],
                      ),
                      Text(
                        "${product.price}원",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      // ⭐ 카테고리 + 평균 평점 표시
                      Row(
                        children: [
                          Text(
                            product.category,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(
                            (product.averageRating > 0
                                ? product.averageRating.toStringAsFixed(1)
                                : "0"),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _quantityButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/empty_dog.png',
                height: 120, width: 120, fit: BoxFit.contain),
            const SizedBox(height: 20),
            const Text("상품이 없다개..",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("찜한 상품이 여기에 표시됩니다!",
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueAccent),
                padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("돌아가기",
                  style: TextStyle(
                      color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
  /// ✅ 선택된 상품들의 총 금액 계산 함수
  int _calculateSelectedTotal(List<Product> products) {
    return products
        .where((p) => _selectedProducts.contains(p.id))
        .fold(0, (sum, p) => sum + (p.price ?? 0) * (p.count ?? 1));
  }

  /// ✅ 장바구니 목록 불러오기
  Future<List<Product>> _fetchCartProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return [];

      final url = Uri.parse("http://127.0.0.1:5000/users/$userId/cart");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final products = data.map((e) => Product.fromJson(e)).toList();

        // ✅ 페이지 처음 열 때 전체 선택 상태라면 모든 상품 ID를 선택목록에 추가
        if (_isAllSelected) {
          _selectedProducts = products.map((p) => p.id).toList();
        }

        return products;
      }
      else {
        print("❌ 장바구니 불러오기 실패: ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ 네트워크 오류: $e");
      return [];
    }
  }

  /// ✅ 장바구니 수량 업데이트 (서버에 반영)
  Future<void> _updateCartCount(String productId, int newCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return;

      final url = Uri.parse("http://127.0.0.1:5000/users/$userId/cart/$productId");
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"count": newCount}),
      );

      if (response.statusCode != 200) {
        print("❌ 수량 변경 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 네트워크 오류: $e");
    }
  }


  /// ✅ 장바구니 상품 제거
  Future<void> _removeFromCart(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return;

      final url =
      Uri.parse("http://127.0.0.1:5000/users/$userId/cart/$productId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("상품이 장바구니에서 제거되었습니다 🗑️")),
        );
      }
    } catch (e) {
      print("❌ 삭제 실패: $e");
    }
  }
  /// ✅ 찜 해제 (서버에 반영)
  Future<void> _removeFromFavorite(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return;

      final url = Uri.parse("http://127.0.0.1:5000/users/$userId/favorites/$productId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          favoriteProducts.removeWhere((p) => p.id == productId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("찜 목록에서 제거되었습니다 ❤️‍🔥")),
        );

        // ✅ 상태 변경을 SharedPreferences로 표시해서 다른 페이지도 인식하도록 함
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("favoritesUpdated", true); // 변경 여부 기록
      }
      else {
        print("❌ 찜 해제 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 네트워크 오류: $e");
    }
  }


}

