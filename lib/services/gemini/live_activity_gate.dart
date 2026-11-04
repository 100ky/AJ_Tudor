import 'dart:async';
import 'dart:convert';
import '../../core/utils/logger.dart';

/// Ohlašování řeči studenta serveru Gemini Live (ruční detekce řeči) v pořadí,
/// které server opravdu zpracuje.
///
/// Server potvrzuje activityStart i activityEnd zprávou voiceActivity (konec řeči běžně
/// do 0,3 s, nejpomaleji za 2,25 s). activityStart poslaný dřív, než server potvrdí
/// předchozí activityEnd, server zahodí i se zvukem a na řeč už neodpoví (v logu lekcí
/// 0 ze 3 takových, po potvrzení 262 z 262). Začátek další řeči se proto i se zvukem
/// podrží, dokud potvrzení nepřijde, nejdéle [ackTimeout].
class LiveActivityGate {
  LiveActivityGate({required this.send, required this.onEndUnconfirmed});

  /// Odešle zprávu serveru.
  final void Function(String json) send;

  /// Server nepotvrdil konec řeči ani za [ackTimeout]: tah se nejspíš ztratil.
  final void Function() onEndUnconfirmed;

  /// Jak dlouho se čeká, než server potvrdí konec řeči studenta.
  static const Duration ackTimeout = Duration(seconds: 3);

  // Server v tomto spojení řeč potvrzuje (bez toho by se další řeč zbytečně držela)
  bool _serverConfirms = false;
  bool _endUnconfirmed = false;
  List<_RealtimeMessage>? _held;
  Timer? _ackTimer;

  /// Pošle zvuk řeči studenta (zprávu realtimeInput se zvukem).
  void sendAudio(String json) => _send(_RealtimeMessage(json));

  /// Ohlásí začátek ([start] true), nebo konec řeči studenta.
  void sendActivity({required bool start}) {
    final activity = start ? 'activityStart' : 'activityEnd';
    _send(_RealtimeMessage(
      jsonEncode({
        'realtimeInput': {activity: <String, dynamic>{}}
      }),
      activity,
    ));
  }

  /// Zpráva voiceActivity ze serveru. Potvrzení konce uvolní podrženou další řeč.
  void onServerVoiceActivity(dynamic voiceActivity) {
    if (voiceActivity is! Map) return;
    _serverConfirms = true;
    if (voiceActivity['type'] != 'ACTIVITY_END' || !_endUnconfirmed) return;
    _ackTimer?.cancel();
    _endUnconfirmed = false;
    _release();
  }

  /// Nové spojení rozpracovanou řeč nezná: podržené zprávy se zahodí.
  void reset() {
    _ackTimer?.cancel();
    _ackTimer = null;
    _serverConfirms = false;
    _endUnconfirmed = false;
    _held = null;
  }

  void _send(_RealtimeMessage message) {
    final held = _held;
    if (held != null) {
      held.add(message);
      return;
    }
    if (message.activity == 'activityStart' && _endUnconfirmed) {
      L.vad('Server ještě nepotvrdil konec předchozí řeči, začátek další řeči podržím.');
      _held = [message];
      return;
    }
    if (message.activity != null) L.vad('➡️ ${message.activity}');
    send(message.json);
    if (message.activity == 'activityEnd' && _serverConfirms) {
      _endUnconfirmed = true;
      _ackTimer?.cancel();
      _ackTimer = Timer(ackTimeout, _onAckTimeout);
    }
  }

  void _onAckTimeout() {
    if (!_endUnconfirmed) return;
    L.w('Server nepotvrdil konec řeči studenta ani za ${ackTimeout.inSeconds} s.');
    _endUnconfirmed = false;
    _release();
    onEndUnconfirmed();
  }

  void _release() {
    final held = _held;
    if (held == null) return;
    _held = null;
    L.vad('Posílám podrženou řeč studenta (${held.length} zpráv).');
    for (final message in held) {
      _send(message);
    }
  }
}

/// Zpráva realtimeInput: zvuk, nebo ohlášení začátku či konce řeči ([activity]).
class _RealtimeMessage {
  _RealtimeMessage(this.json, [this.activity]);

  final String json;
  final String? activity;
}
