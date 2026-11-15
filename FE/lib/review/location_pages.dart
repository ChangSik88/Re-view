import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'design.dart';
import 'review_state.dart';

/// 같은 장소명으로 모은 나이트루틴 기록 묶음. 지도 마커 하나가 이 묶음 하나다.
class Place {
  final String name;
  final List<DiaryRecord> records; // 최신순
  Place(this.name, this.records);
  LatLng get point => LatLng(records.first.latitude!, records.first.longitude!);
}

const _unnamedPlace = '이름 없는 장소';

/// 위치가 있는 나이트루틴 기록만 장소명 기준으로 묶는다.
List<Place> placesOf(ReviewState state) {
  final groups = <String, List<DiaryRecord>>{};
  for (final r in state.forRoutine(Routine.night).where((r) => r.hasLocation)) {
    groups
        .putIfAbsent(
            r.placeName.isEmpty ? _unnamedPlace : r.placeName, () => [])
        .add(r);
  }
  return groups.entries.map((e) => Place(e.key, e.value)).toList();
}

String emotionFlow(DiaryRecord r) => r.tags.take(3).join(' → ');

class PlaceMap extends StatelessWidget {
  final List<Place> places;
  final Place? selected;
  final ValueChanged<Place>? onSelect;
  final bool interactive;
  const PlaceMap(
      {super.key,
      required this.places,
      this.selected,
      this.onSelect,
      this.interactive = true});

  @override
  Widget build(BuildContext context) {
    final points = places.map((p) => p.point).toList();
    return FlutterMap(
        options: MapOptions(
            initialCenter:
                points.isEmpty ? const LatLng(37.5665, 126.978) : points.first,
            initialZoom: points.isEmpty ? 11 : 15,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: interactive
                        ? const EdgeInsets.fromLTRB(56, 120, 56, 380)
                        : const EdgeInsets.fromLTRB(36, 40, 36, 40))
                : null,
            interactionOptions: InteractionOptions(
                flags:
                    interactive ? InteractiveFlag.all : InteractiveFlag.none)),
        children: [
          TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.frontend',
              errorTileCallback: (_, __, ___) {}),
          MarkerLayer(
              markers: places
                  .map((place) => Marker(
                      point: place.point,
                      width: interactive ? 60 : 42,
                      height: interactive ? 72 : 50,
                      child: GestureDetector(
                          onTap:
                              onSelect == null ? null : () => onSelect!(place),
                          child: _PlaceMarker(
                              place: place,
                              selected: place == selected,
                              compact: !interactive))))
                  .toList()),
          if (interactive)
            const Align(
                alignment: Alignment.topRight,
                child: Padding(
                    padding: EdgeInsets.only(top: 64, right: 8),
                    child: Text('© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 9, color: muted)))),
        ]);
  }
}

class _PlaceMarker extends StatelessWidget {
  final Place place;
  final bool selected, compact;
  const _PlaceMarker(
      {required this.place, required this.selected, this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(compact ? 3 : 4),
      decoration: BoxDecoration(
          color: selected ? purple : Colors.white,
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 6)
          ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: compact ? 30 : 44,
            height: compact ? 30 : 44,
            child: RecordImage(place.records.first.image, radius: 6)),
        const SizedBox(height: 2),
        Text('기록 ${place.records.length}',
            style: TextStyle(
                fontSize: compact ? 8 : 9,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : purple)),
      ]));
}

/// 홈의 '위치' 카드. 장소를 남긴 나이트루틴 기록을 작은 지도와 썸네일로 보여준다.
class LocationCard extends StatelessWidget {
  const LocationCard({super.key});
  @override
  Widget build(BuildContext context) {
    final places = placesOf(context.watch<ReviewState>());
    void open() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LocationMapPage()));
    return Paper(
        radius: 20,
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('위치',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            InkWell(
                onTap: open,
                child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('전체보기 ›',
                        style: TextStyle(fontSize: 12, color: purple)))),
          ]),
          gap,
          if (places.isEmpty)
            Container(
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: lavender, borderRadius: BorderRadius.circular(16)),
                child: const Text('아직 장소를 남긴 하루가 없어요.',
                    style: TextStyle(fontSize: 12, color: muted)))
          else ...[
            GestureDetector(
                onTap: open,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                        height: 165,
                        child: IgnorePointer(
                            child: PlaceMap(
                                places: places, interactive: false))))),
            gap,
            Row(
                children: places
                    .take(3)
                    .map((p) => Expanded(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _PlaceThumb(place: p, height: 80))))
                    .toList()),
          ],
          gap,
          const Text('장소를 남긴 하루를 지도에서 모아보세요. · © OpenStreetMap contributors',
              style: TextStyle(fontSize: 11, color: muted)),
        ]));
  }
}

class _PlaceThumb extends StatelessWidget {
  final Place place;
  final double height;
  final VoidCallback? onTap;
  const _PlaceThumb({required this.place, required this.height, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RecordImage(place.records.first.image, height: height, radius: 12),
        const SizedBox(height: 6),
        Text(place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        Text('기록 ${place.records.length}개',
            style: const TextStyle(fontSize: 11, color: muted)),
      ]));
}

/// 전체 지도. 마커를 누르면 아래 패널이 그 장소의 기록으로 바뀐다.
class LocationMapPage extends StatefulWidget {
  const LocationMapPage({super.key});
  @override
  State<LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  String? selectedName;

  @override
  Widget build(BuildContext context) {
    final places = placesOf(context.watch<ReviewState>());
    final selected = places.where((p) => p.name == selectedName).firstOrNull;
    return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(children: [
          Positioned.fill(
              child: PlaceMap(
                  places: places,
                  selected: selected,
                  onSelect: (p) => setState(() => selectedName = p.name))),
          SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(children: [
                    Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                            tooltip: '뒤로',
                            onPressed: () => goBack(context),
                            icon: const Icon(Icons.chevron_left))),
                    const SizedBox(width: 10),
                    Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        elevation: 2,
                        child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            child: Text('장소별 기록',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)))),
                  ]))),
          Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .42),
                  child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28))),
                      child: SingleChildScrollView(
                          child: selected == null
                              ? _placeList(places)
                              : _placeDetail(selected)))))
        ]));
  }

  Widget _placeList(List<Place> places) {
    final total = places.fold(0, (sum, p) => sum + p.records.length);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('내가 머문 장소',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
          places.isEmpty
              ? '나이트루틴을 기록할 때 위치를 허용하면 장소가 모여요.'
              : '${places.length}개 장소에 담긴 $total개의 하루',
          style: const TextStyle(fontSize: 13, color: muted)),
      if (places.isNotEmpty) ...[
        gap,
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: places
                    .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                            width: 105,
                            child: _PlaceThumb(
                                place: p,
                                height: 90,
                                onTap: () =>
                                    setState(() => selectedName = p.name)))))
                    .toList())),
      ]
    ]);
  }

  Widget _placeDetail(Place place) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(place.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700))),
          TextButton(
              onPressed: () => setState(() => selectedName = null),
              child: const Text('전체 장소')),
        ]),
        Text('이 장소에서 남긴 기록 ${place.records.length}개',
            style: const TextStyle(fontSize: 13, color: muted)),
        gap,
        for (final r in place.records)
          InkWell(
              onTap: () => _openReport(r),
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    SizedBox(
                        width: 76,
                        height: 76,
                        child: RecordImage(r.image, radius: 8)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('${r.date.month}월 ${r.date.day}일 · 나이트루틴',
                              style:
                                  const TextStyle(fontSize: 12, color: muted)),
                          Text(r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          if (r.tags.isNotEmpty)
                            Text(emotionFlow(r),
                                style: const TextStyle(
                                    fontSize: 12, color: purple)),
                        ])),
                  ]))),
        PrimaryButton('리포트 보기 ›',
            onPressed: () => _openReport(place.records.first)),
      ]);

  void _openReport(DiaryRecord record) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => PlaceReportPage(record: record)));
}

/// 장소에서 남긴 하루 한 건의 리포트.
class PlaceReportPage extends StatelessWidget {
  final DiaryRecord record;
  const PlaceReportPage({super.key, required this.record});
  @override
  Widget build(BuildContext context) {
    const heading = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    return ReviewPage(
        background: canvas,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PageHeader(title: '장소별 기록', close: false),
          gap,
          Paper(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    '${record.date.month}월 ${record.date.day}일'
                    '${record.placeName.isEmpty ? '' : ' · ${record.placeName}'}',
                    style: const TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 6),
                Text(record.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                gap,
                RecordImage(record.image, height: 170, radius: 14),
                const SizedBox(height: 16),
                const Text('오늘 있었던 일', style: heading),
                const SizedBox(height: 6),
                Text(record.content,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
                if (record.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('주요 감정', style: heading),
                  const SizedBox(height: 6),
                  Text(emotionFlow(record),
                      style: const TextStyle(fontSize: 14, color: purple)),
                ],
              ])),
        ]));
  }
}
