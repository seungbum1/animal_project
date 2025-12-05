import 'package:flutter/material.dart';

class AdminProductOrderDetailPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const AdminProductOrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final product = order["product"] ?? {};
    final payment = order["payment"] ?? {};
    final userName = order["userName"] ?? "이름 없음";
    final address = order["address"] ?? "주소 없음";
    final phone = order["phone"] ?? "전화번호 없음";
    final imageUrl = product["image"] ?? "";
    final orderDate =
        order["createdAt"]?.toString().split("T").first ?? "날짜 없음";
    final status = order["status"] ?? "결제완료";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("주문 상세보기", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼 상품 이미지
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: imageUrl.isEmpty
                    ? const Icon(Icons.image_not_supported, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // 📦 상품 정보
            const Text("상품 정보",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            _infoRow("상품명", product["name"] ?? "상품명 없음"),
            _infoRow("카테고리", product["category"] ?? "-"),
            _infoRow("가격", "${product["price"] ?? 0}원"),
            const Divider(height: 30),

            // 💳 결제 정보
            const Text("결제 정보",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            _infoRow("결제 방법", payment["method"] ?? "정보 없음"),
            _infoRow("결제 금액", "${payment["totalAmount"] ?? 0}원"),
            const Divider(height: 30),

            // 👤 주문자 정보
            const Text("주문자 정보",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            _infoRow("이름", userName),
            _infoRow("전화번호", phone),
            _infoRow("주소", address),
            const Divider(height: 30),

            // ⏰ 기타 정보
            const Text("기타 정보",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            _infoRow("주문일자", orderDate),
            _infoRow("상태", status),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}