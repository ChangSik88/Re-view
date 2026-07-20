import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/session_service.dart';
import '../../services/store_service.dart';

class StoreDetailScreen extends StatefulWidget {
  @override
  _StoreDetailScreenState createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  int? _itemId;
  Map<String, dynamic>? _itemData;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var args = ModalRoute.of(context)?.settings.arguments;
    if (args != null) {
      _itemId = int.tryParse(args.toString());
      if (_itemId != null) {
        _fetchItemDetail();
      }
    }
  }

  Future<void> _fetchItemDetail() async {
    try {
      final result = await storeService.getItemDetail(_itemId!);
      if (!mounted) return;
      setState(() {
        _itemData = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _handlePurchase() {
    if (_itemId.toString() == '1') {
      _showDiarySelectionDialog();
    } else {
      _showPurchaseCompleteDialog();
    }
  }

  void _showDiarySelectionDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');

    List<dynamic> sessionList = [];
    try {
      sessionList = await sessionService.getAllSessions(userId);
    } catch (e) {
      sessionList = [];
    }

    if (!mounted) return;

    Set<int> selectedRoomIds = {};
    bool isSortLatest = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // 🚀 명확한 Context 분리
        return StatefulBuilder(
          builder: (context, setDialogState) {
            sessionList.sort((a, b) {
              DateTime dateA =
                  DateTime.tryParse(a['updated_at'] ?? '1970-01-01') ??
                      DateTime.now();
              DateTime dateB =
                  DateTime.tryParse(b['updated_at'] ?? '1970-01-01') ??
                      DateTime.now();
              return isSortLatest
                  ? dateB.compareTo(dateA)
                  : dateA.compareTo(dateB);
            });

            bool isValid =
                selectedRoomIds.length >= 2 && selectedRoomIds.length <= 6;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 304,
                height: 559,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                          color: Color(0xFFD3D3D3),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(15))),
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 14),
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.pop(dialogContext), // 🚀 명확하게 다이얼로그만 닫기
                        child: Icon(Icons.close, size: 26),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('날짜 선택',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w400)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildSortButton('최신순', isSortLatest, () {
                            setDialogState(() => isSortLatest = true);
                          }),
                          SizedBox(width: 8),
                          _buildSortButton('오래된 순', !isSortLatest, () {
                            setDialogState(() => isSortLatest = false);
                          }),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sessionList.length,
                        itemBuilder: (context, index) {
                          final session = sessionList[index];
                          final int roomId = session['room_id'];
                          final bool isSelected =
                              selectedRoomIds.contains(roomId);

                          String rawDate = session['updated_at'] ?? '';
                          String formattedDate = rawDate.length >= 10
                              ? rawDate.substring(0, 10).replaceAll('-', '.')
                              : rawDate;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(formattedDate,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w300)),
                                      Text(session['title'] ?? '제목 없음',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      isSelected
                                          ? selectedRoomIds.remove(roomId)
                                          : selectedRoomIds.add(roomId);
                                    });
                                  },
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: Color(0xFF8A38F5),
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _showPreviewOverlay(roomId),
                                  child: Icon(Icons.arrow_forward_ios,
                                      size: 18, color: Colors.grey),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: _buildDialogButton('취소', true),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (isValid) {
                                Navigator.pop(dialogContext);
                                _showPurchaseCompleteDialog();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('다이어리는 2개에서 6개 사이로 선택해주세요!')),
                                );
                              }
                            },
                            child: _buildDialogButton('선택 완료', isValid),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortButton(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 55,
        height: 24,
        decoration: BoxDecoration(
          color: isActive ? Colors.black : const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
                color: isActive ? Colors.white : Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton(String text, bool isActive) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? Color(0xFFE6E6E6) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: isActive ? Colors.grey : Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: Text(text,
          style: TextStyle(
              fontSize: 18, color: isActive ? Colors.black : Colors.grey)),
    );
  }

  // 💡 [핵심 수정] 멈춤 현상(Freeze) 방지 및 안전장치 풀가동!
  void _showPreviewOverlay(int roomId) async {
    // 1. 데이터를 가져오는 동안 멈춘 것처럼 보이지 않게 로딩 창을 먼저 띄웁니다!
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingCtx) {
        return Center(
            child: CircularProgressIndicator(color: Color(0xFF8F6CFF)));
      },
    );

    String content = "작성된 일기 내용이 없습니다.";
    String imageUrl = "https://placehold.co/400x300?text=No+Image";

    try {
      final result = await sessionService.getSession(roomId);

      if (result != null) {
        if (result['content'] != null &&
            result['content'].toString().trim().isNotEmpty) {
          content = result['content'];
        }
        if (result['image_url'] != null &&
            result['image_url'].toString().trim().isNotEmpty) {
          imageUrl = result['image_url']
              .toString()
              .replaceAll('localhost', '13.209.97.107');
        }
      }
    } catch (e) {
      // 미리보기 실패 시 위에서 정한 기본 안내 문구를 그대로 사용
    }

    if (!mounted) return;

    // 2. 데이터 가져오기 완료되면 로딩 창 닫기
    Navigator.pop(context);

    // 3. 실제 미리보기 창 띄우기 (별도의 overlayCtx 부여로 닫기 버튼 충돌 방지)
    showDialog(
      context: context,
      builder: (BuildContext overlayCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('일기 미리보기', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                    // 🚀 이미지 주소가 깨져 있어도 앱이 뻗지 않도록 엑스박스 처리!
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 180,
                        color: Colors.grey[300],
                        child: Icon(Icons.broken_image,
                            color: Colors.grey[500], size: 50),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                Text(content, style: TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(overlayCtx), // 🚀 오직 이 미리보기 창만 정확히 닫음!
              child: Text('닫기',
                  style: TextStyle(
                      color: Color(0xFF8A38F5), fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }

  void _showPurchaseCompleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext completeCtx) {
        // 🚀 Context 충돌 방지
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 304,
            height: 330,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                      color: Color(0xFFD3D3D3),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(15))),
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(completeCtx); // 팝업 닫기
                      Navigator.pop(context); // 스토어 화면으로 나가기
                    },
                    child: Icon(Icons.close, size: 26),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('구매 완료!',
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _itemData == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String rawUrl = _itemData!['image_url'] ?? "https://placehold.co/400";
    String safeImageUrl = rawUrl.replaceAll('localhost', '13.209.97.107');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 220,
                    decoration:
                        BoxDecoration(borderRadius: BorderRadius.circular(10)),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(
                      safeImageUrl,
                      fit: BoxFit.cover,
                      // 🚀 상세 화면 메인 이미지도 안전하게 에러 방어!
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.broken_image,
                            color: Colors.grey[500], size: 50),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(_itemData!['item_name'] ?? '',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('${_itemData!['price'] ?? 0}원',
                      style: TextStyle(fontSize: 18)),
                  SizedBox(height: 24),
                  Text('상품 정보',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text(_itemData!['headline'] ?? '',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                  SizedBox(height: 16),
                  Text(_itemData!['description'] ?? '',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          height: 1.6)),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: Colors.white,
          child: GestureDetector(
            onTap: _handlePurchase,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                  color: Color(0xFF0F00FF).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text('상품 구매',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
