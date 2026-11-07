import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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

class _CifraWebViewScreenState extends State<CifraWebViewScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _wakeLockActive = true;
  bool _modoLimpo = true;

  // Domínios permitidos para navegação na página principal
  static const List<String> _dominiosPermitidosMainFrame = [
    'cifraclub.com.br',
    'cifraclub.com',
    'letras.mus.br',
    'letras.com',
  ];

  // Domínios permitidos para sub-recursos / iframes legítimos (CDN Studio Sol)
  static const List<String> _dominiosPermitidosSubFrame = [
    'cifraclub.com.br',
    'cifraclub.com',
    'letras.mus.br',
    'letras.com',
    'sscdn.co',
  ];

  // Termos de redes de anúncios, rastreadores, popups e redirecionamentos de spam
  static const List<String> _padroesBloqueados = [
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'googletagservices.com',
    'adservice.google',
    '2mdn.net',
    'imasdk.googleapis.com',
    'taboola.com',
    'outbrain.com',
    'criteo.com',
    'criteo.net',
    'pubmatic.com',
    'rubiconproject.com',
    'openx.net',
    'adnxs.com',
    'smartadserver.com',
    'casalemedia.com',
    'teads.tv',
    'primis.tech',
    'connatix.com',
    'vidverto.io',
    'vdo.ai',
    'mgid.com',
    'revcontent.com',
    'popads.net',
    'propellerads',
    'adsterra',
    'amazon-adsystem.com',
    'moatads.com',
    'adsafeprotected.com',
    'scorecardresearch.com',
    'onelink.me',
    'appsflyer.com',
    'adjust.com',
    'play.google.com',
    'apps.apple.com',
    'intent://',
    'market://',
  ];

  // Caminhos promocionais internos que tiram o músico da cifra/letra
  static const List<String> _caminhosPromocionaisInternos = [
    '/pro',
    '/academy',
    '/loja',
    '/shop',
    '/anuncie',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ativarWakeLock();

    debugPrint(
        '[WebView DEBUG] Iniciando CifraWebViewScreen com URL: ${widget.url}');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bgPrincipal)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('[WebView DEBUG] onPageStarted: $url');
            if (mounted) setState(() => _isLoading = true);
            _injetarBlindagem();
          },
          onPageFinished: (String url) {
            debugPrint('[WebView DEBUG] onPageFinished: $url');
            _injetarBlindagem();
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Ignora erros de subframes de anúncios que nós mesmos bloqueamos
            if (error.isForMainFrame ?? true) {
              debugPrint(
                  '[WebView DEBUG] onWebResourceError: ${error.description} | Código: ${error.errorCode} | URL: ${error.url}');
              if (mounted) setState(() => _isLoading = false);
            }
          },
          onHttpError: (HttpResponseError error) {
            debugPrint(
                '[WebView DEBUG] onHttpError: status ${error.response?.statusCode}');
          },
          onUrlChange: (UrlChange change) {
            debugPrint('[WebView DEBUG] onUrlChange: Mudou para -> ${change.url}');
            _injetarBlindagem();
          },
          onNavigationRequest: (NavigationRequest request) {
            final permitido = _avaliarNavegacao(
              request.url,
              isMainFrame: request.isMainFrame,
            );
            if (!permitido) {
              debugPrint(
                  '🛡️ [AdBlock] Navegação bloqueada (${request.isMainFrame ? "Main" : "Iframe"}): ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  bool _avaliarNavegacao(String rawUrl, {required bool isMainFrame}) {
    final urlLower = rawUrl.toLowerCase().trim();
    if (urlLower.isEmpty) return false;
    if (urlLower == 'about:blank') return true;

    // Bloqueia esquemas externos (intent://, market://, whatsapp://, tel:, mailto:)
    if (!urlLower.startsWith('http://') && !urlLower.startsWith('https://')) {
      return false;
    }

    // Bloqueia imediatamente qualquer rede de anúncio/tracker/spam conhecida
    for (final padrao in _padroesBloqueados) {
      if (urlLower.contains(padrao)) return false;
    }

    final uri = Uri.tryParse(urlLower);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host;

    if (isMainFrame) {
      final dominioValido = _dominiosPermitidosMainFrame.any(
        (d) => host == d || host.endsWith('.$d'),
      );
      if (!dominioValido) return false;

      // Impede cliques acidentais em páginas de assinatura Pro/Loja/Academy
      for (final caminho in _caminhosPromocionaisInternos) {
        if (uri.path == caminho || uri.path.startsWith('$caminho/')) {
          return false;
        }
      }
      return true;
    } else {
      // Para iframes, permite apenas recursos internos legítimos
      return _dominiosPermitidosSubFrame.any(
        (d) => host == d || host.endsWith('.$d'),
      );
    }
  }

  Future<void> _ativarWakeLock() async {
    try {
      await WakelockPlus.enable();
      if (mounted) {
        setState(() => _wakeLockActive = true);
      }
      debugPrint('💡 [WakeLock] Tela configurada para permanecer ligada.');
    } catch (e) {
      debugPrint('⚠️ [WakeLock] Erro ao ativar: $e');
    }
  }

  Future<void> _desativarWakeLock() async {
    try {
      await WakelockPlus.disable();
      if (mounted) {
        setState(() => _wakeLockActive = false);
      }
      debugPrint('💡 [WakeLock] Tela liberada para bloqueio padrão.');
    } catch (e) {
      debugPrint('⚠️ [WakeLock] Erro ao desativar: $e');
    }
  }

  Future<void> _toggleWakeLock() async {
    if (_wakeLockActive) {
      await _desativarWakeLock();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tela sempre ligada: Desativada'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await _ativarWakeLock();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tela sempre ligada: Ativada'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleModoLimpo() async {
    setState(() => _modoLimpo = !_modoLimpo);
    _injetarBlindagem();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _modoLimpo
                ? 'Modo Palco ativado (distrações ocultas)'
                : 'Modo Palco desativado (anúncios seguem bloqueados)',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Se o app for minimizado ou for para segundo plano, libera o wake lock
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      WakelockPlus.disable().catchError((e) {
        debugPrint('⚠️ [WakeLock] Erro ao desativar em background: $e');
      });
    } else if (state == AppLifecycleState.resumed) {
      // Ao voltar para o primeiro plano nesta tela, se estiver ativo, reativa
      if (_wakeLockActive) {
        WakelockPlus.enable().catchError((e) {
          debugPrint('⚠️ [WakeLock] Erro ao reativar no resume: $e');
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Garante que o wake lock seja desativado imediatamente ao sair da tela
    WakelockPlus.disable().catchError((e) {
      debugPrint('⚠️ [WakeLock] Erro ao desativar no dispose: $e');
    });
    super.dispose();
  }

  void _injetarBlindagem() {
    final cssModoPalco = _modoLimpo
        ? '''
          footer, .footer, #footer,
          #comments, .comments, [class*="comment-section"],
          .outbrain, .taboola, [class*="newsletter"],
          [class*="blog-"], [class*="news-"],
          [class*="social-share"], [class*="share-bar"] {
            display: none !important;
          }
        '''
        : '';

    final String jsCode = '''
      (function() {
        try {
          // 1. Bloqueia abertura de popups / novas abas por scripts de spam
          window.open = function() { return null; };

          // 2. Injeta ou atualiza folha de estilo de bloqueio profundo
          var styleId = 'escala-ibai-adshield';
          var estilo = document.getElementById(styleId);
          if (!estilo) {
            estilo = document.createElement('style');
            estilo.id = styleId;
            (document.head || document.documentElement).appendChild(estilo);
          }

          estilo.textContent = `
            /* Slots de publicidade Google Ads / GPT / AdSense / Banners */
            [id^="div-gpt-ad"], [id*="gpt-ad"], [id^="google_ads"],
            ins.adsbygoogle, [data-ad-client], [data-ad-slot], [data-google-query-id],
            [data-ad], [data-adunit], [data-ad-unit],
            .pub, [class^="pub-"], [class*=" pub-"], [class*="--pub"],
            .header-ad, .footer-ad, .pub-banner, .ad-banner, .ad-slot,
            .ad-unit, .ad-container, .ad-wrapper, .ads-container, .ads-wrapper,
            .dfp-ad, .js-ad, .advertising, .advertisement, .sponsored,
            iframe[src*="doubleclick"], iframe[src*="googlesyndication"],
            iframe[src*="googleadservices"], iframe[src*="taboola"],
            iframe[src*="criteo"], iframe[src*="outbrain"], iframe[src*="ads"],
            iframe[id^="google_ads"], iframe[title*="advertisement" i],
            iframe[aria-label*="advertisement" i],

            /* Players de vídeo patrocinados flutuantes */
            [id*="primis"], [class*="primis"],
            [id*="vdo_ai"], [id*="vidverto"], [class*="vidverto"],
            [class*="connatix"], [id*="teads"], [class*="teads"],
            .floating-video, .sticky-video-ad,

            /* Banners de instalar app, assinatura Pro e overlays de cookies/LGPD */
            .smartbanner, #smartbanner, [class*="smart-banner"], [class*="smartBanner"],
            [class*="app-banner"], [class*="appBanner"], [class*="open-in-app"],
            [class*="download-app"], [class*="install-app"],
            [class*="pro-banner"], [class*="proBanner"], [class*="banner-pro"],
            [class*="modal-pro"], [class*="promo-pro"], .g-pro-banner,
            #onetrust-consent-sdk, .onetrust-pc-dark-filter,
            #didomi-host, .fc-consent-root, .fc-dialog-overlay,
            [id*="cookie-banner"], [class*="cookie-banner"], [class*="lgpd-banner"] {
              display: none !important;
              visibility: hidden !important;
              height: 0 !important;
              min-height: 0 !important;
              max-height: 0 !important;
              margin: 0 !important;
              padding: 0 !important;
              pointer-events: none !important;
              opacity: 0 !important;
            }

            $cssModoPalco
          `;

          // 3. Função de varredura ativa para limpar elementos dinâmicos e destravar rolagem
          function limparElementosDinamicos() {
            try {
              var seletoresRemover = [
                '[id^="div-gpt-ad"]',
                '[id^="google_ads"]',
                'ins.adsbygoogle',
                'iframe[src*="doubleclick"]',
                'iframe[src*="googlesyndication"]',
                'iframe[src*="ads"]',
                '[id*="primis"]',
                '[id*="vidverto"]',
                '#onetrust-consent-sdk',
                '.fc-consent-root',
                '.smartbanner',
                '#smartbanner'
              ];
              var nodos = document.querySelectorAll(seletoresRemover.join(','));
              for (var i = 0; i < nodos.length; i++) {
                nodos[i].remove();
              }

              // Remove links promocionais "Abrir no App" / "Assine o Pro" flutuantes sem afetar controles de tom/rolagem
              var links = document.querySelectorAll('a[href*="play.google.com"], a[href*="apps.apple.com"], a[href*="onelink.me"]');
              for (var j = 0; j < links.length; j++) {
                var box = links[j].closest('[class*="banner"], [class*="modal"], [class*="toast"], [class*="promo"]');
                if (box) {
                  box.remove();
                } else {
                  links[j].style.setProperty('display', 'none', 'important');
                }
              }

              // Garante que popups bloqueados não deixem a rolagem da cifra travada
              if (document.body && getComputedStyle(document.body).overflow === 'hidden') {
                document.body.style.setProperty('overflow', 'auto', 'important');
              }
              if (document.documentElement && getComputedStyle(document.documentElement).overflow === 'hidden') {
                document.documentElement.style.setProperty('overflow', 'auto', 'important');
              }
            } catch (err) {}
          }

          limparElementosDinamicos();

          // 4. Instala MutationObserver contínuo (com throttle leve) uma única vez por página
          if (!window.__escalaIbaiAdObserverInstalled) {
            window.__escalaIbaiAdObserverInstalled = true;
            var timer = null;
            var observer = new MutationObserver(function() {
              if (timer) return;
              timer = setTimeout(function() {
                timer = null;
                limparElementosDinamicos();
              }, 250);
            });
            observer.observe(document.documentElement || document, {
              childList: true,
              subtree: true
            });
          }
        } catch (e) {}
      })();
    ''';
    _controller.runJavaScript(jsCode).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrincipal,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.bgPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _modoLimpo
                ? 'Modo Palco / Sem distrações (Ativado)'
                : 'Modo Palco / Sem distrações (Desativado)',
            icon: Icon(
              _modoLimpo ? Icons.shield : Icons.shield_outlined,
              color: _modoLimpo ? AppColors.sucesso : Colors.white54,
            ),
            onPressed: _toggleModoLimpo,
          ),
          IconButton(
            tooltip: _wakeLockActive
                ? 'Tela sempre ligada (Ativada)'
                : 'Tela sempre ligada (Desativada)',
            icon: Icon(
              _wakeLockActive ? Icons.lightbulb : Icons.lightbulb_outline,
              color: _wakeLockActive ? AppColors.acentoDark : Colors.white54,
            ),
            onPressed: _toggleWakeLock,
          ),
          IconButton(
            tooltip: 'Recarregar página',
            icon: const Icon(Icons.refresh, color: Colors.white),
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
