import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'admin_product_stock_page.dart';
import 'admin_product_order_page.dart';
import 'admin_main_page.dart';
import 'hospital_approval_page.dart';
import 'user_manage_page.dart';
import 'product_register_page.dart';
import 'product.dart';
import 'product_detail_page.dart';
import 'package:animal_project/api_config.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  String _sortOption = "최근등록";
  String _searchQuery = "";
  String _selectedCategory = "전체";

  bool _isSelectionMode = false;
  Set<String> _selectedProductIds = {};

  /// ===========================================
  /// 🔥 상품 가져오기
  /// ===========================================
  Future<void> _fetchProducts() async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/products");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          products = data.map((e) => Product.fromJson(e)).toList();
          _applySort();
          _applyFilters();
          _selectedProductIds.clear();
        });
      }
    } catch (e) {
      print("❌ 오류 발생: $e");
    }
  }

  /// 🔥 선택 상품 삭제
  Future<void> _deleteSelectedProducts() async {
    for (var id in _selectedProductIds) {
      try {
        final url = Uri.parse("${ApiConfig.baseUrl}/products/$id");
        final response = await http.delete(url);
        if (response.statusCode == 200) {
          print("🗑 삭제 완료: $id");
        }
      } catch (e) {
        print("❌ 삭제 오류: $e");
      }
    }

    await _fetchProducts();
    setState(() {
      _isSelectionMode = false;
    });
  }

  /// 🔥 정렬
  void _applySort() {
    if (_sortOption == "최근등록") {
      products = products.reversed.toList();
    } else if (_sortOption == "높은가격") {
      products.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortOption == "낮은가격") {
      products.sort((a, b) => a.price.compareTo(b.price));
    }
  }

  /// 🔥 검색 + 카테고리 필터
  void _applyFilters() {
    filteredProducts = products.where((p) {
      final matchesSearch =
      p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
      (_selectedCategory == "전체" || p.category == _selectedCategory);
      return matchesSearch && matchesCategory;
    }).toList();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  /// =======================================================
  /// 🔥 애니메이션 없는 페이지 교체 함수
  /// =======================================================
  void _noAnimReplace(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  /// =======================================================
  /// 🔥 하단 네비게이션 생성 (currentIndex = 2)
  /// =======================================================
  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 2,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,

      onTap: (index) {
        if (index == 2) return;

        switch (index) {
          case 0:
            _noAnimReplace(context, const AdminMainPage());
            break;
          case 1:
            _noAnimReplace(context, const HospitalApprovalPage());
            break;
          case 3:
            _noAnimReplace(context, const UserManagePage());
            break;
        }
      },

      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "메인화면"),
        BottomNavigationBarItem(icon: Icon(Icons.verified), label: "병원승인"),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "상품"),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "사용자 관리"),
      ],
    );
  }

  /// =======================================================
  /// 🔥 위젯 빌드
  /// =======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("상품 목록", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        automaticallyImplyLeading: false,

        // 주문내역 아이콘
        leading: IconButton(
          icon: const Icon(Icons.receipt_long, color: Colors.black),
          tooltip: "주문 내역",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminProductOrderPage()),
            );
          },
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.inventory, color: Colors.black),
            tooltip: "수량 관리",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminProductStockPage()),
              );
            },
          ),

          // 선택 모드 버튼
          IconButton(
            icon: Icon(
              _isSelectionMode ? Icons.close : Icons.check_circle,
              color: _isSelectionMode ? Colors.red : Colors.black,
            ),
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) _selectedProductIds.clear();
              });
            },
          ),

          // 삭제 버튼
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _selectedProductIds.isEmpty
                  ? null
                  : _deleteSelectedProducts,
            ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 검색창
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: "상품명을 입력해주세요",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          /// 카테고리 선택
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["전체", "간식", "사료", "용품"].map((category) {
                  final selected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      _selectedCategory = category;
                      _applyFilters();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFFF7CC)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? Colors.black : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          /// 총 상품 수 + 정렬 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("총 ${filteredProducts.length}개 상품"),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    _sortOption = val;
                    _applySort();
                    _applyFilters();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: "최근등록", child: Text("최근등록")),
                    PopupMenuItem(value: "높은가격", child: Text("높은가격순")),
                    PopupMenuItem(value: "낮은가격", child: Text("낮은가격순")),
                  ],
                  child: Row(
                    children: [
                      Text(_sortOption, style: const TextStyle(color: Colors.grey)),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          /// 상품 리스트
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchProducts,
              color: Colors.black,
              backgroundColor: const Color(0xFFFFF7CC),

              child: filteredProducts.isEmpty
                  ? ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("검색 결과가 없습니다.")),
                ],
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(12),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (_, index) {
                  return _productCard(
                      context, filteredProducts[index]);
                },
              ),
            ),
          ),

          /// 상품 등록 버튼
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7CC),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size.fromHeight(50),
              ),
              child:
              const Text("상품 등록", style: TextStyle(color: Colors.black)),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductRegisterPage()),
                );
                if (result == true) {
                  await _fetchProducts();
                }
              },
            ),
          ),
        ],
      ),

      /// 🔥 부드러운 하단 네비게이션
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  /// =======================================================
  /// 🔥 상품 카드
  /// =======================================================
  Widget _productCard(BuildContext context, Product product) {
    final isSelected = _selectedProductIds.contains(product.id);

    return GestureDetector(
      onTap: () async {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedProductIds.remove(product.id);
            } else {
              _selectedProductIds.add(product.id);
            }
          });
        } else {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(product: product),
            ),
          );
          if (result == true) await _fetchProducts();
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 이미지
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
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

                /// 텍스트
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("${product.price}원",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text(product.category,
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(width: 6),
                          const Icon(Icons.star,
                              color: Colors.amber, size: 16),
                          Text(
                            product.averageRating > 0
                                ? product.averageRating.toStringAsFixed(1)
                                : "0",
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

          /// 선택 모드 체크박스
          if (_isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 14,
                backgroundColor:
                isSelected ? Colors.blue : Colors.grey.shade300,
                child: Icon(Icons.check,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
