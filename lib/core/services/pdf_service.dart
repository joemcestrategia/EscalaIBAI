import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/escala_item.dart';

class PdfService {
  static Future<Uint8List> gerarEscalaMensal(
      List<EscalaItem> itens, int mes, int ano) async {
    final pdf = pw.Document();

    // Filtra apenas itens do mês/ano
    final filtrados = itens.where((e) {
      final d = DateTime.tryParse(e.data);
      if (d == null) return false;
      return d.month == mes && d.year == ano;
    }).toList();

    // Ordena por data e horário
    filtrados.sort((a, b) {
      final cmpData = a.data.compareTo(b.data);
      if (cmpData != 0) return cmpData;
      return a.horario.compareTo(b.horario);
    });

    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final mesStr = meses[mes - 1];

    // Agrupa por Data -> Horário -> Ministério
    final porData = <String, Map<String, Map<String, List<EscalaItem>>>>{};
    for (final item in filtrados) {
      final d = item.data;
      final h = item.horario;
      final m = item.ministerio;

      porData.putIfAbsent(d, () => {});
      porData[d]!.putIfAbsent(h, () => {});
      porData[d]![h]!.putIfAbsent(m, () => []).add(item);
    }

    // Cores Premium
    const corPrimaria = PdfColor.fromInt(0xFF0F172A); // Slate 900
    const corAcento = PdfColor.fromInt(0xFFD4AF37);   // Dourado
    const corFundoData = PdfColor.fromInt(0xFFF1F5F9); // Slate 100
    const corTextoEscuro = PdfColor.fromInt(0xFF1E293B); // Slate 800

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ESCALA DE SERVIÇO',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: corPrimaria)),
                pw.Text('$mesStr / $ano',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: corAcento)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, color: corAcento),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(height: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        build: (context) {
          if (porData.isEmpty) {
            return [
              pw.Center(
                child: pw.Text('Nenhuma escala definida para $mesStr / $ano.',
                    style: const pw.TextStyle(fontSize: 12)),
              )
            ];
          }

          final blocks = <pw.Widget>[];

          for (final dataKey in porData.keys.toList()..sort()) {
            final dateObj = DateTime.parse(dataKey);
            final dataStr = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(dateObj);

            // Bloco da Data
            blocks.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: corFundoData,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border(left: pw.BorderSide(color: corAcento, width: 4)),
                ),
                child: pw.Text(
                  dataStr.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: corTextoEscuro),
                ),
              ),
            );

            final porHorario = porData[dataKey]!;
            for (final hora in porHorario.keys.toList()..sort()) {
              final minMap = porHorario[hora]!;
              final primeiroTema = minMap.values.first.first.tema;
              final tituloHora = primeiroTema.isNotEmpty ? '$hora — $primeiroTema' : hora;

              blocks.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 4, top: 4, bottom: 2),
                  child: pw.Text(
                    tituloHora,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: corPrimaria),
                  ),
                ),
              );

              // Tabela de Ministérios para compactar
              final rows = <pw.TableRow>[];

              for (final min in minMap.keys.toList()..sort()) {
                final itensMin = minMap[min]!;
                
                // Agrupa membros e funções em uma única string ou widgets compactos
                final membrosWidgets = itensMin.map((item) {
                  final falta = item.nome == '[FALTA]';
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(falta ? '❌ ' : '• ', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(
                          falta ? 'VAGA ABERTA' : item.nome,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: falta ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: falta ? PdfColors.red900 : corTextoEscuro,
                          ),
                        ),
                        pw.Text(
                          ' (${item.funcao})',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  );
                }).toList();

                rows.add(
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          min.toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: corTextoEscuro),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: membrosWidgets,
                        ),
                      ),
                    ],
                  ),
                );
              }

              blocks.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, bottom: 6),
                  child: pw.Table(
                    columnWidths: const {
                      0: pw.FixedColumnWidth(100),
                      1: pw.FlexColumnWidth(),
                    },
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    children: rows,
                  ),
                ),
              );
            }
          }

          return blocks;
        },
      ),
    );

    return pdf.save();
  }
}
