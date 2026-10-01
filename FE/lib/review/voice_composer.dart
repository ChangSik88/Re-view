import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_input_service.dart';
import 'design.dart';

class VoiceComposer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final VoiceRecognizer? recognizer;
  const VoiceComposer(
      {super.key,
      required this.controller,
      required this.onSend,
      this.enabled = true,
      this.recognizer});
  @override
  State<VoiceComposer> createState() => _VoiceComposerState();
}

class _VoiceComposerState extends State<VoiceComposer>
    with WidgetsBindingObserver {
  late final engine = widget.recognizer ?? DeviceVoiceRecognizer.instance;
  bool active = false, starting = false, stopping = false;
  int epoch = 0;
  String prefix = '', suffix = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _cancel() {
    epoch++;
    unawaited(engine.cancel(this).catchError((_) {}));
    active = false;
    starting = false;
    stopping = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VoiceComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && active) _cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (active && !starting && state != AppLifecycleState.resumed) {
      setState(_cancel);
    }
  }

  void _finish(int request, [String? error]) {
    if (!mounted || request != epoch) return;
    setState(() {
      active = false;
      starting = false;
      stopping = false;
      epoch++;
    });
    if (error != null) message(context, error);
  }

  Future<void> _toggle() async {
    if (starting || stopping || !widget.enabled) return;
    if (active) {
      setState(() => stopping = true);
      try {
        await engine.stop(this);
      } catch (_) {
        _finish(epoch, '음성 입력을 종료하지 못했어요. 다시 시도해 주세요.');
      }
      return;
    }
    FocusScope.of(context).unfocus();
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final start =
        selection.isValid ? selection.start.clamp(0, text.length) : text.length;
    final end =
        selection.isValid ? selection.end.clamp(0, text.length) : text.length;
    prefix = text.substring(0, start);
    suffix = text.substring(end);
    final request = ++epoch;
    setState(() {
      active = true;
      starting = true;
    });
    try {
      await engine.start(this,
          onWords: (words) {
            if (!mounted || request != epoch || words.isEmpty) return;
            final before = prefix.isNotEmpty && !RegExp(r'\s$').hasMatch(prefix)
                ? '$prefix '
                : prefix;
            final after = suffix.isNotEmpty && !RegExp(r'^\s').hasMatch(suffix)
                ? ' $suffix'
                : suffix;
            final value = '$before$words$after';
            widget.controller.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(
                    offset: before.length + words.length));
          },
          onDone: () => _finish(request),
          onError: (error) => _finish(request, error));
      if (mounted && request == epoch) setState(() => starting = false);
    } catch (_) {
      _finish(request, '음성 입력을 사용할 수 없어요. 마이크 권한과 음성 인식 설정을 확인해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        if (active)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                  liveRegion: true,
                  child: Text(
                      starting
                          ? '마이크 준비 중…'
                          : stopping
                              ? '음성 입력 마무리 중…'
                              : '듣고 있어요 · 마이크를 다시 누르면 종료돼요',
                      style: const TextStyle(color: purple, fontSize: 12)))),
        TextField(
            controller: widget.controller,
            style: const TextStyle(fontSize: 13),
            minLines: 1,
            maxLines: 4,
            enabled: widget.enabled,
            readOnly: active,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (widget.enabled && !active) widget.onSend();
            },
            decoration: InputDecoration(
                hintText: '루미에게 이야기해 주세요',
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: lineColor)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: purple)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                prefixIcon: IconButton(
                    tooltip: active ? '음성 입력 종료' : '음성으로 입력',
                    onPressed: !widget.enabled || starting || stopping
                        ? null
                        : _toggle,
                    icon: active
                        ? const Icon(Icons.stop_circle, color: purple)
                        : const FigmaAsset('542-212/imgIonMicOutline')),
                suffixIcon: IconButton(
                    tooltip: '메시지 보내기',
                    onPressed: widget.enabled && !active ? widget.onSend : null,
                    icon: Opacity(
                        opacity: active ? .4 : 1,
                        child: const FigmaAsset('542-212/imgFrame488'))))),
      ]);
}
