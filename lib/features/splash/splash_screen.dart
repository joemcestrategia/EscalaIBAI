import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({
    super.key,
    required this.onInitializationComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  int _messageIndex = 0;
  final List<String> _messages = [
    'Preparando os ministérios...',
    'Organizando as escalas de serviço...',
    'Que a paz do Senhor esteja com você.',
    'Servindo ao Reino com amor e excelência.',
  ];

  Timer? _messageTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();

    // Rotacionar mensagens suavemente
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
      }
    });

    // Tempo de entrada ágil e fluido
    _navigationTimer = Timer(const Duration(milliseconds: 2400), () {
      widget.onInitializationComplete();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageTimer?.cancel();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrincipal,
      body: Stack(
        children: [
          // Brilho Safira suave ao fundo
          Positioned(
            top: -90,
            right: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.corPrimaria.withValues(alpha: 0.10),
                    blurRadius: 110,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo Principal
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: context.corPrimaria.withValues(alpha: 0.22),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: context.heroGradient,
                              ),
                              child: const Icon(
                                Icons.church_rounded,
                                size: 54,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Escala IBAI',
                      style: AppTextStyles.display(color: context.textoPrimario)
                          .copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Servindo ao Reino com Excelência',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: context.textoSecund),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 240,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: context.bgBorda,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.corPrimaria,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: Text(
                              _messages[_messageIndex],
                              key: ValueKey<int>(_messageIndex),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall(
                                color: context.textoSecund,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Créditos no Rodapé
          Positioned(
            bottom: 28 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    'Desenvolvido por',
                    style: AppTextStyles.label(color: context.textoMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dionathan Iannini',
                    style: AppTextStyles.bodySmall(
                      color: context.textoPrimario,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
