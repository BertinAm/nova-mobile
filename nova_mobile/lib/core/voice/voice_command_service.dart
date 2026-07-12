import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceCommandRouter {
  final _controller = StreamController<VoiceCommand>.broadcast();

  Stream<VoiceCommand> get commands => _controller.stream;

  void dispatch(VoiceCommand command) => _controller.add(command);

  void dispose() => _controller.close();
}

class VoiceCommandService {
  final SpeechToText _speech;
  final VoiceCommandRouter _router;

  VoiceCommandService(this._router, {SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  /// Keyword → command. Checked in order; first match wins.
  static const List<MapEntry<String, VoiceCommand>> _commandEntries = [
    // ── Numbered options (most likely to be spoken) ──────────────────────
    MapEntry('option one',    VoiceCommand.option1),
    MapEntry('option 1',      VoiceCommand.option1),
    MapEntry('numéro un',     VoiceCommand.option1),
    MapEntry('option two',    VoiceCommand.option2),
    MapEntry('option 2',      VoiceCommand.option2),
    MapEntry('numéro deux',   VoiceCommand.option2),
    MapEntry('option three',  VoiceCommand.option3),
    MapEntry('option 3',      VoiceCommand.option3),
    MapEntry('numéro trois',  VoiceCommand.option3),
    MapEntry('option four',   VoiceCommand.option4),
    MapEntry('option 4',      VoiceCommand.option4),
    MapEntry('numéro quatre', VoiceCommand.option4),
    MapEntry('option five',   VoiceCommand.option5),
    MapEntry('option 5',      VoiceCommand.option5),
    MapEntry('numéro cinq',   VoiceCommand.option5),
    MapEntry('option six',    VoiceCommand.option6),
    MapEntry('option 6',      VoiceCommand.option6),
    MapEntry('numéro six',    VoiceCommand.option6),
    // ── Stop / Control ───────────────────────────────────────────────────
    MapEntry('stop option',   VoiceCommand.stopCurrentOption),
    MapEntry('arrêter',       VoiceCommand.stopCurrentOption),
    MapEntry('stop',          VoiceCommand.stopTts),
    MapEntry('slow down',     VoiceCommand.slowTts),
    MapEntry('vitesse lente', VoiceCommand.slowTts),
    MapEntry('speed up',      VoiceCommand.speedUpTts),
    MapEntry('vitesse rapide',VoiceCommand.speedUpTts),
    // ── Emergency ────────────────────────────────────────────────────────
    MapEntry('emergency',     VoiceCommand.emergency),
    MapEntry('urgence',       VoiceCommand.emergency),
    MapEntry('call for help', VoiceCommand.emergency),
    MapEntry('au secours',    VoiceCommand.emergency),
    MapEntry('help',          VoiceCommand.emergency),
    // ── Module keywords (fallback if numbered not used) ──────────────────
    MapEntry('obstacle',      VoiceCommand.option1),
    MapEntry('read text',     VoiceCommand.option2),
    MapEntry('lire texte',    VoiceCommand.option2),
    MapEntry('describe scene',VoiceCommand.option3),
    MapEntry('décrire',       VoiceCommand.option3),
    MapEntry('identify money',VoiceCommand.option4),
    MapEntry('identifier argent', VoiceCommand.option4),
    MapEntry('who is this',   VoiceCommand.option5),
    MapEntry('qui est',       VoiceCommand.option5),
    MapEntry('settings',      VoiceCommand.option6),
    MapEntry('paramètres',    VoiceCommand.option6),
    // ── Confirmation ─────────────────────────────────────────────────────
    MapEntry('yes',           VoiceCommand.confirm),
    MapEntry('yeah',          VoiceCommand.confirm),
    MapEntry('oui',           VoiceCommand.confirm),
    MapEntry('ouais',         VoiceCommand.confirm),
    MapEntry('no',            VoiceCommand.deny),
    MapEntry('nope',          VoiceCommand.deny),
    MapEntry('non',           VoiceCommand.deny),
  ];

  Future<void> init(String locale) async {
    try {
      await _speech.initialize(
        onError: (err) => debugPrint('Speech error: $err'),
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  void startListening({String localeId = 'en_CM'}) {
    try {
      _speech.listen(
        onResult: (result) {
          if (!result.finalResult) return;
          _processTranscript(result.recognizedWords.toLowerCase());
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          localeId: localeId,
        ),
      );
    } catch (e) {
      debugPrint('Speech listen failed: $e');
    }
  }

  void stopListening() => _speech.stop();

  @visibleForTesting
  void processTranscriptForTest(String transcript) =>
      _processTranscript(transcript.toLowerCase());

  void _processTranscript(String transcript) {
    if (transcript.isEmpty) return;

    final inputTokens = transcript.split(RegExp(r'\s+'));
    VoiceCommand? bestMatch;
    double highestScore = 0.0;

    for (final entry in _commandEntries) {
      final optionTokens = entry.key.split(RegExp(r'\s+'));
      int matchCount = 0;

      for (var token in inputTokens) {
        if (optionTokens.contains(token)) {
          matchCount++;
        }
      }

      double score = matchCount / (inputTokens.length + optionTokens.length - matchCount);
      
      // If exact string match, bump score to max
      if (transcript.contains(entry.key)) {
        score = 1.0;
      }

      if (score > highestScore && score >= 0.25) { // 0.25 confidence threshold
        highestScore = score;
        bestMatch = entry.value;
      }
    }

    if (bestMatch != null) {
      _router.dispatch(bestMatch);
    }
  }
}

enum VoiceCommand {
  // Numbered menu options (1-indexed, matching on-screen numbers)
  option1,
  option2,
  option3,
  option4,
  option5,
  option6,
  // Control
  stopCurrentOption,
  slowTts,
  speedUpTts,
  stopTts,
  // Emergency
  emergency,
  // Confirmation
  confirm,
  deny,
}
