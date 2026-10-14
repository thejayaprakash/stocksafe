import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_localization.dart';

/// Detected intent from spoken voice commands.
enum VoiceIntentType {
  search,
  navigateLowStock,
  navigateExpiring,
  navigateValuation,
  navigateAudit,
  navigateBackup,
  quickStockMovement,
  unknown,
}

/// Parsed voice command payload.
class VoiceCommandResult {
  final VoiceIntentType intent;
  final String rawTranscript;
  final String? searchQuery;
  final int? quantity;
  final String? productName;
  final bool? isStockIn;

  const VoiceCommandResult({
    required this.intent,
    required this.rawTranscript,
    this.searchQuery,
    this.quantity,
    this.productName,
    this.isStockIn,
  });
}

/// Voice Assistant Service for Hands-Free Retail & Kirana Operations.
/// Supports both English and Tamil (தமிழ்) speech recognition and offline heuristic intent parsing.
class VoiceAssistantService extends ChangeNotifier {
  VoiceAssistantService._();
  static final VoiceAssistantService instance = VoiceAssistantService._();

  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = '';

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;

  /// Initialize speech engine. Safe to call multiple times.
  Future<bool> initialize() async {
    if (_isAvailable) return true;
    try {
      _isAvailable = await _speech.initialize(
        onError: (val) {
          debugPrint('VoiceAssistant onError: ${val.errorMsg}');
          _isListening = false;
          notifyListeners();
        },
        onStatus: (status) {
          debugPrint('VoiceAssistant onStatus: $status');
          _isListening = status == 'listening';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('VoiceAssistant init failed: $e');
      _isAvailable = false;
    }
    notifyListeners();
    return _isAvailable;
  }

  /// Start listening with locale selection matching app language.
  Future<void> startListening({
    required Function(VoiceCommandResult result) onResult,
  }) async {
    final available = await initialize();
    if (!available) return;

    _lastWords = '';
    _isListening = true;
    notifyListeners();

    // Select locale: ta_IN for Tamil, en_IN / en_US for English
    final isTamil = AppLocale.instance.current == AppLanguage.tamil;
    final localeId = isTamil ? 'ta_IN' : 'en_IN';

    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.confirmation,
        ),
        onResult: (result) {
          _lastWords = result.recognizedWords;
          notifyListeners();

          // Partial results included on purpose: the dialog shows a live
          // transcript, which needs them. `result.finalResult ||` used to
          // lead this condition and decided nothing, because the right side
          // is already true once a single word is heard.
          //
          // The caller therefore gets many calls per utterance, and must not
          // treat each one as a decision to act. VoiceAssistantDialog latches
          // on the first recognised intent for exactly that reason.
          if (_lastWords.trim().isNotEmpty) {
            onResult(parseCommand(_lastWords));
          }
        },
      );
    } catch (e) {
      debugPrint('VoiceAssistant startListening error: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop listening explicitly.
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  /// Offline heuristic parser translating spoken English & Tamil retail phrases into actionable intents.
  static VoiceCommandResult parseCommand(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) {
      return const VoiceCommandResult(intent: VoiceIntentType.unknown, rawTranscript: '');
    }

    // 1. Low Stock intents (English & Tamil)
    if (text.contains('low stock') ||
        text.contains('out of stock') ||
        text.contains('shortage') ||
        text.contains('குறைந்த இருப்பு') ||
        text.contains('இருப்பு இல்லை') ||
        text.contains('தீர்ந்து')) {
      return VoiceCommandResult(
        intent: VoiceIntentType.navigateLowStock,
        rawTranscript: input,
      );
    }

    // 2. Expiry intents
    if (text.contains('expir') ||
        text.contains('காலாவதி') ||
        text.contains('முடிவு')) {
      return VoiceCommandResult(
        intent: VoiceIntentType.navigateExpiring,
        rawTranscript: input,
      );
    }

    // 3. Inventory Valuation / Total Value intents
    if (text.contains('value') ||
        text.contains('worth') ||
        text.contains('valuation') ||
        text.contains('மதிப்பு') ||
        text.contains('மொத்த விலை')) {
      return VoiceCommandResult(
        intent: VoiceIntentType.navigateValuation,
        rawTranscript: input,
      );
    }

    // 4. Physical Stocktake / Audit intents
    if (text.contains('audit') ||
        text.contains('stocktake') ||
        text.contains('count') ||
        text.contains('தணிக்கை') ||
        text.contains('எண்ணிக்கை')) {
      return VoiceCommandResult(
        intent: VoiceIntentType.navigateAudit,
        rawTranscript: input,
      );
    }

    // 5. Backup intents
    if (text.contains('backup') ||
        text.contains('export') ||
        text.contains('காப்புநகல்') ||
        text.contains('சேமி')) {
      return VoiceCommandResult(
        intent: VoiceIntentType.navigateBackup,
        rawTranscript: input,
      );
    }

    // 6. Quick Stock In / Out commands (e.g. "add 10 parle g" or "stock in 5 milk" or "விற்பனை 2 அரிசி")
    final stockInRegex = RegExp(r'(?:add|stock in|inward|சேர்|வாங்கு|வரவு)\s*(\d+)?\s*(.*)', caseSensitive: false);
    final stockOutRegex = RegExp(r'(?:remove|stock out|sell|sold|விற்பனை|கொடு|செலவு)\s*(\d+)?\s*(.*)', caseSensitive: false);

    final inMatch = stockInRegex.firstMatch(text);
    if (inMatch != null && inMatch.group(1) != null) {
      final qty = int.tryParse(inMatch.group(1)!);
      final prod = inMatch.group(2)?.trim();
      return VoiceCommandResult(
        intent: VoiceIntentType.quickStockMovement,
        rawTranscript: input,
        quantity: qty,
        productName: prod?.isNotEmpty == true ? prod : null,
        isStockIn: true,
      );
    }

    final outMatch = stockOutRegex.firstMatch(text);
    if (outMatch != null && outMatch.group(1) != null) {
      final qty = int.tryParse(outMatch.group(1)!);
      final prod = outMatch.group(2)?.trim();
      return VoiceCommandResult(
        intent: VoiceIntentType.quickStockMovement,
        rawTranscript: input,
        quantity: qty,
        productName: prod?.isNotEmpty == true ? prod : null,
        isStockIn: false,
      );
    }

    // 7. General search fallback (e.g. "find salt", "search milk", "தேடு அரிசி", or just product name)
    final cleanedSearch = text
        .replaceAll(RegExp(r'^(search|find|show|look for|தேடு|பார்)\s+', caseSensitive: false), '')
        .trim();

    return VoiceCommandResult(
      intent: VoiceIntentType.search,
      rawTranscript: input,
      searchQuery: cleanedSearch.isNotEmpty ? cleanedSearch : text,
    );
  }
}
