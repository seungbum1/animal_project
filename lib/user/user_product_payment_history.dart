import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_order_detail_page.dart'; // ✅ 상세정보 페이지 import
import 'user_product_review_page.dart';



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

  /// ✅ 날짜 표시 박스 위젯
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


  /// ✅ 날짜 필터에 따른 검색 적용
  void _filterByDate() {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      filteredOrders = orders.where((order) {
        final orderDate = DateTime.tryParse(order["orderedAt"] ?? "");
        if (orderDate == null) return false;
        return orderDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    });
  }

  /// ✅ 미니 달력 다이얼로그 (중앙 네모 달력)
  Future<void> _showMiniCalendarDialog(bool isStart) async {
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isStart ? "시작일 선택" : "종료일 선택", textAlign: TextAlign.center),
          content: SizedBox(
            width: 300,
            height: 300,
            child: CalendarDatePicker(
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              onDateChanged: (date) {
                selectedDate = date;
              },
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


  /// ✅ DB에서 결제내역 불러오기
  Future<void> _fetchOrders() async {
    final url =
    Uri.parse("http://127.0.0.1:5000/users/${widget.userId}/orders");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);

      // ✅ 최신 결제일순으로 정렬 (orderedAt 기준 내림차순)
      data.sort((a, b) {
        final dateA = DateTime.tryParse(a["orderedAt"] ?? "") ?? DateTime(0);
        final dateB = DateTime.tryParse(b["orderedAt"] ?? "") ?? DateTime(0);
        return dateB.compareTo(dateA); // 🔽 최신순
      });

      setState(() {
        orders = data;
        filteredOrders = data;
      });
      print("✅ 결제내역 불러오기 성공 (${orders.length}개)");
    } else {
      print("❌ 결제내역 불러오기 실패: ${res.body}");
    }
  }

  /// 🔍 검색 필터 적용
  void _applySearch(String query) {
    setState(() {
      _searchQuery = query;
      filteredOrders = orders.where((order) {
        final name = (order["name"] ?? "").toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  /// ✅ 날짜별로 결제내역 묶어서 그룹화
  List<Widget> _buildGroupedOrderList() {
    Map<String, List<dynamic>> groupedOrders = {};

    for (var order in filteredOrders) {
      final date = (order["orderedAt"] ?? "").substring(0, 10);
      groupedOrders.putIfAbsent(date, () => []);
      groupedOrders[date]!.add(order);
    }

    // 🔽 최신 날짜가 위로 오게 정렬
    final sortedDates = groupedOrders.keys.toList()
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
              color: Colors.black87,
            ),
          ),
        ),
      );

      for (var order in groupedOrders[date]!) {
        widgets.add(_buildOrderCard(order));
      }
    }

    return widgets;
  }

  Widget _buildOrderCard(dynamic order) {
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
              /// 🖼️ 상품 이미지
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: order["image"] != null
                      ? DecorationImage(
                    image: NetworkImage(order["image"]),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: order["image"] == null
                    ? const Icon(Icons.image_not_supported, color: Colors.grey)
                    : null,
              ),

              const SizedBox(width: 12),

              /// 🛍️ 상품 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ✅ 상품명 + 상세정보
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            order["name"] ?? "상품명 없음",
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
                                builder: (context) =>
                                    UserOrderDetailPage(order: order),
                              ),
                            );
                          },
                          child: const Text(
                            "상세정보 >",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    /// ✅ 카테고리 / 수량
                    Row(
                      children: [
                        Text(order["category"] ?? "정보 없음"),
                        const SizedBox(width: 4),
                        const Text("/"),
                        const SizedBox(width: 4),
                        Text("${order["quantity"] ?? 1}개"),
                      ],
                    ),

                    /// ✅ 금액
                    Text(
                      "₩${order["totalAmount"] ?? ((order["price"] ?? 0) + 3000)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    /// ✅ 리뷰 버튼
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProductReviewPage(
                                productId: order["productId"],  // ✅ 서버 데이터에 productId 포함되어 있어야 함
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF7CC),
                          foregroundColor: Colors.black,
                          elevation: 0,
                        ),
                        child: const Text("리뷰 작성하기"),
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
          /// 🔍 검색창
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onTap: () => setState(() => _showDateFilter = !_showDateFilter), // ✅ 클릭 시 열기/닫기
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

          /// ✅ 날짜 필터 (검색창 클릭 시 표시)
          if (_showDateFilter)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _filterButton("일주일", DateTime.now().subtract(const Duration(days: 7)), DateTime.now()),
                      _filterButton("한달", DateTime.now().subtract(const Duration(days: 30)), DateTime.now()),
                      _filterButton("일년", DateTime.now().subtract(const Duration(days: 365)), DateTime.now()),
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

          /// 📦 결제내역 목록 (날짜별 그룹화)
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
