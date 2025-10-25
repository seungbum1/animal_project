import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'admin_main_page.dart';
import 'hospital_approval_page.dart';
import 'user_manage_page.dart';
import 'product_page.dart';
import 'product.dart';

class ProductRegisterPage extends StatefulWidget {
  final Product? product;

  const ProductRegisterPage({super.key, this.product});

  @override
  State<ProductRegisterPage> createState() => _ProductRegisterPageState();
}

class _ProductRegisterPageState extends State<ProductRegisterPage> {
  final List<dynamic> _images = []; // ✅ File 또는 URL(String) 모두 저장 가능
  final picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _selectedCategory = "간식";
  late final String baseUrl;

  @override
  void initState() {
    super.initState();

    // ✅ 플랫폼 감지 (에뮬레이터 vs 데스크탑)
    baseUrl = Platform.isAndroid ? "http://10.0.2.2:5000" : "http://127.0.0.1:5000";

    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descController.text = widget.product!.description;
      _qtyController.text = widget.product!.quantity.toString();
      _priceController.text = widget.product!.price.toString();
      _selectedCategory = widget.product!.category;

      // ✅ 기존 이미지 URL 추가
      _images.addAll(widget.product!.images);
    }
  }

  /// ✅ 갤러리에서 이미지 추가
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

  /// ✅ 서버로 이미지 업로드
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final uri = Uri.parse("$baseUrl/upload");
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      var response = await request.send();

      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        final data = jsonDecode(resBody);
        final fullUrl = "$baseUrl${data['imageUrl']}";
        print("✅ 업로드 완료: $fullUrl");
        return fullUrl;
      } else {
        print("❌ 업로드 실패: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ 업로드 오류: $e");
      return null;
    }
  }

  /// ✅ 상품 등록 / 수정
  Future<void> _saveProduct() async {
    final isEdit = widget.product != null;
    final url = isEdit
        ? Uri.parse("$baseUrl/products/${widget.product!.id}")
        : Uri.parse("$baseUrl/products");

    List<String> uploadedUrls = [];

    // ✅ 로컬 파일만 업로드 (이미 URL인 건 그대로 유지)
    for (final img in _images) {
      if (img is File) {
        final imageUrl = await _uploadImage(img);
        if (imageUrl != null) uploadedUrls.add(imageUrl);
      } else if (img is String && img.startsWith('http')) {
        uploadedUrls.add(img); // 기존 서버 이미지 유지
      }
    }

    final body = jsonEncode({
      "name": _nameController.text.trim(),
      "category": _selectedCategory,
      "description": _descController.text.trim(),
      "quantity": int.tryParse(_qtyController.text) ?? 0,
      "price": int.tryParse(_priceController.text) ?? 0,
      "images": uploadedUrls,
    });

    try {
      final response = isEdit
          ? await http.put(url, headers: {"Content-Type": "application/json"}, body: body)
          : await http.post(url, headers: {"Content-Type": "application/json"}, body: body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? "상품이 수정되었습니다 ✅" : "상품이 등록되었습니다 ✅")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 실패: ${response.body}")),
        );
      }
    } catch (e) {
      print("❌ 상품 저장 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 연결 실패: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7CC),
        elevation: 0,
        title: Text(isEdit ? "상품 수정" : "상품 등록",
            style: const TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._images.map((img) {
                  final isNetwork = img is String && img.startsWith('http');
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isNetwork
                            ? Image.network(
                          img,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                  color: Colors.grey[300],
                                  width: 80,
                                  height: 80,
                                  child:
                                  const Icon(Icons.broken_image)),
                        )
                            : Image.file(
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
                          onPressed: () => setState(() => _images.remove(img)),
                        ),
                      ),
                    ],
                  );
                }),
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

            _buildDropdown(),
            _buildTextField("상품명", _nameController, "상품명을 입력하세요"),
            _buildTextField("설명", _descController, "상품 설명을 입력하세요", maxLines: 6),
            _buildTextField("수량", _qtyController, "수량 입력", suffix: "개"),
            _buildTextField("판매가", _priceController, "가격 입력", suffix: "원"),

            const SizedBox(height: 30),

            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CC),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDropdown() {
    return Row(
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
            onChanged: (value) => setState(() => _selectedCategory = value!),
            decoration: _inputDecoration(""),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      String hint,
      {String? suffix, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType:
            suffix != null ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            decoration: _inputDecoration(hint, suffix: suffix),
          ),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNav() {
    return BottomNavigationBar(
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      currentIndex: 2,
      onTap: (index) {
        Widget next;
        switch (index) {
          case 0:
            next = const AdminMainPage();
            break;
          case 1:
            next = const HospitalApprovalPage();
            break;
          case 2:
            next = const ProductPage();
            break;
          case 3:
            next = const UserManagePage();
            break;
          default:
            return;
        }
        Navigator.pushAndRemoveUntil(
            context, MaterialPageRoute(builder: (_) => next), (route) => false);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "메인화면"),
        BottomNavigationBarItem(icon: Icon(Icons.verified), label: "병원승인"),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "상품"),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "사용자 관리"),
      ],
    );
  }
}
