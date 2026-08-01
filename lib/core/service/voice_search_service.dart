import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Thin wrapper around `speech_to_text` used to dictate the holdings search
/// query. Android-only — see `HomeScreen`'s platform check before wiring the
/// mic button in.
class VoiceSearchService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> _ensureInitialized() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize();
    return _isInitialized;
  }

  /// Requests mic permission, initializes the recognizer, and starts
  /// listening. [onResult] fires with the live transcript as it's refined.
  /// [onDone] fires once the recognizer stops (silence timeout or manual
  /// stop) so the caller can reset its "listening" UI state.
  /// Returns `false` if permission was denied or init failed.
  Future<bool> startListening({
    required final String localeId,
    required final void Function(String text) onResult,
    required final void Function() onDone,
  }) async {
    final PermissionStatus status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    final bool ready = await _ensureInitialized();
    if (!ready) return false;

    _speech.statusListener = (final String status) {
      if (status == 'done' || status == 'notListening') onDone();
    };

    await _speech.listen(
      onResult: (final SpeechRecognitionResult result) => onResult(result.recognizedWords),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.search,
        localeId: localeId,
      ),
    );
    return true;
  }

  Future<void> stopListening() => _speech.stop();
}
