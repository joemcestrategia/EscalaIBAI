import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_widgets.dart';

class UpdatePage extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdatePage({super.key, required this.updateInfo});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage>
    with SingleTickerProviderStateMixin {
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

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
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
      if (dir == null) {
        throw Exception("Diretório de armazenamento não encontrado");
      }

      final savePath =
          "${dir.path}/escala_update_${widget.updateInfo.versionCode}.apk";

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
        AppSnackbar.show(context, "Download concluído! Abrindo instalação...");
      }

      final result = await OpenFilex.open(savePath);
      debugPrint("OpenFilex resultado: ${result.message}");
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        AppSnackbar.show(context, "Erro ao baixar atualização: $e", erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrincipal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.updateInfo.forceUpdate && !_isDownloading)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      PhosphorIconsBold.x,
                      color: context.textoSecund,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              else
                const SizedBox(height: 44),

              const Spacer(),

              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: context.heroGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: context.corPrimaria.withValues(alpha: 0.28),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      PhosphorIconsBold.rocketLaunch,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                "Nova versão disponível!",
                textAlign: TextAlign.center,
                style: AppTextStyles.display(color: context.textoPrimario)
                    .copyWith(fontSize: 26),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.acentoSuave,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    "Versão ${widget.updateInfo.versionName}",
                    style: AppTextStyles.label(color: context.acentoTexto),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              AppSurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIconsBold.sparkle,
                          color: context.corPrimaria,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Novidades desta atualização",
                          style: AppTextStyles.subheading(
                            color: context.textoPrimario,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.updateInfo.changelog?.trim().isNotEmpty == true
                          ? widget.updateInfo.changelog!
                          : "Melhorias de desempenho, estabilidade e refinamentos na escala.",
                      style: AppTextStyles.body(color: context.textoSecund),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              if (_isDownloading) ...[
                Text(
                  "Baixando atualização... ${(_progress * 100).toStringAsFixed(0)}%",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subheading(color: context.textoPrimario),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 10,
                    backgroundColor: context.bgBorda,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.corPrimaria,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(PhosphorIconsBold.downloadSimple, size: 20),
                  label: const Text("Atualizar agora"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (!widget.updateInfo.forceUpdate) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style:
                        TextButton.styleFrom(foregroundColor: context.textoSecund),
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
