import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StoreScreen extends StatefulWidget {
  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String _selectedCategory = '다이어리';
  Map<String, List<dynamic>> _storeData = {'다이어리': [], '악세서리': [], '기타': []};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStoreItems();
  }

  Future<void> _fetchStoreItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      final url = Uri.parse('http://13.209.97.107:8000/item/list');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _storeData['다이어리'] = data['result']['다이어리'] ?? [];
          _storeData['악세서리'] = data['result']['악세서리'] ?? [];
          _storeData['기타'] = data['result']['기타'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.popUntil(context, ModalRoute.withName('/home'));
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/dream_list');
    } else if (index == 3) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('아직 준비 중인 기능입니다! 🚀')));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> currentItems = _storeData[_selectedCategory] ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Store',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () =>
              Navigator.popUntil(context, ModalRoute.withName('/home')),
        ),
        actions: [
          Icon(Icons.shopping_cart_outlined, color: Colors.black),
          SizedBox(width: 20),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _buildCategoryButton('다이어리'),
                SizedBox(width: 12),
                _buildCategoryButton('악세서리'),
                SizedBox(width: 12),
                _buildCategoryButton('기타'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: Color(0xFF8F6CFF)))
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: currentItems.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(currentItems[index]);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF4589FE),
        unselectedItemColor: Colors.black,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈 화면'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: 'AI-채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: '스토어'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String title) {
    bool isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF030213) : const Color(0xFFECEEF2),
          borderRadius: BorderRadius.circular(6.75),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF030213),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    String rawUrl = item['image_url'] ?? "https://placehold.co/400x200";
    String safeImageUrl = rawUrl.replaceAll('localhost', '13.209.97.107');

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/store_detail',
            arguments: item['item_id']);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        height: 206, // 전체 카드 높이
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(12.75),
        ),
        child: Row(
          children: [
            // 🚀 이미지 영역: BoxFit.cover를 써서 비율이 안 맞아도 찌그러지지 않고 꽉 차게 변경!
            Container(
              width: 146,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.75),
                    bottomLeft: Radius.circular(12.75)),
                image: DecorationImage(
                  image: NetworkImage(safeImageUrl),
                  fit: BoxFit.cover, // 변경됨
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['item_name'] ?? '상품명',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('${item['price'] ?? 0}원',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Column(
                      children: [
                        _buildCardButton('상품 미리보기', Color(0xFF030213)),
                        SizedBox(height: 8),
                        _buildCardButton('상품 구매', Color(0xFF0F00FF)),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCardButton(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6.75)),
      child: Center(
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}
