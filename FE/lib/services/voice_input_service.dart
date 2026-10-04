import 'package:speech_to_text/speech_to_text.dart';

abstract class VoiceRecognizer {
  Future<void> start(Object owner,
      {required void Function(String) onWords,
      required void Function() onDone,
      required void Function(String) onError});
  Future<void> stop(Object owner);
  Future<void> cancel(Object owner);
}

/// One engine per app: platform initialize callbacks cannot be reassigned.
class DeviceVoiceRecognizer implements VoiceRecognizer {
  static final instance = DeviceVoiceRecognizer._();
  DeviceVoiceRecognizer._();
  final _speech = SpeechToText();
  Object? _owner;
  void Function()? _done;
  void Function(String)? _error;
  @override
  Future<void> start(Object owner,
      {required void Function(String) onWords,
      required void Function() onDone,
      required void Function(String) onError}) async {
    if (_owner != null) await cancel(_owner!);
    _owner = owner;
    _done = onDone;
    _error = onError;
    final ready = await _speech.initialize(
      options: [SpeechToText.androidNoBluetooth],
      onStatus: (status) {
        if (status == SpeechToText.doneStatus) _done?.call();
      },
      onError: (error) => _error?.call(_message(error.errorMsg)),
    );
    if (_owner != owner) return;
    if (!ready) {
      onError('음성 입력을 시작할 수 없어요. 앱 설정에서 마이크 권한을 허용하고 휴대폰의 음성 인식 서비스를 확인해 주세요.');
      return;
    }
    final locales = await _speech.locales();
    if (_owner != owner) return;
    final korean = locales
        .where((l) => l.localeId.toLowerCase().startsWith('ko'))
        .firstOrNull;
    if (korean == null) {
      onError('한국어 음성 인식을 사용할 수 없어요. 휴대폰 음성 인식 설정에서 한국어를 추가해 주세요.');
      return;
    }
    await _speech.listen(
        listenOptions: SpeechListenOptions(
            localeId: korean.localeId,
            listenFor: const Duration(seconds: 60),
            pauseFor: const Duration(seconds: 5),
            partialResults: true,
            cancelOnError: true,
            listenMode: ListenMode.dictation),
        onResult: (result) {
          if (_owner == owner) onWords(result.recognizedWords);
        });
    // A page may have closed while the platform was starting its microphone.
    if (_owner != owner) await _speech.cancel();
  }

  @override
  Future<void> stop(Object owner) async {
    if (_owner == owner) await _speech.stop();
  }

  @override
  Future<void> cancel(Object owner) async {
    if (_owner != owner) return;
    _owner = null;
    _done = null;
    _error = null;
    await _speech.cancel();
  }

  String _message(String code) {
    if (code.contains('permission')) {
      return '마이크 권한이 필요해요. 휴대폰 설정 → 앱 → DreamDiary → 권한에서 마이크를 허용해 주세요.';
    }
    if (code.contains('no_match') || code.contains('speech_timeout')) {
      return '목소리를 인식하지 못했어요. 마이크를 눌러 다시 말해 주세요.';
    }
    if (code.contains('network')) return '음성 인식 연결이 끊겼어요. 인터넷 연결을 확인해 주세요.';
    return '음성 입력을 마쳤어요. 입력된 내용을 확인하거나 마이크를 눌러 다시 시도해 주세요.';
  }
}
