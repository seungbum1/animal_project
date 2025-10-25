import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../admin/product.dart';

class AdminProductStockPage extends StatefulWidget {
  const AdminProductStockPage({super.key});

  @override
  State<AdminProductStockPage> createState() => _AdminProductStockPageState();
}

class _AdminProductStockPageState extends State<AdminProductStockPage> {
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  /// ✅ 상품 목록 불러오기
  Future<void> _fetchProducts() async {
    try {
      final url = Uri.parse("http://127.0.0.1:5000/products");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _products = (data as List).map((e) => Product.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception("상품 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 오류: $e");
      setState(() => _isLoading = false);
    }
  }

  /// ✅ 수량 서버 업데이트
  Future<void> _updateQuantity(String productId, int newQty) async {
    try {
      final url = Uri.parse("http://127.0.0.1:5000/products/$productId/quantity");
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"quantity": newQty}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 수량이 업데이트되었습니다.")),
        );
      } else {
        print("❌ 수량 업데이트 실패: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("수량 업데이트 실패 ❌")),
        );
      }
    } catch (e) {
      print("❌ 네트워크 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("상품 수량 관리", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFFFF7CC),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
          ? const Center(child: Text("상품이 없습니다."))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          final qtyController =
          TextEditingController(text: product.quantity.toString());

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[300],
                      image: product.images.isNotEmpty
                          ? DecorationImage(
                        image:
                        NetworkImage(product.images.first),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Text("${product.price}원",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: "0",
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF7CC),
                      foregroundColor: Colors.black,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () async {
                      final newQty = int.tryParse(qtyController.text) ?? 0;
                      await _updateQuantity(product.id, newQty);
                      // ✅ 수량 변경 후, 이전 페이지로 "업데이트됨" 신호(true) 전달
                      await _fetchProducts(); // 최신 목록 갱신만
                    },
                    child: const Text("저장"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
