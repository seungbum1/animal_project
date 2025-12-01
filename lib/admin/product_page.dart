import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_product_stock_page.dart';
import 'admin_product_order_page.dart'; // ✅ 상단 import 추가
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

  bool _isSelectionMode = false; // ✅ 선택 모드 여부
  Set<String> _selectedProductIds = {}; // ✅ 선택된 상품 id 저장

  /// ✅ DB에서 상품 불러오기
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
      } else {
        print("❌ 상품 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 오류 발생: $e");
    }
  }

  /// ✅ 선택된 상품 삭제
  Future<void> _deleteSelectedProducts() async {
    for (var id in _selectedProductIds) {
      try {
        final url = Uri.parse("${ApiConfig.baseUrl}/products/$id");
        final response = await http.delete(url);
        if (response.statusCode == 200) {
          print("✅ $id 삭제 완료");
        } else {
          print("❌ 삭제 실패: ${response.body}");
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

  /// ✅ 정렬
  void _applySort() {
    if (_sortOption == "최근등록") {
      products = products.reversed.toList();
    } else if (_sortOption == "높은가격") {
      products.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortOption == "낮은가격") {
      products.sort((a, b) => a.price.compareTo(b.price));
    }
  }

  /// ✅ 검색 + 카테고리 필터
  void _applyFilters() {
    setState(() {
      filteredProducts = products.where((p) {
        final matchesSearch =
        p.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCategory =
        (_selectedCategory == "전체" || p.category == _selectedCategory);
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

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
        // ✅ 여기 추가
        leading: IconButton(
          icon: const Icon(Icons.receipt_long, color: Colors.black), // 🧾 주문내역 아이콘
          tooltip: "주문 내역",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminProductOrderPage(),
              ),
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
                  builder: (context) => const AdminProductStockPage(),
                ),
              );
            },
          ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _selectedProductIds.isEmpty ? null : _deleteSelectedProducts,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20), // ✅ 눌렀을 때 효과가 동그랗게 퍼짐
              onTap: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) {
                    _selectedProductIds.clear();
                  }
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white, // ✅ 흰색 배경
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _isSelectionMode ? "취소" : "선택",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

        ],

      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔍 검색창
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
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          /// ✅ 카테고리 선택 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["전체", "간식", "사료", "용품"].map((category) {
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _applyFilters();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFF7CC)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(2, 3),
                          ),
                        ]
                            : [],
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color:
                          isSelected ? Colors.black : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          /// 총 상품 수 + 정렬
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("총 ${filteredProducts.length}개 상품"),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _sortOption = value;
                      _applySort();
                      _applyFilters();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: "최근등록", child: Text("최근등록")),
                    const PopupMenuItem(value: "높은가격", child: Text("높은가격순")),
                    const PopupMenuItem(value: "낮은가격", child: Text("낮은가격순")),
                  ],
                  child: Row(
                    children: [
                      Text(_sortOption,
                          style: const TextStyle(color: Colors.grey)),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          /// 상품 카드 리스트
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchProducts, // ✅ 스크롤 위로 당길 때 상품 다시 불러옴
              color: Colors.black,
              backgroundColor: const Color(0xFFFFF7CC),
              child: filteredProducts.isEmpty
                  ? ListView( // ✅ 빈화면에서도 스크롤 가능하게 변경
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("검색 결과가 없습니다.")),
                ],
              )
                  : GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(), // ✅ 스크롤 없을 때도 당김 가능
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return _productCard(context, product);
                },
              ),
            ),
          ),


          /// 상품 등록 버튼
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7CC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductRegisterPage(),
                  ),
                );
                if (result == true) {
                  await _fetchProducts(); // ✅ 등록 후 목록 새로고침
                  setState(() {});
                }
              },
              child: const Text("상품 등록",
                  style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),

      /// ✅ 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminMainPage()),
            );
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const HospitalApprovalPage()),
            );
          }
          if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserManagePage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "메인화면"),
          BottomNavigationBarItem(icon: Icon(Icons.verified), label: "병원승인"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "상품"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "사용자 관리"),
        ],
      ),
    );
  }

  /// ✅ 상품 카드 위젯
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
              builder: (context) => ProductDetailPage(product: product),
            ),
          );
          if (result == true) {
            await _fetchProducts(); // ✅ 수정 후 목록 새로고침
            setState(() {});
          }
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
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

          if (_isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 14,
                backgroundColor:
                isSelected ? Colors.blue : Colors.grey.shade300,
                child: Icon(Icons.check,
                    size: 16, color: isSelected ? Colors.white : Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

}
