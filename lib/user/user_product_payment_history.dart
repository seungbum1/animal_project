import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:animal_project/user/api_config.dart';
import 'user_order_detail_page.dart';
import 'user_product_review_page.dart';
import 'user_mypage.dart';

class UserProductPaymentHistoryPage extends StatefulWidget {
  final String userId;
  const UserProductPaymentHistoryPage({super.key, required this.userId});

  @override
  State<UserProductPaymentHistoryPage> createState() =>
      _UserProductPaymentHistoryPageState();
}

class _UserProductPaymentHistoryPageState
    extends State<UserProductPaymentHistoryPage> {
  List<dynamic> orders = [];
  List<dynamic> filteredOrders = [];
  String _searchQuery = "";

  bool _showDateFilter = false;
  DateTime? _startDate;
  DateTime? _endDate;

  Widget _filterButton(String label, DateTime? start, DateTime? end) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _startDate = start;
          _endDate = end;
          _filterByDate();
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFF7CC),
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _dateBox(String label, DateTime? date, {required bool isStart}) {
    return GestureDetector(
      onTap: () => _showMiniCalendarDialog(isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          date != null ? date.toString().substring(0, 10) : label,
        ),
      ),
    );
  }

  void _filterByDate() {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      filteredOrders = orders.where((order) {
        final raw = order["createdAt"] ?? order["orderedAt"] ?? "";
        final orderDate = DateTime.tryParse(raw);
        if (orderDate == null) return false;

        return orderDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    });
  }

  Future<void> _showMiniCalendarDialog(bool isStart) async {
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isStart ? "시작일 선택" : "종료일 선택",
              textAlign: TextAlign.center),
          content: SizedBox(
            width: 300,
            height: 300,
            child: CalendarDatePicker(
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              onDateChanged: (date) => selectedDate = date,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  if (isStart) {
                    _startDate = selectedDate;
                  } else {
                    _endDate = selectedDate;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text("확인", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  // 🔥 주문 목록 불러오기 API
  Future<void> _fetchOrders() async {
    final url =
    Uri.parse("${ApiConfig.baseUrl}/users/${widget.userId}/orders");

    try {
      final res = await http.get(url);

      debugPrint(
          "📡 GET 주문내역 url=$url status=${res.statusCode} body=${res.body}");

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);

        // createdAt 기준 최신 정렬
        data.sort((a, b) {
          final aDate = DateTime.tryParse(a["createdAt"] ?? "") ?? DateTime(0);
          final bDate = DateTime.tryParse(b["createdAt"] ?? "") ?? DateTime(0);
          return bDate.compareTo(aDate);
        });

        setState(() {
          orders = data;
          filteredOrders = data;
        });
        debugPrint("✅ 결제내역 불러오기 성공 (${orders.length}개)");
      } else {
        debugPrint("❌ 결제내역 불러오기 실패: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("❌ 결제내역 불러오기 중 예외: $e");
    }
  }

  void _applySearch(String query) {
    setState(() {
      _searchQuery = query;
      filteredOrders = orders.where((order) {
        final name =
        (order["product"]?["name"] ?? "").toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('📦 PaymentHistory userId = ${widget.userId}');
    if (widget.userId.isNotEmpty) {
      _fetchOrders();
    } else {
      debugPrint('❗ userId 비어 있어서 주문내역 요청 안 함');
    }
  }

  List<Widget> _buildGroupedOrderList() {
    Map<String, List<dynamic>> grouped = {};

    for (var order in filteredOrders) {
      final raw = order["createdAt"] ?? order["orderedAt"] ?? "";

      String date = "날짜 없음";
      if (raw is String && raw.isNotEmpty) {
        try {
          final parsed = DateTime.parse(raw);
          date =
          "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
        } catch (_) {}
      }

      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(order);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    List<Widget> widgets = [];
    for (var date in sortedDates) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            "📅 $date",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );

      for (var order in grouped[date]!) {
        widgets.add(_buildOrderCard(order));
      }
    }

    return widgets;
  }

  Widget _buildOrderCard(dynamic order) {
    final product = order["product"] ?? {};
    final payment = order["payment"] ?? {};

    final name = product["name"] ?? "상품명 없음";
    final category = product["category"] ?? "정보 없음";
    final count = product["quantity"] ?? 1;
    final price = product["price"] ?? 0;
    final img = product["image"] ?? "";
    final method = payment["method"] ?? "결제수단 없음";
    final total = payment["totalAmount"] ?? (price * count);
    final status = order["status"] ?? "결제완료";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: img != ""
                      ? DecorationImage(
                    image: NetworkImage(img),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: img == ""
                    ? const Icon(Icons.image_not_supported, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),

              // 정보들
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단: 상품명 + 상세보기
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserOrderDetailPage(order: order),
                              ),
                            );
                          },
                          child: const Text(
                            "상세정보 >",
                            style:
                            TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Text("$category / ${count}개"),
                    Text(
                      "₩$total",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "결제수단: $method",
                      style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: (status == "배송완료")
                          ? ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProductReviewPage(
                                  productId: product["_id"]),
                            ),
                          );
                          if (result == true) {
                            await _fetchOrders();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("리뷰가 등록되었습니다"),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF7CC),
                          foregroundColor: Colors.black,
                          elevation: 0,
                        ),
                        child: const Text("리뷰 작성하기"),
                      )
                          : Text(
                        status,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        title: const Text("주문내역", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onTap: () =>
                  setState(() => _showDateFilter = !_showDateFilter),
              onChanged: _applySearch,
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

          // 날짜 필터
          if (_showDateFilter)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _filterButton(
                        "일주일",
                        DateTime.now().subtract(const Duration(days: 7)),
                        DateTime.now(),
                      ),
                      _filterButton(
                        "한달",
                        DateTime.now().subtract(const Duration(days: 30)),
                        DateTime.now(),
                      ),
                      _filterButton(
                        "일년",
                        DateTime.now().subtract(const Duration(days: 365)),
                        DateTime.now(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _dateBox("시작일", _startDate, isStart: true),
                      _dateBox("종료일", _endDate, isStart: false),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _filterByDate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    child: const Text("검색하기"),
                  ),
                ],
              ),
            ),

          // 리스트
          Expanded(
            child: filteredOrders.isEmpty
                ? const Center(child: Text("결제내역이 없습니다."))
                : ListView(
              children: _buildGroupedOrderList(),
            ),
          ),
        ],
      ),
    );
  }
}