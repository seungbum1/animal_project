import 'package:flutter/material.dart';

class UserOrderDetailPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const UserOrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final product = order["product"] ?? {};
    final payment = order["payment"] ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        title: const Text("상세정보", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("년/월/일"),
              Text(order["createdAt"]?.substring(0, 10) ?? "정보 없음"),
              const SizedBox(height: 12),

              _sectionTitle("성함"),
              Text(order["userName"] ?? "정보 없음"),
              const SizedBox(height: 12),

              _sectionTitle("주소"),
              Text(order["address"] ?? "정보 없음"),
              const SizedBox(height: 12),

              _sectionTitle("전화번호"),
              Text(order["phone"] ?? "정보 없음"),

              const Divider(height: 40),
              _sectionTitle("주문 상품"),
              const SizedBox(height: 8),

              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                      image: (product["image"] != null && product["image"] != "")
                          ? DecorationImage(
                        image: NetworkImage(product["image"]),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: (product["image"] == null || product["image"] == "")
                        ? const Icon(Icons.image_not_supported)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product["name"] ?? "상품명 없음",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("카테고리: ${product["category"] ?? "정보 없음"}"),
                        Text("상품 가격: ₩${product["price"] ?? 0}"),
                        Text("수량: ${product["quantity"] ?? 1}개"),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 40),
              _sectionTitle("결제 정보"),
              const SizedBox(height: 8),
              _infoRow("상품금액", "${product["price"] ?? 0}원"),
              _infoRow("배송비", "3,000원"),
              _infoRow("총 결제 금액", "${payment["totalAmount"] ?? 0}원"),
              _infoRow("결제수단", payment["method"] ?? "기타결제"),
              const SizedBox(height: 20),

              _sectionTitle("주문 상태"),
              Text(order["status"] ?? "결제완료",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  );

  Widget _infoRow(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
