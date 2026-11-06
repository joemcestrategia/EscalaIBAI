import 'package:flutter/material.dart';

/// Um widget de layout base que protege a interface contra sobreposições
/// das barras do sistema (como a barra de navegação do Android ou o home indicator do iOS).
class SafeLayout extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomActionButton;

  const SafeLayout({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.bottomActionButton,
  });

  @override
  Widget build(BuildContext context) {
    // Recupera o padding do sistema operacional (insets).
    // Isso é fundamental para saber o tamanho exato da barra de navegação inferior.
    final systemPadding = MediaQuery.of(context).padding;

    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
            )
          : null,
      // O SafeArea protege o conteúdo principal de entalhes (notches) e barras do sistema.
      // O parâmetro 'bottom: true' garante que o conteúdo não fique atrás da barra inferior.
      body: SafeArea(
        top: true,
        bottom: true, 
        child: child,
      ),
      floatingActionButton: floatingActionButton,
      
      // Exemplo de botão de ação fixo na parte inferior da tela.
      // Usamos 'bottomNavigationBar' para fixar o componente.
      bottomNavigationBar: bottomActionButton != null
          ? Padding(
              // Adiciona o espaçamento dinâmico exato da barra do sistema
              // evitando que o botão seja "engolido" ou sobreposto.
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                // Se o sistema tiver uma barra física/gestos (padding > 0), usa o valor dela.
                // Caso contrário, aplica um espaçamento padrão de 16dp.
                bottom: systemPadding.bottom > 0 
                    ? systemPadding.bottom 
                    : 16, 
              ),
              child: bottomActionButton,
            )
          : null,
    );
  }
}
