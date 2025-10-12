import 'dart:io';
import 'dart:convert'; // ✅ jsonEncode
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // ✅ http 요청

import 'admin_main_page.dart';
import 'hospital_approval_page.dart';
import 'user_manage_page.dart';
import 'product_page.dart';
import 'product.dart';

class ProductRegisterPage extends StatefulWidget {
  final Product? product; // ✅ 수정 모드일 때 전달되는 상품

  const ProductRegisterPage({super.key, this.product});

  @override
  State<ProductRegisterPage> createState() => _ProductRegisterPageState();
}

class _ProductRegisterPageState extends State<ProductRegisterPage> {
  final List<File> _images = [];
  final picker = ImagePicker();

  // ✅ 입력 컨트롤러
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _selectedCategory = "간식"; // 기본값

  @override
  void initState() {
    super.initState();

    // ✅ 수정 모드일 경우 기존 데이터 세팅
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descController.text = widget.product!.description;
      _qtyController.text = widget.product!.quantity.toString();
      _priceController.text = widget.product!.price.toString();
      _selectedCategory = widget.product!.category;
      _images.addAll(widget.product!.images.map((e) => File(e)));
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("사진은 최대 10개까지 등록할 수 있습니다.")),
      );
      return;
    }

    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  InputDecoration _inputDecoration(String hint, {String? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }

  /// ✅ 상품 등록/수정 함수
  Future<void> _saveProduct() async {
    final isEdit = widget.product != null;
    final url = isEdit
        ? Uri.parse("http://localhost:5000/products/${widget.product!.id}") // 수정
        : Uri.parse("http://localhost:5000/products"); // 등록

    final body = jsonEncode({
      "name": _nameController.text,
      "category": _selectedCategory,
      "description": _descController.text,
      "quantity": int.tryParse(_qtyController.text) ?? 0,
      "price": int.tryParse(_priceController.text) ?? 0,
      "images": _images.map((e) => e.path).toList(),
    });

    final response = isEdit
        ? await http.put(url, headers: {"Content-Type": "application/json"}, body: body)
        : await http.post(url, headers: {"Content-Type": "application/json"}, body: body);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? "상품이 수정되었습니다 ✅" : "상품이 등록되었습니다 ✅")),
      );
      Navigator.pop(context, true); // ✅ true 반환 → ProductPage 새로고침 트리거
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 실패: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null; // ✅ 수정 모드 체크

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: Text(isEdit ? "상품 수정" : "상품 등록", style: const TextStyle(color: Colors.black)),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 📷 사진 업로드
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._images.map((img) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        img,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: IconButton(
                        icon: const Icon(Icons.cancel,
                            color: Colors.red, size: 20),
                        onPressed: () {
                          setState(() {
                            _images.remove(img);
                          });
                        },
                      ),
                    ),
                  ],
                )),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.black),
                          Text("${_images.length}/10",
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// 카테고리
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("카테고리", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: const [
                      DropdownMenuItem(value: "간식", child: Text("간식")),
                      DropdownMenuItem(value: "사료", child: Text("사료")),
                      DropdownMenuItem(value: "용품", child: Text("용품")),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                    decoration: _inputDecoration(""),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// 상품명
            const Text("상품명", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration("상품명을 입력하세요"),
            ),
            const SizedBox(height: 16),

            /// 설명
            const Text("설명", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 6,
              decoration: _inputDecoration("상품 설명을 입력하세요"),
            ),
            const SizedBox(height: 16),

            /// 수량
            const Text("수량", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration("수량 입력", suffix: "개"),
            ),
            const SizedBox(height: 16),

            /// 판매가
            const Text("판매가", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration("가격 입력", suffix: "원"),
            ),
            const SizedBox(height: 30),

            /// ✅ 등록/수정 버튼
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _saveProduct,
                child: Text(isEdit ? "수정하기" : "등록하기",
                    style: const TextStyle(color: Colors.black)),
              ),
            ),
          ],
        ),
      ),

      /// ✅ 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const AdminMainPage()),
                  (route) => false,
            );
          }
          if (index == 1) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HospitalApprovalPage()),
                  (route) => false,
            );
          }
          if (index == 2) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const ProductPage()),
                  (route) => false,
            );
          }
          if (index == 3) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const UserManagePage()),
                  (route) => false,
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
}
