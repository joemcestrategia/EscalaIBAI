import 'package:flutter/material.dart';
import '../../core/models/musica.dart';
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
    var filtrada = widget.musicas.where((m) =>
        m.titulo.toLowerCase().contains(_filtro) ||
        m.artista.toLowerCase().contains(_filtro)).toList();
        
    filtrada.sort((a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text('Selecionar Música', style: AppTextStyles.heading()),
      content: SizedBox(
        width: 300,
        height: 500,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Pesquisar...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtrada.isEmpty
                  ? Center(child: Text('Nenhuma música encontrada.', style: AppTextStyles.body()))
                  : ListView.builder(
                      itemCount: filtrada.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(filtrada[i].titulo, style: AppTextStyles.body()),
                        subtitle: Text(
                          '${filtrada[i].artista}${filtrada[i].tempo.isNotEmpty ? ' • ${filtrada[i].tempo}' : ''}',
                          style: AppTextStyles.bodySmall()
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
