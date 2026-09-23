import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class MjpegServerService {
  HttpServer? _server;
  final List<_MjpegClient> _clients = [];

  static const String _boundary = "frame";

  Future<void> start({int port = 8081}) async {
    if (_server != null) return;
    _server = await HttpServer.bind('0.0.0.0', port);
    
    _server!.listen((HttpRequest request) {
      if (request.uri.path == '/video_stream') {
        _handleClient(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      }
    });
    
    print('MJPEG Server running on port $port');
  }

  void _handleClient(HttpRequest request) {
    request.response.headers.set(HttpHeaders.contentTypeHeader, 'multipart/x-mixed-replace; boundary=$_boundary');
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
    request.response.headers.set('Pragma', 'no-cache');
    request.response.headers.set('Expires', '0');
    request.response.headers.set('Access-Control-Allow-Origin', '*'); // Crucial for Web Panel consumption

    final client = _MjpegClient(request.response);
    _clients.add(client);

    request.response.done.then((_) {
      _clients.remove(client);
    }).catchError((_) {
      _clients.remove(client);
    });
  }

  void pushFrame(Uint8List frameBytes, {bool isBmp = false}) {
    for (var client in _clients.toList()) {
      client.sendFrame(frameBytes, isBmp: isBmp);
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _clients.clear();
  }
}

class _MjpegClient {
  final HttpResponse response;
  bool _isSending = false;

  _MjpegClient(this.response);

  void sendFrame(Uint8List frame, {bool isBmp = false}) {
    if (_isSending) return; 
    
    _isSending = true;
    
    try {
      final contentType = isBmp ? "image/bmp" : "image/jpeg";
      final header = "--${MjpegServerService._boundary}\r\n"
          "Content-Type: $contentType\r\n"
          "Content-Length: ${frame.length}\r\n\r\n";
      
      response.add(header.codeUnits);
      response.add(frame);
      response.add("\r\n".codeUnits);
      
      // Await socket flush completion before accepting next frame
      response.flush().then((_) {
        _isSending = false;
      }).catchError((_) {
        _isSending = false;
      });
    } catch (e) {
      _isSending = false;
    }
  }
}
