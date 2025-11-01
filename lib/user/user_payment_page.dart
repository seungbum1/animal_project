import 'dart:convert';
import 'package:flutter/material.dart';
import '../admin/product.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'user_product_page.dart';

class UserPaymentPage extends StatefulWidget {
  /// ✅ 이제 List<Map<String, dynamic>>로 받음 (product + count)
  final List<Map<String, dynamic>> products;
  final String source; // ✅ 결제 경로 구분 (detail / favorite)

  const UserPaymentPage({
    super.key,
    required this.products,
    this.source = "detail", // ✅ 기본값: 상품 상세페이지에서 결제
  });

  @override
  State<UserPaymentPage> createState() => _UserPaymentPageState();
}

class _UserPaymentPageState extends State<UserPaymentPage> {

  @override
  void initState() {
    super.initState();
    _loadLatestProducts(); // ✅ 결제 페이지 진입 시 최신 상품 정보 불러오기
  }

  String _selectedPayment = "기타결제";

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();


  /// ✅ 총 금액 계산 (수량 포함)
  int get totalPrice => widget.products.fold(
    0,
        (sum, item) =>
    sum + ((item["product"] as Product).price * (item["count"] as int)),
  );

  /// ✅ 결제 완료 시 주문 저장
  Future<void> _completePayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final savedUserName = prefs.getString('userName') ?? "익명 사용자";

      if (userId == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("로그인이 필요합니다.")));
        return;
      }

      // ✅ 입력값 불러오기
      final userName = _nameController.text.isNotEmpty ? _nameController.text : savedUserName;
      final address = _addressController.text.isNotEmpty ? _addressController.text : "주소 정보 없음";
      final phone = _phoneController.text.isNotEmpty ? _phoneController.text : "연락처 정보 없음";

      // ✅ 주문 생성 루프
      for (var item in widget.products) {
        final product = item["product"] as Product;
        final count = item["count"] as int;

        // ✅ 재고 차감
        final newQty = product.quantity - count;
        if (newQty >= 0) {
          final updateUrl = Uri.parse("http://127.0.0.1:5000/products/${product.id}/quantity");
          await http.patch(
            updateUrl,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"quantity": newQty}),
          );
        }

        // ✅ 주문 데이터 (서버 스키마 구조에 완벽히 맞춤)
        final orderData = {
          "userName": userName,
          "address": address,
          "phone": phone,
          "product": {
            "_id": product.id,
            "name": product.name,
            "category": product.category,
            "price": product.price,
            "quantity": count,
            "image": product.images.isNotEmpty ? product.images.first : "",
          },
          "payment": {
            "method": _selectedPayment, // ✅ 결제 방식 (카카오페이 등)
            "totalAmount": (product.price * count) + 3000,
          },
          "status": "결제완료",
        };

        // ✅ 서버로 주문 전송
        final orderUrl = Uri.parse("http://127.0.0.1:5000/users/$userId/orders");
        final res = await http.post(
          orderUrl,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(orderData),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          print("✅ 주문 저장 성공: ${product.name}");
        } else {
          print("❌ 주문 저장 실패: ${res.body}");
        }
      }

      // ✅ 찜(favorite) 결제 시 장바구니 비우기
      if (widget.source == "favorite") {
        for (var item in widget.products) {
          final product = item["product"] as Product;
          final deleteUrl = Uri.parse("http://127.0.0.1:5000/users/$userId/cart/${product.id}");
          await http.delete(deleteUrl);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("결제가 완료되었습니다 💳")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PaymentCompletePage()),
      );
    } catch (e) {
      print("❌ 결제 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("결제 오류: $e")),
        );
      }
    }
  }

  /// ✅ 서버에서 최신 상품 정보 다시 불러오기
  Future<void> _loadLatestProducts() async {
    try {
      List<Map<String, dynamic>> updatedList = [];

      for (var item in widget.products) {
        final product = item["product"] as Product;
        final count = item["count"] as int;

        final response = await http.get(
          Uri.parse("http://127.0.0.1:5000/products/${product.id}"),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final updatedProduct = Product.fromJson(data); // ✅ 최신 Product 객체로 교체
          updatedList.add({"product": updatedProduct, "count": count});
        } else {
          // 오류 시 기존 데이터 그대로 사용
          updatedList.add(item);
        }
      }

      setState(() {
        widget.products
          ..clear()
          ..addAll(updatedList);
      });

      print("🔄 결제 페이지 최신 상품 동기화 완료 (${widget.products.length}개)");
    } catch (e) {
      print("❌ 최신 상품 불러오기 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        centerTitle: true,
        title: const Text("주문서", style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📦 배송지
            const Text("배송지",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _textField("이름"),
            const SizedBox(height: 8),
            _textField("주소"),
            const SizedBox(height: 8),
            _textField("전화번호"),
            const SizedBox(height: 20),

            // 🧾 상품 목록
            Text("주문 상품 ${widget.products.length}개",
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            ...widget.products.map((item) {
              final product = item["product"] as Product;
              final count = item["count"] as int;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name,
                              style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                          Text("수량: ${count}개",
                              style: const TextStyle(color: Colors.grey)),
                          Text("가격: ${product.price * count}원",
                              style: const TextStyle(color: Colors.black)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 30),

            // 💳 결제 수단
            const Text("결제 수단",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Column(
              children: [
                _radioTile("카카오페이"),
                _radioTile("토스페이"),
                _radioTile("기타결제"),
              ],
            ),

            const SizedBox(height: 30),

            // 💰 결제 금액 요약
            const Text("결제 금액",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _priceRow("상품 금액", "${totalPrice}원"),
            _priceRow("배송비", "3,000원"),
            const Divider(),
            _priceRow("총 결제 금액", "${totalPrice + 3000}원", isBold: true),

            const SizedBox(height: 30),

            // 🧾 결제하기 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _completePayment, // ✅ 서버 연동 결제 완료
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  "${totalPrice + 3000}원 결제하기",
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label) {
    TextEditingController controller;
    if (label == "이름") {
      controller = _nameController;
    } else if (label == "주소") {
      controller = _addressController;
    } else {
      controller = _phoneController;
    }

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }


  Widget _radioTile(String title) {
    return RadioListTile<String>(
      title: Text(title),
      value: title,
      groupValue: _selectedPayment,
      onChanged: (val) => setState(() => _selectedPayment = val!),
      activeColor: Colors.black,
    );
  }

  Widget _priceRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class PaymentCompletePage extends StatelessWidget {
  const PaymentCompletePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              "결제가 완료되었습니다!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // ✅ 결제 후 상품 메인 페이지로 이동
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserProductPage(),
                  ),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7CC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "홈으로 돌아가기",
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
