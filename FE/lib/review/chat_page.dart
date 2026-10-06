import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import 'design.dart';
import 'diary_pages.dart';
import 'review_state.dart';
import 'story_details.dart';
import 'story_field_dialog.dart';
import 'voice_composer.dart';

class ReviewChatPage extends StatefulWidget {
  final ChatService? service;
  final Routine routine;
  final DiaryRecord? record;
  const ReviewChatPage(
      {super.key, required this.routine, this.record, this.service});
  @override
  State<ReviewChatPage> createState() => _ReviewChatPageState();
}

class _ReviewChatPageState extends State<ReviewChatPage> {
  ChatService get service => widget.service ?? chatService;
  final Set<String> editedFields = {};
  bool replying = false;
  String partialReply = '';
  final replyKey = GlobalKey();
  final conversationEndKey = GlobalKey();

  Future<void> _reveal(String reply) async {
    final letters = reply.characters.toList();
    for (var i = 0; i < letters.length; i += 3) {
      if (!mounted) return;
      setState(() => partialReply = letters.take(i + 3).join());
      _scrollDown();
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
    if (!mounted) return;
    setState(() {
      messages.add((text: reply, me: false));
      partialReply = '';
    });
  }

  void _applyDetails(Map? data) {
    if (data == null) return;
    String value(String key) => data[key] is String ? data[key] as String : '';
    if (!editedFields.contains('장소') && value('place').isNotEmpty) {
      place = value('place');
    }
    if (!editedFields.contains('감정') && value('emotions').isNotEmpty) {
      emotionText = value('emotions');
    }
    if (!editedFields.contains('생활') && value('situation').isNotEmpty) {
      life = value('situation');
    }
    if (!editedFields.contains('기타 메모') && value('memo').isNotEmpty) {
      memo = value('memo');
    }
    if (!editedFields.contains('등장인물') && data['characters'] is List) {
      characters.addAll((data['characters'] as List).whereType<String>());
    }
  }

  final input = TextEditingController();
  final scroll = ScrollController();
  final List<({String text, bool me})> messages = [];
  final Set<String> feelings = {}, characters = {};
  String place = '', life = '', memo = '', emotionText = '';
  StoryDetails get details => StoryDetails(
      place: place,
      characters: characters.join(', '),
      emotions:
          [emotionText, ...feelings].where((s) => s.isNotEmpty).join(', '),
      life: life,
      memo: memo);
  List<String> suggested = [];
  int session = 0;
  bool busy = false, historyLoading = false;
  String? error;
  String get _characterKey =>
      'characters_${context.read<ReviewState>().account}_${widget.routine.name}_$session';
  @override
  void initState() {
    super.initState();
    session = widget.record?.id ?? 0;
    _load();
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<ReviewState>();
    if (state.preview) {
      messages.add((
        text: widget.routine == Routine.morning
            ? '오늘은 어떤 꿈을 꾸셨나요?\n기억나는 장면부터 편하게 이야기해 주세요.'
            : '오늘 하루도 수고하셨어요!\n오늘 어떤 일이 있었나요?',
        me: false
      ));
      if (widget.record != null) {
        messages.add((text: widget.record!.content, me: true));
      }
      characters.addAll(['친구', '선생님']);
      suggested = ['불안', '기대', '설렘'];
      setState(() {});
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    characters.addAll(prefs.getStringList(_characterKey) ?? []);
    if (session == 0) {
      setState(() => messages.add((
            text: widget.routine == Routine.morning
                ? '오늘 꾼 꿈을 말해 주세요!'
                : '오늘 하루도 수고하셨어요! 어떤 일이 있었나요?',
            me: false
          )));
      return;
    }
    setState(() {
      historyLoading = true;
      error = null;
    });
    try {
      final history = await service
          .getHistory(session)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() {
        messages.clear();
        messages.addAll(history.map((m) => (
              text: '${m['text'] ?? m['content'] ?? ''}',
              me: m['is_me'] == true || '${m['role']}'.toLowerCase() == 'user'
            )));
      });
    } catch (_) {
      if (mounted) setState(() => error = '대화 내역을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => historyLoading = false);
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = replying ? replyKey : conversationEndKey;
        if (target.currentContext != null) {
          Scrollable.ensureVisible(target.currentContext!,
              alignment: 1, duration: const Duration(milliseconds: 100));
          return;
        }
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });
  Future<void> _send([String? override]) async {
    final text = (override ?? input.text).trim();
    if (busy || text.isEmpty || historyLoading) return;
    final state = context.read<ReviewState>();
    setState(() {
      busy = true;
      replying = true;
      error = null;
      input.clear();
      messages.add((text: text, me: true));
    });
    _scrollDown();
    try {
      if (state.preview) {
        setState(() {
          messages.add(
              (text: '이 화면은 디자인 미리보기예요. 실제 AI와 대화하려면 로그인해 주세요.', me: false));
          suggested = ['불안', '기대', '설렘'];
        });
      } else {
        if (session == 0) {
          session = await service
              .createSession(widget.routine.apiValue, state.account)
              .timeout(const Duration(seconds: 30));
          if (session <= 0) throw StateError('세션 생성 실패');
        }
        if (!mounted) return;
        final response = await service
            .sendMessage(session, text)
            .timeout(const Duration(seconds: 90));
        if (!mounted) return;
        final analysis = response['analysis'] as Map?;
        final reply = '${analysis?['ai_reply'] ?? ''}'.trim();
        if (reply.isEmpty) throw StateError('Empty reply');
        await _reveal(reply);
        if (!mounted) return;
        setState(() {
          suggested = List<String>.from(analysis?['suggested_feelings'] ?? []);
          _applyDetails(analysis?['story_details'] as Map?);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = '응답을 받지 못했어요. 대화 내역을 확인한 뒤 다시 보내주세요.';
          input.text = text;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          replying = false;
        });
        _scrollDown();
      }
    }
  }

  Future<void> _generate() async {
    if (busy || historyLoading) return;
    final state = context.read<ReviewState>();
    final confirmed = details;
    if (confirmed.isEmpty) {
      message(context, '이야기에 담을 정보를 하나 이상 입력해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      DiaryRecord? generated;
      if (state.preview) {
        generated = DiaryRecord(
            id: -DateTime.now().millisecondsSinceEpoch,
            date: DateTime.now(),
            routine: widget.routine,
            title: '확인한 정보로 구성한 이야기 (미리보기)',
            content:
                '문장 구성 미리보기 — 실제 AI 생성은 로그인 후 이용할 수 있어요.\n\n${confirmed.previewStory}',
            tags: [confirmed.emotions].where((s) => s.isNotEmpty).toList());
        state.records.add(generated);
      } else {
        if (session == 0) {
          session = await service
              .createSession(widget.routine.apiValue, state.account)
              .timeout(const Duration(seconds: 30));
          if (session <= 0) throw StateError('세션 생성 실패');
        }
        await service.confirmAndGenerate(
            session,
            confirmed.confirmation,
            [emotionText, ...feelings]
                .where((s) => s.trim().isNotEmpty)
                .toList());
        await state.refresh();
        generated = state.records.where((r) => r.id == session).firstOrNull;
        if (generated == null) throw StateError('생성 결과 조회 실패');
      }
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => AnalysisPage(record: generated!)));
    } catch (_) {
      if (mounted) {
        message(context,
            '이야기 구성을 완료하지 못했어요. 입력 정보는 유지돼요. 기록 목록을 확인한 뒤 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _editText(
      String label, String value, void Function(String) save) async {
    final result = await showDialog<String>(
        context: context,
        builder: (_) => StoryFieldDialog(label: label, initial: value));
    if (result != null && mounted)
      setState(() {
        editedFields.add(label);
        save(result);
      });
  }

  Widget _detailRow(
          String label, String value, IconData icon, VoidCallback edit) =>
      InkWell(
          onTap: busy ? null : edit,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: FigmaAsset('542-212/${switch (label) {
                          '장소' => 'imgBoxiconsLocation',
                          '등장인물' => 'imgFrame483',
                          '감정' => 'imgFrame485',
                          '생활' => 'imgFrame486',
                          _ => 'imgFrame487',
                        }}'))),
                const SizedBox(width: 6),
                SizedBox(
                    width: 54,
                    child: Text(label, style: const TextStyle(fontSize: 11))),
                Expanded(
                    child: Text(value.isEmpty ? '입력하기' : value,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 11))),
                const SizedBox(width: 8),
                const FIcon('chevron', size: 10),
              ])));

  Future<void> _editCharacters() async {
    final selected = await showDialog<Set<String>>(
        context: context,
        builder: (_) => CharacterDialog(selected: characters));
    if (selected == null || !mounted) return;
    setState(() {
      editedFields.add('등장인물');
      characters.clear();
      characters.addAll(selected);
    });
    final state = context.read<ReviewState>();
    if (!state.preview) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      await prefs.setStringList(_characterKey, selected.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return ReviewPage(
        background: canvas,
        scroll: false,
        child: Column(children: [
          PageHeader(actions: [
            IconButton(
                tooltip: '대화 복사',
                onPressed: messages.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(
                            text: messages.map((m) => m.text).join('\n\n')));
                        if (context.mounted) message(context, '대화를 복사했어요.');
                      },
                icon: const FigmaAsset('542-212/imgVector')),
            Text(widget.routine.label,
                style: const TextStyle(fontSize: 12, color: purple)),
            if (r != null)
              IconButton(
                  tooltip: r.marked ? '북마크 해제' : '북마크 추가',
                  onPressed: () => markRecord(context, r),
                  icon: Icon(r.marked ? Icons.bookmark : Icons.bookmark_outline,
                      color: purple))
          ]),
          Expanded(
              child: historyLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scroll,
                      padding: const EdgeInsets.only(top: 12),
                      children: [
                          ...messages.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: m.me
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    if (!m.me) ...[
                                      const LumiArt(),
                                      const SizedBox(width: 8)
                                    ],
                                    Flexible(
                                        child: Container(
                                            constraints: BoxConstraints(
                                                maxWidth: m.me ? 270 : 162),
                                            margin: EdgeInsets.only(
                                                left: m.me ? 44 : 0),
                                            padding: m.me
                                                ? const EdgeInsets.all(16)
                                                : const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 10),
                                            decoration: BoxDecoration(
                                                color: m.me
                                                    ? const Color(0xFFEAE5FF)
                                                    : Colors.white,
                                                border: m.me
                                                    ? null
                                                    : Border.all(
                                                        color: const Color(
                                                            0xFFEEE9FF)),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        m.me ? 16 : 15),
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: m.me
                                                          ? const Color(
                                                              0x127165F6)
                                                          : const Color(
                                                              0x459799FF),
                                                      blurRadius:
                                                          m.me ? 12 : 20)
                                                ]),
                                            child: Text(m.text,
                                                style: TextStyle(
                                                    fontSize: m.me ? 12 : 11,
                                                    height: 1.6)))),
                                  ]))),
                          if (error != null) ...[
                            InfoBox(error!,
                                retry: session != 0 && !busy ? _load : null),
                            gap
                          ],
                          if (replying)
                            Padding(
                              key: replyKey,
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const LumiArt(),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Paper(
                                            child: Text(partialReply.isEmpty
                                                ? '루미가 답장을 생각하고 있어요…'
                                                : partialReply))),
                                  ]),
                            ),
                          SizedBox(key: conversationEndKey, height: 1),
                          Padding(
                              padding: const EdgeInsets.only(left: 48),
                              child: Paper(
                                radius: 16,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('기록 속 이야기',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      gap,
                                      _detailRow(
                                          '장소',
                                          place,
                                          Icons.place_outlined,
                                          () => _editText(
                                              '장소', place, (v) => place = v)),
                                      const Divider(height: 1),
                                      _detailRow(
                                          '등장인물',
                                          characters.join(', '),
                                          Icons.person_outline,
                                          _editCharacters),
                                      const Divider(height: 1),
                                      _detailRow(
                                          '감정',
                                          details.emotions,
                                          Icons.sentiment_satisfied_outlined,
                                          () => _editText('감정', emotionText,
                                              (v) => emotionText = v)),
                                      const Divider(height: 1),
                                      _detailRow(
                                          '생활',
                                          life,
                                          Icons.wb_sunny_outlined,
                                          () => _editText(
                                              '생활', life, (v) => life = v)),
                                      const Divider(height: 1),
                                      _detailRow(
                                          '기타 메모',
                                          memo,
                                          Icons.edit_note,
                                          () => _editText(
                                              '기타 메모', memo, (v) => memo = v)),
                                      if (suggested.isNotEmpty) ...[
                                        const Divider(),
                                        const Text('어떤 감정이 느껴졌나요?',
                                            style: TextStyle(fontSize: 13)),
                                        const SizedBox(height: 8),
                                        Wrap(
                                            spacing: 6,
                                            children: suggested
                                                .map((f) => FilterChip(
                                                    label: Text(f),
                                                    selected:
                                                        feelings.contains(f),
                                                    onSelected: busy
                                                        ? null
                                                        : (value) =>
                                                            setState(() {
                                                              value
                                                                  ? feelings
                                                                      .add(f)
                                                                  : feelings
                                                                      .remove(
                                                                          f);
                                                            })))
                                                .toList()),
                                        gap,
                                      ],
                                      gap,
                                      const Text(
                                          '정보를 확인하면 입력한 내용을 바탕으로 이야기를 구성해요.',
                                          style: TextStyle(
                                              fontSize: 12, color: muted)),
                                      gap,
                                      PrimaryButton(
                                          busy && !replying
                                              ? '이야기 구성 중…'
                                              : '정보가 맞아요',
                                          height: 44,
                                          radius: 10,
                                          onPressed: busy ? null : _generate),
                                    ]),
                              )),
                          gap,
                          if (busy && !replying)
                            const Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(children: [
                                  SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  SizedBox(width: 12),
                                  Text('루미가 이야기를 정리하고 있어요…',
                                      style:
                                          TextStyle(fontSize: 12, color: muted))
                                ])),
                        ])),
          gap,
          VoiceComposer(
              controller: input,
              enabled: !busy && !historyLoading,
              onSend: _send),
        ]));
  }
}

class CharacterDialog extends StatefulWidget {
  final Set<String> selected;
  const CharacterDialog({super.key, required this.selected});
  @override
  State<CharacterDialog> createState() => _CharacterDialogState();
}

class _CharacterDialogState extends State<CharacterDialog> {
  static const options = ['친구', '선생님', '가족', '연인', '선, 후배', '기타'];
  late Set<String> selected;
  late TextEditingController custom;
  bool other = false;
  @override
  void initState() {
    super.initState();
    selected = widget.selected.intersection(options.toSet());
    final extra = widget.selected.difference(options.toSet());
    custom = TextEditingController(text: extra.join(', '));
    other = extra.isNotEmpty || selected.contains('기타');
  }

  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('등장인물 수정',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w600))),
                  IconButton(
                      tooltip: '수정 취소',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ]),
                gap,
                const Text('꿈에 등장한 인물을 선택하거나 입력해 주세요.\n여러 명을 선택할 수 있어요.',
                    style: TextStyle(fontSize: 13, color: muted)),
                const SizedBox(height: 24),
                GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: options
                        .map((o) => OutlinedButton(
                            onPressed: () => setState(() {
                                  if (o == '기타') {
                                    other = !other;
                                  } else {
                                    selected.contains(o)
                                        ? selected.remove(o)
                                        : selected.add(o);
                                  }
                                }),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                side: BorderSide(
                                    color: (o == '기타'
                                            ? other
                                            : selected.contains(o))
                                        ? purple
                                        : lineColor),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: Row(children: [
                              const Icon(Icons.person, size: 17, color: purple),
                              const SizedBox(width: 5),
                              Expanded(
                                  child: Text(o,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black))),
                              if (o == '기타' ? other : selected.contains(o))
                                const Icon(Icons.check_circle,
                                    size: 20, color: purple)
                            ])))
                        .toList()),
                if (other) ...[
                  gap,
                  const Text('직접 입력',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  gap,
                  TextField(
                      controller: custom,
                      decoration: InputDecoration(
                          hintText: '등장인물을 입력해 주세요',
                          suffixIcon: IconButton(
                              tooltip: '입력 지우기',
                              onPressed: custom.clear,
                              icon: const Icon(Icons.close, size: 18))))
                ],
                const SizedBox(height: 24),
                PrimaryButton('수정 완료', height: 44, radius: 10, onPressed: () {
                  final result = {...selected}..remove('기타');
                  if (other && custom.text.trim().isEmpty) {
                    message(context, '기타 등장인물을 입력해 주세요.');
                    return;
                  }
                  if (other) result.add(custom.text.trim());
                  Navigator.pop(context, result);
                }),
              ])));
}
