import 'package:flutter/material.dart';

class UserOrderDetailPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const UserOrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
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
              Text(order["orderedAt"]?.substring(0, 10) ?? "정보 없음"),
              const SizedBox(height: 12),
              _sectionTitle("성함"),
              Text(order["userName"] ?? "홍길동"),
              const SizedBox(height: 12),
              _sectionTitle("주소"),
              Text(order["address"] ?? "서울특별시 ..."),
              const SizedBox(height: 12),
              _sectionTitle("전화번호"),
              Text(order["phone"] ?? "010-0000-0000"),
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
                      image: order["image"] != null
                          ? DecorationImage(
                        image: NetworkImage(order["image"]),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: order["image"] == null
                        ? const Icon(Icons.image_not_supported)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order["name"] ?? "상품명 없음",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("카테고리: ${order["category"] ?? "정보 없음"}"),
                        Text("상품 가격: ₩${order["price"] ?? 0}"),
                        Text("수량: ${order["quantity"] ?? 1}개"),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 40),
              _sectionTitle("결제 정보"),
              const SizedBox(height: 8),
              _infoRow("상품금액", "${order["price"] ?? 0}원"),
              _infoRow("배송비", "3,000원"),
              _infoRow("총 결제 금액", "${order["totalAmount"] ?? ((order["price"] ?? 0) + 3000)}원"),
              _infoRow("결제수단", order["paymentMethod"] ?? "카카오페이"),
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
