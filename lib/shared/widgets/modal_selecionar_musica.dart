import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/models/musica.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ModalSelecionarMusica extends StatefulWidget {
  final List<Musica> musicas;

  const ModalSelecionarMusica({super.key, required this.musicas});

  @override
  State<ModalSelecionarMusica> createState() => _ModalSelecionarMusicaState();
}

class _ModalSelecionarMusicaState extends State<ModalSelecionarMusica> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final filtrada = widget.musicas
        .where((m) =>
            m.titulo.toLowerCase().contains(_filtro) ||
            m.artista.toLowerCase().contains(_filtro))
        .toList()
      ..sort(
          (a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));

    return AlertDialog(
      backgroundColor: context.bgCard,
      title: Text(
        'Selecionar Música',
        style: AppTextStyles.heading(color: context.textoPrimario),
      ),
      content: SizedBox(
        width: 360,
        height: 480,
        child: Column(
          children: [
            TextField(
              style: AppTextStyles.body(color: context.textoPrimario),
              decoration: InputDecoration(
                hintText: 'Pesquisar título ou artista...',
                prefixIcon: Icon(
                  PhosphorIconsBold.magnifyingGlass,
                  color: context.textoSecund,
                  size: 18,
                ),
              ),
              onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtrada.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma música encontrada.',
                        style: AppTextStyles.body(color: context.textoSecund),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrada.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: context.bgBorda),
                      itemBuilder: (_, i) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.acentoSuave,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            PhosphorIconsFill.musicNotes,
                            color: context.acentoTexto,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          filtrada[i].titulo,
                          style: AppTextStyles.body(
                            color: context.textoPrimario,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${filtrada[i].artista}${filtrada[i].tempo.isNotEmpty ? ' • ${filtrada[i].tempo}' : ''}',
                          style: AppTextStyles.bodySmall(
                            color: context.textoSecund,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, {
                          'titulo': filtrada[i].titulo,
                          'artista': filtrada[i].artista,
                          'link': filtrada[i].linkYoutube,
                          'tempo': filtrada[i].tempo,
                        }),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
