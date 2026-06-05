import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  String _selectedCategory = '다이어리';
  Map<String, List<dynamic>> _storeData = {'다이어리': [], '악세서리': [], '기타': []};
  bool _isStoreLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStorePreview();
  }

  Future<void> _fetchStorePreview() async {
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
          _isStoreLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isStoreLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.pushNamed(context, '/dream_list');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/store');
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
      body: SafeArea(
        child: Column(
          children: [
            // --- 헤더 ---
            Container(
              width: double.infinity,
              height: 56,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: 24),
                  Text('AI-Diary',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: _logout,
                    child: Icon(Icons.logout_rounded, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // --- 본문 ---
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🚀 [원상 복구 완료] 무진님의 오리지널 둥근 사각형(circular: 20) 배너입니다!
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x338EC5FF), Color(0x33DAB2FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(20), // 💡 원래의 예쁜 모서리로 복구!
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // 💡 원래의 왼쪽 정렬 복구!
                        children: [
                          Text('지금 시작하세요',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('당신의 꿈 이야기를 말해보세요',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 24),
                          // 🚀 클릭 시 새로운 '루틴 선택 화면'으로 잘 넘어갑니다!
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, '/routine_select'),
                              child: Container(
                                width: 192,
                                height: 54,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    Color(0xB2E900FF),
                                    Color(0xE5FC61FF)
                                  ]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '오늘 일 기록하기',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 40),

                    // --- 스토어 영역 ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('스토어 인기 상품',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/store'),
                          child: Text('더보기 >',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14)),
                        )
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        _buildCategoryTab('다이어리'),
                        SizedBox(width: 12),
                        _buildCategoryTab('악세서리'),
                        SizedBox(width: 12),
                        _buildCategoryTab('기타'),
                      ],
                    ),
                    SizedBox(height: 20),
                    _isStoreLoading
                        ? Center(
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                    color: Color(0xFF8F6CFF))))
                        : currentItems.isEmpty
                            ? Center(
                                child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text("해당 카테고리에 상품이 없습니다.",
                                        style: TextStyle(color: Colors.grey))))
                            : SizedBox(
                                height: 210,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: currentItems.length,
                                  itemBuilder: (context, index) {
                                    return _buildProductCard(
                                        currentItems[index]);
                                  },
                                ),
                              ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
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

  Widget _buildCategoryTab(String title) {
    bool isActive = _selectedCategory == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = title),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFF030213) : Color(0xFFECEEF2),
          borderRadius: BorderRadius.circular(6.75),
        ),
        child: Text(
          title,
          style: TextStyle(
              color: isActive ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    String rawUrl = item['image_url'] ?? "https://placehold.co/150";
    String safeImageUrl = rawUrl.replaceAll('localhost', '13.209.97.107');

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/store_detail',
          arguments: item['item_id']),
      child: Container(
        width: 149,
        margin: EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(12.75)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12.75)),
                image: DecorationImage(
                    image: NetworkImage(safeImageUrl), fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['item_name'] ?? '상품명',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Text('${item['price'] ?? 0}원',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
