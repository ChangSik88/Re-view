import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'design.dart';
import 'diary_pages.dart' show openAnalysis;
import 'review_state.dart';

class RecordPlace {
  final String key, name;
  final LatLng point;
  final List<DiaryRecord> records;
  RecordPlace(this.key, this.name, this.point, this.records);
}

List<RecordPlace> recordPlaces(List<DiaryRecord> records) {
  final groups = <String, RecordPlace>{};
  final sorted = records.toList()..sort((a, b) => b.date.compareTo(a.date));
  for (final r in sorted) {
    if (r.routine != Routine.night || !r.hasLocation || r.content.isEmpty) {
      continue;
    }
    // Distinguish identically named places; group repeated visits within ~10m.
    final key =
        '${r.placeName!.trim()}|${r.latitude!.toStringAsFixed(4)}|${r.longitude!.toStringAsFixed(4)}';
    groups
        .putIfAbsent(
            key,
            () => RecordPlace(
                key, r.placeName!, LatLng(r.latitude!, r.longitude!), []))
        .records
        .add(r);
  }
  return groups.values.toList();
}

void openPlaces(BuildContext context, [String? selected]) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LocationMapPage(selected: selected)));

class LocationHomeCard extends StatelessWidget {
  const LocationHomeCard({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReviewState>();
    final places = recordPlaces(state.records);
    void open() {
      if (state.guest) {
        Navigator.pushNamed(context, '/login');
      } else {
        openPlaces(context);
      }
    }

    return Paper(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('위치',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            TextButton(
                onPressed: open,
                child: const Text('전체보기 ›', style: TextStyle(fontSize: 11)))
          ]),
          gap,
          Semantics(
              button: true,
              label: '장소별 기록 지도 열기',
              child: GestureDetector(
                  onTap: open,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                          height: 165,
                          child: places.isEmpty
                              ? const ColoredBox(
                                  color: lavender,
                                  child: Center(
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                        Icon(Icons.place_outlined,
                                            color: purple, size: 32),
                                        gap,
                                        Text('하루가 머문 곳을 남겨보세요',
                                            style: TextStyle(
                                                color: muted, fontSize: 12))
                                      ])))
                              : IgnorePointer(
                                  child: RecordMap(
                                      places: places.take(1).toList(),
                                      interactive: false)))))),
          if (places.isNotEmpty) ...[
            gap,
            PlaceThumbnails(
                places: places,
                compact: true,
                onSelect: (p) => openPlaces(context, p.key))
          ],
          gap,
          Text(
              state.guest
                  ? '로그인하고 장소별 하루 기록을 모아보세요.'
                  : '장소를 남긴 하루를 지도에서 모아보세요.',
              style: const TextStyle(color: muted, fontSize: 10)),
        ]));
  }
}

class PlaceThumbnails extends StatelessWidget {
  final List<RecordPlace> places;
  final ValueChanged<RecordPlace> onSelect;
  final bool compact;
  const PlaceThumbnails(
      {super.key,
      required this.places,
      required this.onSelect,
      this.compact = false});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: compact ? 100 : 140,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: places.length,
          separatorBuilder: (_, i) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final p = places[i];
            return InkWell(
                onTap: () => onSelect(p),
                child: SizedBox(
                    width: compact ? 100 : 105,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RecordImage(p.records.first.image,
                              height: compact ? 68 : 90, radius: 12),
                          const SizedBox(height: 5),
                          Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: compact ? 10 : 11,
                                  fontWeight: FontWeight.bold)),
                          if (!compact)
                            Text('기록 ${p.records.length}개',
                                style: const TextStyle(
                                    fontSize: 10, color: muted)),
                        ])));
          }));
}

class RecordMap extends StatefulWidget {
  final List<RecordPlace> places;
  final String? selected;
  final ValueChanged<RecordPlace>? onSelect;
  final ValueChanged<LatLng>? onPick;
  final LatLng? point;
  final MapController? controller;
  final bool interactive, loadTiles;
  const RecordMap(
      {super.key,
      this.places = const [],
      this.selected,
      this.onSelect,
      this.point,
      this.onPick,
      this.controller,
      this.interactive = true,
      this.loadTiles = true});
  @override
  State<RecordMap> createState() => _RecordMapState();
}

class _RecordMapState extends State<RecordMap> {
  bool failed = false;
  int revision = 0;
  @override
  Widget build(BuildContext context) {
    final points = widget.places.map((p) => p.point).toList();
    return Stack(children: [
      FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
              initialCenter: widget.point ??
                  (points.isEmpty ? const LatLng(36.4, 127.8) : points.first),
              initialZoom: widget.point != null || points.isNotEmpty ? 14 : 6,
              initialCameraFit: widget.point == null && points.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(60),
                      maxZoom: 15)
                  : null,
              interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none),
              onTap: (_, p) => widget.onPick?.call(p)),
          children: [
            if (widget.loadTiles)
              TileLayer(
                  key: ValueKey(revision),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.frontend/Re-view',
                  maxNativeZoom: 19,
                  errorTileCallback: (_, __, ___) {
                    if (!failed) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => failed = true);
                      });
                    }
                  }),
            MarkerLayer(markers: [
              for (final p in widget.places)
                Marker(
                    point: p.point,
                    width: 60,
                    height: 88,
                    child: Semantics(
                        button: true,
                        label: '${p.name} 기록 ${p.records.length}개',
                        child: GestureDetector(
                            onTap: () => widget.onSelect?.call(p),
                            child: Column(children: [
                              Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                      color: widget.selected == p.key
                                          ? purple
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 6)
                                      ]),
                                  child: Column(children: [
                                    RecordImage(p.records.first.image,
                                        height: 45, radius: 9),
                                    Text('기록 ${p.records.length}',
                                        maxLines: 1,
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: widget.selected == p.key
                                                ? Colors.white
                                                : purple)),
                                  ])),
                              Icon(Icons.arrow_drop_down,
                                  size: 14,
                                  color: widget.selected == p.key
                                      ? purple
                                      : Colors.white)
                            ])))),
              if (widget.point != null && widget.onPick != null)
                Marker(
                    point: widget.point!,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_pin,
                        color: purple, size: 44)),
            ]),
          ]),
      Positioned(
          bottom: 0,
          right: 0,
          child: Material(
              color: Colors.white70,
              child: InkWell(
                  onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright')),
                  child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Text('© OpenStreetMap',
                          style: TextStyle(fontSize: 10)))))),
      if (failed)
        Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Material(
                color: Colors.white,
                child: InkWell(
                    onTap: () => setState(() {
                          failed = false;
                          revision++;
                        }),
                    child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('지도를 불러오지 못했어요 · 탭하여 재시도',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: purple)))))),
    ]);
  }
}

class LocationMapPage extends StatefulWidget {
  final String? selected;
  final bool loadTiles;
  const LocationMapPage({super.key, this.selected, this.loadTiles = true});
  @override
  State<LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  final controller = MapController();
  late String? selected = widget.selected;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void select(RecordPlace p) {
    setState(() => selected = p.key);
    controller.move(p.point, 15);
  }

  @override
  Widget build(BuildContext context) {
    final places = recordPlaces(context.watch<ReviewState>().records);
    final chosen = places.where((p) => p.key == selected).firstOrNull;
    return Scaffold(
        backgroundColor: canvas,
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final panelHeight = (chosen == null ? 300.0 : 322.0)
              .clamp(0.0, constraints.maxHeight * .55);
          return Column(children: [
            Expanded(
                child: Stack(children: [
              RecordMap(
                  controller: controller,
                  places: places,
                  selected: selected,
                  onSelect: select,
                  loadTiles: widget.loadTiles,
                  point: chosen?.point),
              Positioned(
                  top: 16,
                  left: 20,
                  right: 20,
                  child: Row(children: [
                    Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                            tooltip: '뒤로',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.chevron_left))),
                    const SizedBox(width: 12),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24)),
                        child: const Text('장소별 기록',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold))),
                  ])),
            ])),
            Container(
                height: panelHeight,
                width: double.infinity,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28))),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: chosen == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const Text('내가 머문 장소',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                gap,
                                Text(
                                    '${places.length}개 장소에 담긴 ${places.fold<int>(0, (n, p) => n + p.records.length)}개의 하루',
                                    style: const TextStyle(
                                        fontSize: 12, color: muted)),
                                gap,
                                if (places.isNotEmpty)
                                  PlaceThumbnails(
                                      places: places, onSelect: select)
                                else
                                  const Text('하루 리포트에서 장소를 추가하면\n이곳에 기록이 모여요.',
                                      style: TextStyle(color: muted)),
                                TextButton.icon(
                                    onPressed: () => chooseRecord(context),
                                    icon: const Icon(
                                        Icons.add_location_alt_outlined),
                                    label: const Text('기록에 장소 추가')),
                              ])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(chosen.name,
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold))),
                                  IconButton(
                                      tooltip: '모든 장소 보기',
                                      onPressed: () =>
                                          setState(() => selected = null),
                                      icon: const Icon(Icons.close))
                                ]),
                                Text('기록 ${chosen.records.length}개 · 나이트루틴',
                                    style: const TextStyle(
                                        fontSize: 12, color: muted)),
                                gap,
                                for (final r in chosen.records)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: InkWell(
                                          onTap: () => openAnalysis(context, r),
                                          child: Row(children: [
                                            SizedBox(
                                                width: 76,
                                                child: RecordImage(r.image,
                                                    height: 76, radius: 12)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(r.title,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13)),
                                                  Text(r.dateLabel,
                                                      style: const TextStyle(
                                                          color: muted,
                                                          fontSize: 11)),
                                                  Text(r.tags.join(' · '),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color: purple,
                                                          fontSize: 10)),
                                                ]))
                                          ]))),
                                PrimaryButton('리포트 보기',
                                    height: 44,
                                    onPressed: () => openAnalysis(
                                        context, chosen.records.first)),
                              ]))),
          ]);
        })));
  }

  Future<void> chooseRecord(BuildContext context) async {
    final records = context
        .read<ReviewState>()
        .forRoutine(Routine.night)
        .where((r) => r.content.isNotEmpty)
        .toList();
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 루미와 대화하고 하루 리포트를 저장해 주세요.')));
      return;
    }
    final record = await showModalBottomSheet<DiaryRecord>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
              const ListTile(title: Text('장소를 남길 하루를 선택해 주세요')),
              for (final r in records)
                ListTile(
                    title: Text(r.title),
                    subtitle:
                        Text('${r.dateLabel} · ${r.placeName ?? "장소 없음"}'),
                    onTap: () => Navigator.pop(context, r)),
            ])));
    if (record != null && context.mounted) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LocationEditorPage(record: record)));
    }
  }
}

class RecordLocationButton extends StatelessWidget {
  final DiaryRecord record;
  const RecordLocationButton({super.key, required this.record});
  @override
  Widget build(BuildContext context) {
    context.watch<ReviewState>();
    return OutlinedButton.icon(
        icon: const Icon(Icons.place_outlined),
        label: Text(
            record.placeName == null
                ? '이 하루에 장소 추가'
                : '${record.placeName} · 수정',
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LocationEditorPage(record: record))));
  }
}

class LocationEditorPage extends StatefulWidget {
  final DiaryRecord record;
  final bool loadTiles;
  final Future<LatLng> Function()? locate;
  const LocationEditorPage(
      {super.key, required this.record, this.loadTiles = true, this.locate});
  @override
  State<LocationEditorPage> createState() => _LocationEditorPageState();
}

class _LocationEditorPageState extends State<LocationEditorPage> {
  final controller = MapController();
  late final name = TextEditingController(text: widget.record.placeName);
  late LatLng? point = widget.record.hasLocation
      ? LatLng(widget.record.latitude!, widget.record.longitude!)
      : null;
  bool busy = false, locating = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      LatLng result;
      if (widget.locate != null) {
        result = await widget.locate!();
      } else {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw Exception('disabled');
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          throw Exception('denied');
        }
        final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 15)));
        result = LatLng(position.latitude, position.longitude);
      }
      if (!mounted) return;
      setState(() => point = result);
      controller.move(result, 16);
    } catch (_) {
      if (mounted) {
        setState(() => error = '현재 위치를 확인하지 못했어요. 지도에서 장소를 직접 눌러 주세요.');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> save({bool remove = false}) async {
    if (!remove && (point == null || name.text.trim().isEmpty)) {
      setState(() => error = '지도에서 위치를 선택하고 장소 이름을 입력해 주세요.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<ReviewState>().saveLocation(
          widget.record,
          remove ? null : name.text.trim(),
          remove ? null : point!.latitude,
          remove ? null : point!.longitude);
      if (mounted) {
        setState(() => busy = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '장소를 저장하지 못했어요. 연결을 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Scaffold(
          appBar: AppBar(
              title: const Text('하루의 장소'), automaticallyImplyLeading: !busy),
          body: SafeArea(
              child: Column(children: [
            Expanded(
                child: RecordMap(
                    controller: controller,
                    point: point,
                    loadTiles: widget.loadTiles,
                    onPick: busy ? null : (p) => setState(() => point = p))),
            Flexible(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('실제로 있었던 장소를 지도에서 눌러 주세요.',
                              style: TextStyle(fontSize: 13)),
                          TextButton.icon(
                              onPressed: busy || locating ? null : locate,
                              icon: const Icon(Icons.my_location),
                              label:
                                  Text(locating ? '현재 위치 확인 중…' : '현재 위치로 이동')),
                          TextField(
                              controller: name,
                              enabled: !busy,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                  labelText: '장소 이름',
                                  hintText: '예: 친구와 갔던 카페')),
                          const Text(
                              '현재 위치는 제안이에요. 그날 방문한 곳이 맞는지 확인한 뒤 저장해 주세요.',
                              style: TextStyle(fontSize: 11, color: muted)),
                          if (error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(error!,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 12))),
                          gap,
                          FilledButton(
                              onPressed: busy || locating ? null : () => save(),
                              child: Text(busy ? '저장 중…' : '이 장소 저장')),
                          if (widget.record.hasLocation)
                            TextButton(
                                onPressed: busy || locating
                                    ? null
                                    : () => save(remove: true),
                                child: const Text('장소 삭제')),
                        ]))),
          ]))));
}
