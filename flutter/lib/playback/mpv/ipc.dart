import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A single mpv JSON-lines connection. Errors deliberately omit command data.
class MpvIpc {
  final Socket _socket;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _pending = <int, Completer<dynamic>>{};
  int _nextId = 0;
  bool _closed = false;

  MpvIpc._(this._socket) {
    _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final message = jsonDecode(line) as Map<String, dynamic>;
            final pending = _pending.remove(message['request_id']);
            if (pending != null) {
              if (message['error'] == 'success') {
                pending.complete(message['data']);
              } else {
                pending.completeError(StateError('mpv command failed'));
              }
            } else if (!_closed) {
              _events.add(message);
            }
          },
          onError: (_) => close(),
          onDone: close,
        );
  }

  static Future<MpvIpc> connect(String path) async => MpvIpc._(
    await Socket.connect(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    ),
  );

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<dynamic> command(List<dynamic> command) async {
    if (_closed) throw StateError('mpv disconnected');
    final id = ++_nextId;
    final pending = Completer<dynamic>();
    _pending[id] = pending;
    _socket.write('${jsonEncode({'command': command, 'request_id': id})}\n');
    try {
      return await pending.future.timeout(const Duration(seconds: 10));
    } finally {
      _pending.remove(id);
    }
  }

  Future<void> observe(List<String> properties) async {
    for (var i = 0; i < properties.length; i++) {
      await command(['observe_property', i, properties[i]]);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _socket.destroy();
    for (final pending in _pending.values) {
      pending.completeError(StateError('mpv disconnected'));
    }
    _pending.clear();
    _events.close();
  }
}
