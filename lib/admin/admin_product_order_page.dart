import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'admin_product_order_detail_page.dart';
import 'package:animal_project/api_config.dart';

class AdminProductOrderPage extends StatefulWidget {
  const AdminProductOrderPage({super.key});

  @override
  State<AdminProductOrderPage> createState() => _AdminProductOrderPageState();
}

class _AdminProductOrderPageState extends State<AdminProductOrderPage> {
  List<dynamic> orders = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  /// =================================================
  /// ✅ 주문 목록 불러오기 (서버 주소 변경 완료)
  /// =================================================
  Future<void> _fetchOrders() async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/orders");
      debugPrint("📡 GET admin orders: $url");

      final response = await http.get(url);

      debugPrint("✅ status=${response.statusCode} body=${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          orders = jsonDecode(response.body);
        });
        print("✅ 주문 ${orders.length}개 불러옴");
      } else {
        print("❌ 주문 불러오기 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 오류: $e");
    }
  }


  /// =================================================
  /// ✅ 주문 상태 업데이트 (PATCH 요청도 서버 주소 변경)
  /// =================================================
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/orders/$orderId"); // ⭐️ 변경됨

      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": newStatus}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("상태가 '$newStatus'로 변경되었습니다.")),
        );
        _fetchOrders();
      } else {
        print("❌ 상태 변경 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = orders.where((order) {
      final productName =
      (order["product"]?["name"] ?? "").toString().toLowerCase();
      return productName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: const Text("주문내역", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Column(
        children: [
          /// 🔍 검색창
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
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

          Expanded(
            child: filteredOrders.isEmpty
                ? const Center(child: Text("주문 내역이 없습니다."))
                : ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                final product = order["product"] ?? {};
                final userName = order["userName"] ?? "이름 없음";
                final imageUrl = product["image"] ?? "";
                final orderDate = order['createdAt']
                    ?.toString()
                    .split("T")
                    .first ??
                    "날짜 없음";
                final status = order['status'] ?? "결제완료";

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminProductOrderDetailPage(order: order),
                      ),
                    );
                  },
                  child: Card(
                    color: Colors.white,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// 이미지
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              image: imageUrl.isNotEmpty
                                  ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: imageUrl.isEmpty
                                ? const Icon(Icons.image_not_supported,
                                color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 10),

                          /// 주문 정보
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(orderDate,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(product["name"] ?? "상품명 없음"),
                                Text(
                                  "카테고리: ${product["category"] ?? '-'}",
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                Text("가격: ${product["price"] ?? 0}원",
                                    style:
                                    const TextStyle(fontSize: 12)),
                                Text("주문자: $userName",
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey)),
                                const SizedBox(height: 8),

                                /// 배송 상태 버튼
                                Row(
                                  children: [
                                    if (status != "배송완료")
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _updateOrderStatus(
                                                  order["_id"], "취소됨"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            shape:
                                            RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text("배송 취소",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ),
                                      ),
                                    if (status != "배송완료")
                                      const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          String currentStatus =
                                              order["status"] ??
                                                  "결제완료";
                                          String newStatus;

                                          if (currentStatus == "결제완료") {
                                            newStatus = "배송중";
                                          } else if (currentStatus ==
                                              "배송중") {
                                            newStatus = "배송완료";
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      "이미 배송이 완료된 주문입니다.")),
                                            );
                                            return;
                                          }

                                          await _updateOrderStatus(
                                              order["_id"], newStatus);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          const Color(0xFFFFF7CC),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          status == "결제완료"
                                              ? "배송하기"
                                              : status == "배송중"
                                              ? "배송완료 처리"
                                              : "배송완료됨",
                                          style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
