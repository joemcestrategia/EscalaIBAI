import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';

class CifraWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const CifraWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<CifraWebViewScreen> createState() => _CifraWebViewScreenState();
}

class _CifraWebViewScreenState extends State<CifraWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[WebView DEBUG] Iniciando CifraWebViewScreen com URL: ${widget.url}');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bgPrincipal)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('[WebView DEBUG] onPageStarted: $url');
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            debugPrint('[WebView DEBUG] onPageFinished: $url');
            _injetarAdBlocker();
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[WebView DEBUG] onWebResourceError: ${error.description} | Código: ${error.errorCode} | ErroTipo: ${error.errorType} | URL: ${error.url}');
            if (mounted) setState(() => _isLoading = false);
          },
          onHttpError: (HttpResponseError error) {
            debugPrint('[WebView DEBUG] onHttpError: Ocorreu erro HTTP na requisição. URL da resposta vazia?');
          },
          onUrlChange: (UrlChange change) {
            debugPrint('[WebView DEBUG] onUrlChange: Mudou para -> ${change.url}');
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('[WebView DEBUG] onNavigationRequest: Tentando ir para -> ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _injetarAdBlocker() {
    // Esconde divs comuns de anúncios no Letras e CifraClub
    const String jsCode = '''
      try {
        var estilos = document.createElement('style');
        estilos.innerHTML = `
          [id^="div-gpt-ad-"], 
          iframe[src*="doubleclick"], iframe[src*="ads"],
          .header-ad, .footer-ad, .pub-banner {
            display: none !important;
          }
        `;
        document.head.appendChild(estilos);
      } catch(e) {}
    ''';
    _controller.runJavaScript(jsCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrincipal,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.bgPrincipal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.acento),
            ),
        ],
      ),
    );
  }
}
