import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  final String _url;

  WebSocketService(this._url);

  WebSocketChannel? _channel;
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _streamController.stream;

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      print('WebSocket attempting to connect to $_url');

      _channel!.stream.listen(
        (message) {
          print('WebSocket received: $message');
          _streamController.add(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _streamController.addError(error);
        },
        onDone: () {
          print('WebSocket connection closed');
        },
      );
    } catch (e) {
      print('WebSocket connection exception: $e');
    }
  }

  void send(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
    } else {
      print('WebSocket not connected');
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      _channel = null;
    }
  }
}
