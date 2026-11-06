import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CorsClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (kIsWeb) {
      // Usar proxy interno da Vercel
      final proxyUrl = Uri.base.resolve('/api/proxy');
      final newReq = http.Request(request.method, proxyUrl);
      newReq.headers.addAll(request.headers);
      newReq.headers['x-target-url'] = request.url.toString();

      if (request is http.Request) {
        newReq.bodyBytes = request.bodyBytes;
      } else {
        final bytes = await request.finalize().toBytes();
        newReq.bodyBytes = bytes;
      }

      return _inner.send(newReq);
    }
    return _inner.send(request);
  }
}
