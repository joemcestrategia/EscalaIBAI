import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class UpdatePage extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdatePage({super.key, required this.updateInfo});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> with SingleTickerProviderStateMixin {
  bool _isDownloading = false;
  double _progress = 0;
  final Dio _dio = Dio();
  final CancelToken _cancelToken = CancelToken();

  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    try {
      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
      }

      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception("Diretório de armazenamento não encontrado");

      final savePath = "${dir.path}/escala_update_${widget.updateInfo.versionCode}.apk";

      await _dio.download(
        widget.updateInfo.apkUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Download concluído! Abrindo instalação...",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.sucesso,
          ),
        );
      }

      final result = await OpenFilex.open(savePath);
      debugPrint("OpenFilex resultado: ${result.message}");
    } catch (e) {
      if (!CancelToken.isCancel(e as DioException)) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erro ao baixar atualização: $e"),
              backgroundColor: AppColors.perigo,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.updateInfo.forceUpdate && !_isDownloading)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              else
                const SizedBox(height: 48),

              const Spacer(),

              // Ícone animado em destaque
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.acento.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.acento.withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.acento.withValues(alpha: 0.25),
                          blurRadius: 35,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      PhosphorIconsBold.rocketLaunch,
                      size: 64,
                      color: AppColors.acento,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Títulos
              Text(
                "Nova versão disponível!",
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(color: Colors.white).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                "Versão ${widget.updateInfo.versionName}",
                textAlign: TextAlign.center,
                style: AppTextStyles.subheading(color: AppColors.acento).copyWith(fontSize: 16),
              ),

              const SizedBox(height: 28),

              // Card de Novidades (Changelog)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(PhosphorIconsBold.sparkle, color: AppColors.acento, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "O que há de novo",
                          style: AppTextStyles.label(color: Colors.white).copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.updateInfo.changelog?.trim().isNotEmpty == true
                          ? widget.updateInfo.changelog!
                          : "Melhorias de desempenho, estabilidade e novas correções na escala.",
                      style: AppTextStyles.body(color: Colors.white70).copyWith(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Área de Ação
              if (_isDownloading) ...[
                Text(
                  "Baixando atualização... ${(_progress * 100).toStringAsFixed(0)}%",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.acento),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acento,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  child: const Text(
                    "ATUALIZAR AGORA",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                if (!widget.updateInfo.forceUpdate) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                    child: const Text("Lembrar mais tarde"),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

