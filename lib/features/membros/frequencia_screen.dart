import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/escala_item.dart';
import '../../core/models/frequencia_registro.dart';
import '../../core/models/membro.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_widgets.dart';

enum _OrdenacaoFrequencia {
  menorPercentual,
  maisFaltas,
  maiorPercentual,
  alfabetica,
}

extension _OrdenacaoLabel on _OrdenacaoFrequencia {
  String get label {
    switch (this) {
      case _OrdenacaoFrequencia.menorPercentual:
        return 'Menor %';
      case _OrdenacaoFrequencia.maisFaltas:
        return 'Mais faltas';
      case _OrdenacaoFrequencia.maiorPercentual:
        return 'Maior %';
      case _OrdenacaoFrequencia.alfabetica:
        return 'A–Z';
    }
  }
}

Color _corPorPercentual(double pct, {bool semRegistros = false}) {
  if (semRegistros) return AppColors.textoMuted;
  if (pct >= 90.0) return AppColors.sucesso;
  if (pct >= 75.0) return AppColors.alerta;
  return AppColors.perigo;
}

Color _corPorStatus(StatusFrequencia status) {
  switch (status) {
    case StatusFrequencia.presente:
      return AppColors.sucesso;
    case StatusFrequencia.falta:
      return AppColors.perigo;
    case StatusFrequencia.faltaJustificada:
      return AppColors.alerta;
  }
}

String _formatarDataCurta(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('dd/MM/yyyy', 'pt_BR').format(d);
}

String _formatarDataExtensa(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final s = DateFormat("EEE, dd 'de' MMM", 'pt_BR').format(d);
  return s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

void _invalidarFrequencia(WidgetRef ref) {
  ref.invalidate(escalaDoMesProvider);
  ref.invalidate(kpiMesProvider);
  ref.read(frequenciaRefreshProvider.notifier).state++;
}

Future<String?> _pedirMotivoDialog(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  String valorInicial = '',
  bool obrigatorio = false,
  String hint = 'Ex: Viagem, problema de saúde, trabalho...',
}) async {
  final ctrl = TextEditingController(text: valorInicial);
  final formKey = GlobalKey<FormState>();
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        titulo,
        style: AppTextStyles.subheading(color: ctx.textoPrimario),
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitulo != null && subtitulo.isNotEmpty) ...[
              Text(
                subtitulo,
                style: AppTextStyles.bodySmall(color: ctx.textoSecund),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              style: AppTextStyles.body(color: ctx.textoPrimario),
              decoration: InputDecoration(
                labelText: obrigatorio ? 'Motivo / Justificativa *' : 'Observação (opcional)',
                hintText: hint,
              ),
              validator: obrigatorio
                  ? (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o motivo' : null
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: ctx.textoSecund),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState?.validate() != true) return;
            Navigator.pop(ctx, ctrl.text.trim());
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return res;
}

Future<bool?> abrirModalFaltaAvulsa(
  BuildContext context,
  WidgetRef ref, {
  Membro? membroInicial,
  String? ministerioInicial,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ModalRegistrarFaltaAvulsa(
      membroInicial: membroInicial,
      ministerioInicial: ministerioInicial,
    ),
  );
  if (ok == true) {
    _invalidarFrequencia(ref);
  }
  return ok;
}

// ─── Aba Principal de Faltas e Relatório de Comparecimento ──────────────────
class FrequenciaTabView extends ConsumerStatefulWidget {
  const FrequenciaTabView({super.key});

  @override
  ConsumerState<FrequenciaTabView> createState() => _FrequenciaTabViewState();
}

class _FrequenciaTabViewState extends ConsumerState<FrequenciaTabView> {
  int _subAba = 0; // 0 = Relatório (%), 1 = Registrar Faltas
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  _OrdenacaoFrequencia _ordenacao = _OrdenacaoFrequencia.menorPercentual;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final relatorioAsync = ref.watch(relatorioFrequenciaProvider);
    final ministeriosAsync = ref.watch(ministeriosProvider);
    final periodo = ref.watch(frequenciaPeriodoProvider);
    final filtroMin = ref.watch(frequenciaMinisterioFiltroProvider);

    return RefreshIndicator(
      color: AppColors.acento,
      backgroundColor: context.bgCard,
      onRefresh: () async {
        _invalidarFrequencia(ref);
        await ref.read(relatorioFrequenciaProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          // Seletor rápido Relatório (%) vs Registrar Faltas
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.bgSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.bgBorda),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SubTabPill(
                    icon: PhosphorIconsBold.chartBar,
                    label: 'Relatório (%)',
                    ativo: _subAba == 0,
                    onTap: () => setState(() => _subAba = 0),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SubTabPill(
                    icon: PhosphorIconsBold.clipboardText,
                    label: 'Registrar Faltas',
                    ativo: _subAba == 1,
                    onTap: () => setState(() => _subAba = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filtro de Período
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PeriodoFrequencia.values
                  .map(
                    (p) => _ChipFiltro(
                      label: p.label,
                      selecionado: periodo == p,
                      onTap: () =>
                          ref.read(frequenciaPeriodoProvider.notifier).state = p,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Filtro de Ministério
          ministeriosAsync.when(
            data: (mins) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipFiltro(
                    label: 'Todos ministérios',
                    selecionado: filtroMin == null,
                    onTap: () => ref
                        .read(frequenciaMinisterioFiltroProvider.notifier)
                        .state = null,
                  ),
                  ...mins.map(
                    (m) => _ChipFiltro(
                      label: m.nome,
                      selecionado: filtroMin == m.nome,
                      onTap: () => ref
                          .read(frequenciaMinisterioFiltroProvider.notifier)
                          .state = m.nome,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 36),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          relatorioAsync.when(
            data: (res) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!res.tabelaFrequenciaDisponivel) _BannerSqlPendente(),
                if (_subAba == 0)
                  ..._buildRelatorioView(context, res, periodo, filtroMin)
                else
                  ..._buildRegistrarView(context, res, filtroMin),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.acento),
              ),
            ),
            error: (e, _) => AppSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    PhosphorIconsBold.warningCircle,
                    color: AppColors.perigo,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Erro ao carregar dados de frequência',
                    style: AppTextStyles.subheading(color: context.textoPrimario),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.toString(),
                    style: AppTextStyles.bodySmall(color: context.textoSecund),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Tentar Novamente',
                    onPressed: () => _invalidarFrequencia(ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRelatorioView(
    BuildContext context,
    RelatorioFrequenciaResult res,
    PeriodoFrequencia periodo,
    String? filtroMin,
  ) {
    final media = res.mediaComparecimentoGeral;
    final corMedia = _corPorPercentual(
      media,
      semRegistros: res.totalCompromissosGeral == 0,
    );

    final listaFiltrada = res.resumos.where((r) {
      if (_busca.trim().isEmpty) return true;
      return r.membro.nome.toLowerCase().contains(_busca.trim().toLowerCase());
    }).toList();

    listaFiltrada.sort((a, b) {
      switch (_ordenacao) {
        case _OrdenacaoFrequencia.menorPercentual:
          if (a.semRegistros != b.semRegistros) {
            return a.semRegistros ? 1 : -1;
          }
          final cmpPct = a.percentualComparecimento
              .compareTo(b.percentualComparecimento);
          if (cmpPct != 0) return cmpPct;
          final cmpFalta = b.totalFaltas.compareTo(a.totalFaltas);
          if (cmpFalta != 0) return cmpFalta;
          return a.membro.nome.compareTo(b.membro.nome);

        case _OrdenacaoFrequencia.maisFaltas:
          final cmpFalta = b.totalFaltas.compareTo(a.totalFaltas);
          if (cmpFalta != 0) return cmpFalta;
          final cmpNaoJust =
              b.faltasNaoJustificadas.compareTo(a.faltasNaoJustificadas);
          if (cmpNaoJust != 0) return cmpNaoJust;
          return a.membro.nome.compareTo(b.membro.nome);

        case _OrdenacaoFrequencia.maiorPercentual:
          if (a.semRegistros != b.semRegistros) {
            return a.semRegistros ? 1 : -1;
          }
          final cmpPct = b.percentualComparecimento
              .compareTo(a.percentualComparecimento);
          if (cmpPct != 0) return cmpPct;
          return b.presencas.compareTo(a.presencas);

        case _OrdenacaoFrequencia.alfabetica:
          return a.membro.nome.compareTo(b.membro.nome);
      }
    });

    return [
      // Card KPI Geral
      AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RESUMO DE COMPARECIMENTO',
                        style: AppTextStyles.label(
                          color: context.corPrimaria,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${periodo.label}${filtroMin != null ? ' • $filtroMin' : ''}',
                        style: AppTextStyles.bodySmall(
                          color: context.textoSecund,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _copiarResumo(context, res, periodo, filtroMin),
                  icon: const Icon(PhosphorIconsBold.copy, size: 16),
                  label: const Text('Copiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.corPrimaria,
                    side: BorderSide(
                      color: context.corPrimaria.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _KpiMiniBox(
                    titulo: 'Comparecimento',
                    valor: res.totalCompromissosGeral == 0
                        ? '—'
                        : '${media.toStringAsFixed(1)}%',
                    detalhe:
                        '${res.totalPresencasGeral}/${res.totalCompromissosGeral} presenças',
                    cor: corMedia,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiMiniBox(
                    titulo: 'Total de Faltas',
                    valor: '${res.totalFaltasGeral}',
                    detalhe: res.totalFaltasJustificadasGeral > 0
                        ? '${res.totalFaltasNaoJustificadasGeral} s/ just. • ${res.totalFaltasJustificadasGeral} just.'
                        : '${res.totalFaltasNaoJustificadasGeral} registradas',
                    cor: res.totalFaltasGeral > 0
                        ? AppColors.perigo
                        : AppColors.sucesso,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _subAba = 1),
                    icon: const Icon(PhosphorIconsBold.calendarCheck, size: 17),
                    label: const Text('Chamada por Culto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textoPrimario,
                      side: BorderSide(color: context.bgBorda),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => abrirModalFaltaAvulsa(
                      context,
                      ref,
                      ministerioInicial: filtroMin,
                    ),
                    icon: const Icon(PhosphorIconsBold.calendarX, size: 17),
                    label: const Text('Falta Avulsa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.acento,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Cálculo sobre escalas já realizadas até hoje e ensaios/reuniões lançados no período.',
              style: AppTextStyles.label(color: context.textoMuted)
                  .copyWith(fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Busca e ordenação
      TextField(
        controller: _buscaCtrl,
        style: AppTextStyles.body(color: context.textoPrimario),
        onChanged: (v) => setState(() => _busca = v),
        decoration: InputDecoration(
          hintText: 'Filtrar membro no relatório...',
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            color: context.textoSecund,
            size: 20,
          ),
          suffixIcon: _buscaCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    PhosphorIconsBold.x,
                    color: context.textoSecund,
                    size: 18,
                  ),
                  onPressed: () {
                    _buscaCtrl.clear();
                    setState(() => _busca = '');
                  },
                )
              : null,
        ),
      ),
      const SizedBox(height: 10),

      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _OrdenacaoFrequencia.values
              .map(
                (ord) => _ChipFiltro(
                  label: ord.label,
                  selecionado: _ordenacao == ord,
                  onTap: () => setState(() => _ordenacao = ord),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 12),

      if (listaFiltrada.isEmpty)
        AppSurfaceCard(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Text(
              'Nenhum membro encontrado para o filtro selecionado.',
              style: AppTextStyles.body(color: context.textoSecund),
              textAlign: TextAlign.center,
            ),
          ),
        )
      else
        ...listaFiltrada.map(
          (resumo) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MembroFrequenciaCard(
              resumo: resumo,
              onTap: () => _abrirDetalhesMembro(context, resumo),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildRegistrarView(
    BuildContext context,
    RelatorioFrequenciaResult res,
    String? filtroMin,
  ) {
    final cultosAsync = ref.watch(chamadaCultosRecentesProvider);

    return [
      // Atalhos de registro
      AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REGISTRO RÁPIDO DE FALTAS',
              style: AppTextStyles.label(color: context.corPrimaria),
            ),
            const SizedBox(height: 6),
            Text(
              'Faça a chamada por culto da escala ou lance uma falta avulsa em ensaios, reuniões e eventos extras.',
              style: AppTextStyles.bodySmall(color: context.textoSecund),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => abrirModalFaltaAvulsa(
                      context,
                      ref,
                      ministerioInicial: filtroMin,
                    ),
                    icon: const Icon(PhosphorIconsBold.calendarX, size: 18),
                    label: const Text('Falta Avulsa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.acento,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _escolherCultoPorData(context, filtroMin),
                    icon: const Icon(PhosphorIconsBold.calendar, size: 18),
                    label: const Text('Outra Data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.corPrimaria,
                      side: BorderSide(
                        color: context.corPrimaria.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),

      Text(
        'CULTOS RECENTES PARA CHAMADA',
        style: AppTextStyles.label(color: context.textoSecund),
      ),
      const SizedBox(height: 8),

      cultosAsync.when(
        data: (itens) {
          final validos = itens.where((e) {
            if (e.ministerio == 'Jejum') return false;
            final n = e.nome.trim();
            if (n.isEmpty || n == '[FALTA]') return false;
            if (filtroMin != null &&
                filtroMin.isNotEmpty &&
                e.ministerio != filtroMin) {
              return false;
            }
            return true;
          }).toList();

          if (validos.isEmpty) {
            return AppSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Nenhuma escala encontrada nos últimos 45 dias para chamada.',
                style: AppTextStyles.bodySmall(color: context.textoSecund),
              ),
            );
          }

          final porCulto = <String, List<EscalaItem>>{};
          for (final item in validos) {
            final key = '${item.data}|${item.horario}';
            porCulto.putIfAbsent(key, () => []).add(item);
          }

          final chaves = porCulto.keys.toList()
            ..sort((a, b) => b.compareTo(a)); // Mais recentes primeiro

          return Column(
            children: chaves.take(20).map((key) {
              final grupo = porCulto[key]!;
              final primeiro = grupo.first;

              // Consolida membros únicos no culto
              final membrosUnicos = <String, List<EscalaItem>>{};
              for (final e in grupo) {
                final mKey = '${e.nome.trim().toLowerCase()}|${e.ministerio}';
                membrosUnicos.putIfAbsent(mKey, () => []).add(e);
              }

              int totalFaltas = 0;
              int totalPresentes = 0;
              for (final mItens in membrosUnicos.values) {
                if (mItens.any((e) =>
                    e.statusConvite == 'FALTA' ||
                    e.statusConvite == 'FALTA_JUSTIFICADA')) {
                  totalFaltas++;
                } else if (mItens.any((e) => e.statusConvite == 'PRESENTE')) {
                  totalPresentes++;
                }
              }

              return AppSurfaceCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                onTap: () => _abrirChamadaCulto(
                  context,
                  dataCulto: primeiro.data,
                  horaCulto: primeiro.horario,
                  tema: primeiro.tema,
                  ministerioFiltro: filtroMin,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.acentoSuave,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        PhosphorIconsBold.calendarCheck,
                        color: context.acentoTexto,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatarDataExtensa(primeiro.data)} • ${primeiro.horario.isNotEmpty ? primeiro.horario : 'Horário livre'}',
                            style: AppTextStyles.body(
                              color: context.textoPrimario,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${primeiro.tema.isNotEmpty ? primeiro.tema : 'Culto'} • ${membrosUnicos.length} escalados',
                            style: AppTextStyles.bodySmall(
                              color: context.textoSecund,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (totalFaltas > 0 || totalPresentes > 0) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (totalPresentes > 0)
                                  _MiniStatusTag(
                                    label: '$totalPresentes presentes',
                                    cor: AppColors.sucesso,
                                  ),
                                if (totalFaltas > 0)
                                  _MiniStatusTag(
                                    label: '$totalFaltas faltas',
                                    cor: AppColors.perigo,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      PhosphorIconsBold.caretRight,
                      color: context.textoMuted,
                      size: 18,
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.acento),
          ),
        ),
        error: (e, _) => AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Text('Erro ao carregar cultos: $e'),
        ),
      ),

      const SizedBox(height: 18),
      Text(
        'FALTAS E EVENTOS AVULSOS NO PERÍODO',
        style: AppTextStyles.label(color: context.textoSecund),
      ),
      const SizedBox(height: 8),

      if (res.registrosAvulsosEFaltas.isEmpty)
        AppSurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Nenhuma falta ou evento avulso lançado no período selecionado.',
            style: AppTextStyles.bodySmall(color: context.textoSecund),
          ),
        )
      else
        ...res.registrosAvulsosEFaltas.map(
          (reg) => _RegistroFrequenciaCard(
            registro: reg,
            onEdit: () => _editarRegistro(context, reg),
            onDelete: () => _excluirRegistro(context, reg),
          ),
        ),
    ];
  }

  Future<void> _copiarResumo(
    BuildContext context,
    RelatorioFrequenciaResult res,
    PeriodoFrequencia periodo,
    String? filtroMin,
  ) async {
    final buf = StringBuffer();
    buf.writeln('📊 *Relatório de Frequência — ${periodo.label}*');
    if (filtroMin != null && filtroMin.isNotEmpty) {
      buf.writeln('Ministério: $filtroMin');
    }
    buf.writeln(
      'Média geral: ${res.mediaComparecimentoGeral.toStringAsFixed(1)}% '
      '(${res.totalPresencasGeral}/${res.totalCompromissosGeral} presenças | ${res.totalFaltasGeral} faltas)',
    );
    buf.writeln('');

    final ordenados = List<ResumoFrequenciaMembro>.from(res.resumos)
      ..sort((a, b) => a.membro.nome.compareTo(b.membro.nome));
    for (final r in ordenados) {
      final pctTxt = r.semRegistros
          ? 'Sem registros'
          : '${r.percentualComparecimento.toStringAsFixed(0)}%';
      final faltasTxt = r.totalFaltas == 0
          ? '0 faltas'
          : (r.faltasJustificadas > 0
              ? '${r.totalFaltas} falta(s) (${r.faltasJustificadas} justif.)'
              : '${r.totalFaltas} falta(s)');
      buf.writeln(
        '• ${r.membro.nome}: $pctTxt (${r.presencas}/${r.totalCompromissos}) — $faltasTxt',
      );
    }

    await Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    if (context.mounted) {
      AppSnackbar.show(context, 'Relatório copiado para a área de transferência!');
    }
  }

  Future<void> _abrirDetalhesMembro(
    BuildContext context,
    ResumoFrequenciaMembro resumo,
  ) async {
    final mudou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModalDetalheFrequenciaMembro(resumo: resumo),
    );
    if (mudou == true) {
      _invalidarFrequencia(ref);
    }
  }

  Future<void> _abrirChamadaCulto(
    BuildContext context, {
    required String dataCulto,
    required String horaCulto,
    String tema = '',
    String? ministerioFiltro,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChamadaCultoSheet(
        dataCulto: dataCulto,
        horaCulto: horaCulto,
        tema: tema,
        ministerioFiltro: ministerioFiltro,
      ),
    );
    _invalidarFrequencia(ref);
  }

  Future<void> _escolherCultoPorData(
    BuildContext context,
    String? filtroMin,
  ) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (d == null || !context.mounted) return;
    final dataStr = DateFormat('yyyy-MM-dd').format(d);
    final itens = await ref.read(escalaRepoProvider).getByData(dataStr);
    if (!context.mounted) return;

    final validos = itens.where((e) {
      if (e.ministerio == 'Jejum') return false;
      final n = e.nome.trim();
      if (n.isEmpty || n == '[FALTA]') return false;
      if (filtroMin != null &&
          filtroMin.isNotEmpty &&
          e.ministerio != filtroMin) {
        return false;
      }
      return true;
    }).toList();

    if (validos.isEmpty) {
      AppSnackbar.show(
        context,
        'Nenhuma escala encontrada em ${_formatarDataCurta(dataStr)}. Use "Falta Avulsa" se desejar registrar evento extra.',
        erro: true,
      );
      return;
    }

    final horarios = validos.map((e) => e.horario).toSet().toList()..sort();
    if (horarios.length == 1) {
      await _abrirChamadaCulto(
        context,
        dataCulto: dataStr,
        horaCulto: horarios.first,
        tema: validos.first.tema,
        ministerioFiltro: filtroMin,
      );
      return;
    }

    final horaEscolhida = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(
              'Escolha o horário de ${_formatarDataCurta(dataStr)}',
              style: AppTextStyles.subheading(color: ctx.textoPrimario),
            ),
            const SizedBox(height: 8),
            ...horarios.map((h) {
              final primeiro = validos.firstWhere((e) => e.horario == h);
              return ListTile(
                leading: Icon(
                  PhosphorIconsBold.clock,
                  color: ctx.corPrimaria,
                ),
                title: Text(h.isNotEmpty ? h : 'Horário livre'),
                subtitle: Text(
                  primeiro.tema.isNotEmpty ? primeiro.tema : 'Culto',
                ),
                onTap: () => Navigator.pop(ctx, h),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (horaEscolhida != null && context.mounted) {
      final primeiro = validos.firstWhere((e) => e.horario == horaEscolhida);
      await _abrirChamadaCulto(
        context,
        dataCulto: dataStr,
        horaCulto: horaEscolhida,
        tema: primeiro.tema,
        ministerioFiltro: filtroMin,
      );
    }
  }

  Future<void> _editarRegistro(
    BuildContext context,
    FrequenciaRegistro reg,
  ) async {
    StatusFrequencia statusSel = reg.status;
    final motivoCtrl = TextEditingController(text: reg.motivo);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(
            'Editar registro — ${reg.membroNome}',
            style: AppTextStyles.subheading(color: ctx.textoPrimario),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatarDataCurta(reg.data)} • ${reg.tipoAtividade}',
                style: AppTextStyles.bodySmall(color: ctx.textoSecund),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: StatusFrequencia.values.map((st) {
                  final sel = statusSel == st;
                  final cor = _corPorStatus(st);
                  return ChoiceChip(
                    label: Text(st.label),
                    selected: sel,
                    selectedColor: cor.withValues(alpha: 0.2),
                    labelStyle: AppTextStyles.bodySmall(
                      color: sel ? cor : ctx.textoSecund,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) => setDlg(() => statusSel = st),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                maxLines: 3,
                style: AppTextStyles.body(color: ctx.textoPrimario),
                decoration: InputDecoration(
                  labelText: statusSel == StatusFrequencia.faltaJustificada
                      ? 'Motivo / Justificativa'
                      : 'Observação (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    final novoMotivo = motivoCtrl.text.trim();
    motivoCtrl.dispose();

    if (ok == true) {
      await ref.read(frequenciaRepoProvider).atualizarRegistro(
            registro: reg,
            novoStatus: statusSel,
            novoMotivo: novoMotivo,
          );
      _invalidarFrequencia(ref);
      if (context.mounted) {
        AppSnackbar.show(context, 'Registro atualizado!');
      }
    }
  }

  Future<void> _excluirRegistro(
    BuildContext context,
    FrequenciaRegistro reg,
  ) async {
    final ok = await ConfirmDialog.show(
      context,
      titulo: 'Excluir registro',
      mensagem:
          'Remover registro de ${reg.status.label.toLowerCase()} de ${reg.membroNome} em ${_formatarDataCurta(reg.data)}?',
      labelConfirmar: 'Excluir',
      perigo: true,
    );
    if (!ok) return;

    await ref.read(frequenciaRepoProvider).excluirRegistro(reg);
    _invalidarFrequencia(ref);
    if (context.mounted) {
      AppSnackbar.show(context, 'Registro removido.');
    }
  }
}

// ─── Bottom Sheet de Chamada por Culto (Reutilizável na EscalaScreen) ────────
class ChamadaCultoSheet extends ConsumerStatefulWidget {
  final String dataCulto;
  final String horaCulto;
  final String tema;
  final String? ministerioFiltro;

  const ChamadaCultoSheet({
    super.key,
    required this.dataCulto,
    required this.horaCulto,
    this.tema = '',
    this.ministerioFiltro,
  });

  @override
  ConsumerState<ChamadaCultoSheet> createState() => _ChamadaCultoSheetState();
}

class _GrupoMembroCulto {
  final String nome;
  final String ministerio;
  final List<EscalaItem> itens;
  final StatusFrequencia? statusAtual;
  final String motivo;

  const _GrupoMembroCulto({
    required this.nome,
    required this.ministerio,
    required this.itens,
    required this.statusAtual,
    required this.motivo,
  });

  String get funcoesLabel => itens
      .map((e) => e.funcao.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .join(', ');
}

class _ChamadaCultoSheetState extends ConsumerState<ChamadaCultoSheet> {
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;
  String? _minFiltroLocal;
  List<_GrupoMembroCulto> _grupos = [];
  Map<String, Membro> _membrosPorNome = {};

  @override
  void initState() {
    super.initState();
    _minFiltroLocal = widget.ministerioFiltro;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ref.read(escalaRepoProvider).getByData(widget.dataCulto),
        ref
            .read(frequenciaRepoProvider)
            .getRegistrosPeriodo(widget.dataCulto, widget.dataCulto),
        ref.read(membrosProvider.future),
      ]);

      final itensData = results[0] as List<EscalaItem>;
      final freqRes = results[1]
          as ({List<FrequenciaRegistro> registros, bool tabelaDisponivel});
      final membros = results[2] as List<Membro>;

      final horaAlvo = widget.horaCulto.length >= 5
          ? widget.horaCulto.substring(0, 5)
          : widget.horaCulto;

      final itensCulto = itensData.where((e) {
        if (e.ministerio == 'Jejum') return false;
        final n = e.nome.trim();
        if (n.isEmpty || n == '[FALTA]') return false;
        if (horaAlvo.isNotEmpty && e.horario != horaAlvo) return false;
        return true;
      }).toList();

      final freqPorEscalaId = <String, FrequenciaRegistro>{
        for (final r in freqRes.registros)
          if (r.escalaId != null && r.escalaId!.isNotEmpty) r.escalaId!: r,
      };

      final agrupado = <String, List<EscalaItem>>{};
      for (final e in itensCulto) {
        final key = '${e.nome.trim().toLowerCase()}|${e.ministerio}';
        agrupado.putIfAbsent(key, () => []).add(e);
      }

      final grupos = <_GrupoMembroCulto>[];
      for (final list in agrupado.values) {
        final first = list.first;
        FrequenciaRegistro? reg;
        for (final e in list) {
          if (freqPorEscalaId.containsKey(e.id)) {
            reg = freqPorEscalaId[e.id];
            break;
          }
        }

        StatusFrequencia? st;
        if (reg != null) {
          st = reg.status;
        } else if (list.any((e) => e.statusConvite == 'FALTA')) {
          st = StatusFrequencia.falta;
        } else if (list.any((e) => e.statusConvite == 'FALTA_JUSTIFICADA')) {
          st = StatusFrequencia.faltaJustificada;
        } else if (list.any((e) => e.statusConvite == 'PRESENTE')) {
          st = StatusFrequencia.presente;
        }

        grupos.add(
          _GrupoMembroCulto(
            nome: first.nome,
            ministerio: first.ministerio,
            itens: list,
            statusAtual: st,
            motivo: reg?.motivo ?? '',
          ),
        );
      }

      grupos.sort((a, b) {
        final cmpMin = a.ministerio.compareTo(b.ministerio);
        return cmpMin != 0 ? cmpMin : a.nome.compareTo(b.nome);
      });

      if (!mounted) return;
      setState(() {
        _grupos = grupos;
        _membrosPorNome = {
          for (final m in membros) m.nome.trim().toLowerCase(): m,
        };
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _marcarStatus(
    _GrupoMembroCulto grupo,
    StatusFrequencia status, {
    bool pedirMotivo = false,
  }) async {
    String motivo = grupo.motivo;
    if (status == StatusFrequencia.presente) {
      motivo = '';
    } else if (status == StatusFrequencia.faltaJustificada || pedirMotivo) {
      final resp = await _pedirMotivoDialog(
        context,
        titulo: status == StatusFrequencia.faltaJustificada
            ? 'Justificar falta — ${grupo.nome}'
            : 'Observação da falta — ${grupo.nome}',
        subtitulo:
            '${_formatarDataCurta(widget.dataCulto)} • ${grupo.ministerio}',
        valorInicial: grupo.motivo,
        obrigatorio: status == StatusFrequencia.faltaJustificada,
      );
      if (resp == null) return;
      motivo = resp;
    }

    setState(() => _salvando = true);
    try {
      final membro = _membrosPorNome[grupo.nome.trim().toLowerCase()];
      final liderNome =
          ref.read(userRoleProvider.notifier).selectedMembroNome ?? 'Líder';
      await ref.read(frequenciaRepoProvider).registrarChamadaEscala(
            itensDoMembroNoCulto: grupo.itens,
            status: status,
            motivo: motivo,
            membroId: membro?.id,
            registradoPor: liderNome,
          );
      _invalidarFrequencia(ref);
      await _carregar();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Erro ao salvar: $e', erro: true);
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _marcarPendentesPresentes() async {
    final pendentes = _gruposVisiveis
        .where((g) => g.statusAtual == null)
        .toList();
    if (pendentes.isEmpty) {
      AppSnackbar.show(context, 'Todos os membros exibidos já possuem marcação.');
      return;
    }

    setState(() => _salvando = true);
    try {
      final liderNome =
          ref.read(userRoleProvider.notifier).selectedMembroNome ?? 'Líder';
      final repo = ref.read(frequenciaRepoProvider);
      for (final g in pendentes) {
        final membro = _membrosPorNome[g.nome.trim().toLowerCase()];
        await repo.registrarChamadaEscala(
          itensDoMembroNoCulto: g.itens,
          status: StatusFrequencia.presente,
          membroId: membro?.id,
          registradoPor: liderNome,
        );
      }
      _invalidarFrequencia(ref);
      await _carregar();
      if (mounted) {
        AppSnackbar.show(
          context,
          '${pendentes.length} membro(s) marcado(s) como Presente!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Erro ao atualizar lote: $e', erro: true);
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  List<_GrupoMembroCulto> get _gruposVisiveis {
    if (_minFiltroLocal == null || _minFiltroLocal!.isEmpty) return _grupos;
    return _grupos.where((g) => g.ministerio == _minFiltroLocal).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ministeriosPresentes = _grupos
        .map((g) => g.ministerio)
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final visiveis = _gruposVisiveis;
    final temPendentes = visiveis.any((g) => g.statusAtual == null);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.bgBorda),
        ),
        child: LoadingOverlay(
          loading: _salvando,
          mensagem: 'Registrando...',
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.bgBorda,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chamada do Culto',
                            style: AppTextStyles.heading(
                              color: context.textoPrimario,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatarDataExtensa(widget.dataCulto)} • ${widget.horaCulto}${widget.tema.isNotEmpty ? ' • ${widget.tema}' : ''}',
                            style: AppTextStyles.bodySmall(
                              color: context.textoSecund,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        PhosphorIconsBold.x,
                        color: context.textoSecund,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              if (ministeriosPresentes.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _ChipFiltro(
                        label: 'Todos',
                        selecionado: _minFiltroLocal == null,
                        onTap: () => setState(() => _minFiltroLocal = null),
                      ),
                      ...ministeriosPresentes.map(
                        (m) => _ChipFiltro(
                          label: m,
                          selecionado: _minFiltroLocal == m,
                          onTap: () => setState(() => _minFiltroLocal = m),
                        ),
                      ),
                    ],
                  ),
                ),
              if (temPendentes && !_carregando)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _marcarPendentesPresentes,
                      icon: const Icon(
                        PhosphorIconsBold.userCheck,
                        size: 17,
                      ),
                      label: const Text('Marcar pendentes como Presente'),
                    ),
                  ),
                ),
              Divider(height: 1, color: context.bgBorda),
              Expanded(
                child: _carregando
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.acento,
                        ),
                      )
                    : _erro != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Erro ao carregar chamada: $_erro',
                                style: AppTextStyles.body(
                                  color: AppColors.perigo,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : visiveis.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Nenhum membro escalado encontrado para este culto.',
                                    style: AppTextStyles.body(
                                      color: context.textoSecund,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: ctrl,
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  24 + MediaQuery.of(context).padding.bottom,
                                ),
                                itemCount: visiveis.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, idx) {
                                  final g = visiveis[idx];
                                  return _ChamadaMembroCard(
                                    grupo: g,
                                    onSelectStatus: (st) => _marcarStatus(g, st),
                                    onEditarMotivo: g.statusAtual != null &&
                                            g.statusAtual!.isFalta
                                        ? () => _marcarStatus(
                                              g,
                                              g.statusAtual!,
                                              pedirMotivo: true,
                                            )
                                        : null,
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Modal de Falta Avulsa (Ensaio, Reunião, Evento Extra) ───────────────────
class ModalRegistrarFaltaAvulsa extends ConsumerStatefulWidget {
  final Membro? membroInicial;
  final String? ministerioInicial;

  const ModalRegistrarFaltaAvulsa({
    super.key,
    this.membroInicial,
    this.ministerioInicial,
  });

  @override
  ConsumerState<ModalRegistrarFaltaAvulsa> createState() =>
      _ModalRegistrarFaltaAvulsaState();
}

class _ModalRegistrarFaltaAvulsaState
    extends ConsumerState<ModalRegistrarFaltaAvulsa> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _buscaCtrl = TextEditingController();
  late final TextEditingController _dataCtrl;
  final _horarioCtrl = TextEditingController();

  DateTime _data = DateTime.now();
  TimeOfDay? _horario;
  String _tipoAtividade = 'Ensaio';
  StatusFrequencia _status = StatusFrequencia.falta;
  String? _ministerio;
  final Set<String> _membrosIdsSelecionados = {};
  bool _salvando = false;

  static const _tipos = ['Ensaio', 'Reunião', 'Culto', 'Evento'];

  @override
  void initState() {
    super.initState();
    _dataCtrl = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_data),
    );
    _ministerio = widget.ministerioInicial ?? widget.membroInicial?.ministerio;
    if (_ministerio != null && _ministerio!.isEmpty) _ministerio = null;
    if (widget.membroInicial != null && widget.membroInicial!.id.isNotEmpty) {
      _membrosIdsSelecionados.add(widget.membroInicial!.id);
    }
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _motivoCtrl.dispose();
    _buscaCtrl.dispose();
    _dataCtrl.dispose();
    _horarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membrosAsync = ref.watch(membrosProvider);
    final ministeriosAsync = ref.watch(ministeriosProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      minChildSize: 0.6,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.bgBorda),
        ),
        child: LoadingOverlay(
          loading: _salvando,
          mensagem: 'Salvando registro...',
          child: Form(
            key: _formKey,
            child: ListView(
              controller: ctrl,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    24 +
                    MediaQuery.of(context).padding.bottom,
              ),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: context.bgBorda,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Falta / Presença Avulsa',
                        style: AppTextStyles.heading(
                          color: context.textoPrimario,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        PhosphorIconsBold.x,
                        color: context.textoSecund,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Use para registrar ensaios, reuniões ou faltas fora da escala gerada.',
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                ),
                const SizedBox(height: 16),

                Text(
                  'Tipo de atividade',
                  style: AppTextStyles.bodySmall(
                    color: context.textoPrimario,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tipos.map((t) {
                    final sel = _tipoAtividade == t;
                    return ChoiceChip(
                      label: Text(t),
                      selected: sel,
                      selectedColor: context.acentoSuave,
                      labelStyle: AppTextStyles.bodySmall(
                        color: sel ? context.acentoTexto : context.textoSecund,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) => setState(() => _tipoAtividade = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Text(
                  'Situação a registrar',
                  style: AppTextStyles.bodySmall(
                    color: context.textoPrimario,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StatusFrequencia.values.map((st) {
                    final sel = _status == st;
                    final cor = _corPorStatus(st);
                    return ChoiceChip(
                      label: Text(st.label),
                      selected: sel,
                      selectedColor: cor.withValues(alpha: 0.18),
                      labelStyle: AppTextStyles.bodySmall(
                        color: sel ? cor : context.textoSecund,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) => setState(() => _status = st),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Data *',
                        readOnly: true,
                        controller: _dataCtrl,
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _data,
                            firstDate: DateTime(2024, 1, 1),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) {
                            setState(() {
                              _data = d;
                              _dataCtrl.text = DateFormat('dd/MM/yyyy').format(d);
                            });
                          }
                        },
                        suffixIcon: Icon(
                          PhosphorIconsBold.calendar,
                          color: context.corPrimaria,
                          size: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Horário (opcional)',
                        readOnly: true,
                        hint: 'Selecionar',
                        controller: _horarioCtrl,
                        onTap: () async {
                          final h = await showTimePicker(
                            context: context,
                            initialTime: _horario ??
                                const TimeOfDay(hour: 19, minute: 30),
                          );
                          if (h != null) {
                            setState(() {
                              _horario = h;
                              _horarioCtrl.text =
                                  '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                        suffixIcon: Icon(
                          PhosphorIconsBold.clock,
                          color: context.corPrimaria,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                ministeriosAsync.when(
                  data: (mins) {
                    final items = <String>[
                      ...mins.map((m) => m.nome),
                    ];
                    if (_ministerio != null && !items.contains(_ministerio)) {
                      items.add(_ministerio!);
                    }
                    return DropdownButtonFormField<String?>(
                      initialValue: _ministerio,
                      style: AppTextStyles.body(color: context.textoPrimario),
                      dropdownColor: context.bgCard,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar membros por ministério',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos os ministérios'),
                        ),
                        ...items.map(
                          (m) => DropdownMenuItem<String?>(
                            value: m,
                            child: Text(m),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _ministerio = v),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: 'Descrição da atividade (opcional)',
                  hint: 'Ex: Ensaio de sexta, Reunião de alinhamento...',
                  controller: _descricaoCtrl,
                ),
                const SizedBox(height: 14),

                AppTextField(
                  label: _status == StatusFrequencia.faltaJustificada
                      ? 'Motivo / Justificativa *'
                      : 'Observação / Motivo (opcional)',
                  hint: 'Ex: Avisou com antecedência, trabalho, doença...',
                  controller: _motivoCtrl,
                  maxLines: 2,
                  validator: (v) {
                    if (_status == StatusFrequencia.faltaJustificada &&
                        (v == null || v.trim().isEmpty)) {
                      return 'Informe o motivo da falta justificada';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Membros (${_membrosIdsSelecionados.length} selecionado${_membrosIdsSelecionados.length == 1 ? '' : 's'}) *',
                        style: AppTextStyles.bodySmall(
                          color: context.textoPrimario,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    membrosAsync.maybeWhen(
                      data: (todos) {
                        final elegiveis = _filtrarMembros(todos);
                        final todosSel = elegiveis.isNotEmpty &&
                            elegiveis.every(
                              (m) => _membrosIdsSelecionados.contains(m.id),
                            );
                        return TextButton(
                          onPressed: () {
                            setState(() {
                              if (todosSel) {
                                for (final m in elegiveis) {
                                  _membrosIdsSelecionados.remove(m.id);
                                }
                              } else {
                                for (final m in elegiveis) {
                                  _membrosIdsSelecionados.add(m.id);
                                }
                              }
                            });
                          },
                          child: Text(
                            todosSel ? 'Desmarcar visíveis' : 'Selecionar todos',
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _buscaCtrl,
                  onChanged: (_) => setState(() {}),
                  style: AppTextStyles.body(color: context.textoPrimario),
                  decoration: const InputDecoration(
                    hintText: 'Buscar integrante...',
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                membrosAsync.when(
                  data: (todos) {
                    final filtrados = _filtrarMembros(todos);
                    if (filtrados.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Nenhum integrante encontrado.',
                          style: AppTextStyles.bodySmall(
                            color: context.textoSecund,
                          ),
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filtrados.map((m) {
                        final sel = _membrosIdsSelecionados.contains(m.id);
                        return FilterChip(
                          label: Text(
                            m.nome,
                            style: AppTextStyles.bodySmall(
                              color: sel ? Colors.white : context.textoPrimario,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          selected: sel,
                          selectedColor: _corPorStatus(_status),
                          checkmarkColor: Colors.white,
                          backgroundColor: context.bgSubtle,
                          side: BorderSide(
                            color: sel
                                ? _corPorStatus(_status)
                                : context.bgBorda,
                          ),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _membrosIdsSelecionados.add(m.id);
                              } else {
                                _membrosIdsSelecionados.remove(m.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.acento),
                  ),
                  error: (e, _) => Text('Erro ao carregar membros: $e'),
                ),

                const SizedBox(height: 24),
                AppButton(
                  label: 'Salvar Registro',
                  icon: PhosphorIconsBold.check,
                  loading: _salvando,
                  width: double.infinity,
                  onPressed: () => _salvar(membrosAsync.value ?? []),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Membro> _filtrarMembros(List<Membro> todos) {
    final q = _buscaCtrl.text.trim().toLowerCase();
    return todos.where((m) {
      if (_ministerio != null &&
          _ministerio!.isNotEmpty &&
          m.ministerio != _ministerio) {
        return false;
      }
      if (q.isNotEmpty && !m.nome.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _salvar(List<Membro> todos) async {
    if (_formKey.currentState?.validate() != true) return;
    if (_membrosIdsSelecionados.isEmpty) {
      AppSnackbar.show(
        context,
        'Selecione pelo menos 1 integrante.',
        erro: true,
      );
      return;
    }

    final selecionados =
        todos.where((m) => _membrosIdsSelecionados.contains(m.id)).toList();
    if (selecionados.isEmpty) return;

    setState(() => _salvando = true);
    try {
      final horaStr = _horario == null
          ? ''
          : '${_horario!.hour.toString().padLeft(2, '0')}:${_horario!.minute.toString().padLeft(2, '0')}';
      final liderNome =
          ref.read(userRoleProvider.notifier).selectedMembroNome ?? 'Líder';

      await ref.read(frequenciaRepoProvider).registrarEventoAvulso(
            membros: selecionados,
            ministerio: _ministerio ?? '',
            data: DateFormat('yyyy-MM-dd').format(_data),
            horario: horaStr,
            tipoAtividade: _tipoAtividade,
            descricaoAtividade: _descricaoCtrl.text.trim(),
            status: _status,
            motivo: _motivoCtrl.text.trim(),
            registradoPor: liderNome,
          );

      if (mounted) {
        AppSnackbar.show(
          context,
          'Registro salvo para ${selecionados.length} integrante(s)!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (mounted) {
        if (msg.contains('pgrst205') ||
            msg.contains('42p01') ||
            msg.contains('frequencia_membros')) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Tabela ainda não criada no Supabase'),
              content: const Text(
                'Para registrar faltas avulsas (ensaios, reuniões e justificativas), execute o script "supabase_frequencia.sql" no SQL Editor do seu painel Supabase.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          );
        } else {
          AppSnackbar.show(context, 'Erro ao salvar: $e', erro: true);
        }
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}

// ─── Modal de Detalhamento Individual do Membro ──────────────────────────────
class _ModalDetalheFrequenciaMembro extends ConsumerStatefulWidget {
  final ResumoFrequenciaMembro resumo;

  const _ModalDetalheFrequenciaMembro({required this.resumo});

  @override
  ConsumerState<_ModalDetalheFrequenciaMembro> createState() =>
      _ModalDetalheFrequenciaMembroState();
}

class _ModalDetalheFrequenciaMembroState
    extends ConsumerState<_ModalDetalheFrequenciaMembro> {
  bool _alterado = false;
  bool _processando = false;

  @override
  Widget build(BuildContext context) {
    final resumoAtualAsync = ref.watch(relatorioFrequenciaProvider);
    final resumo = resumoAtualAsync.maybeWhen(
      data: (r) => r.resumos.firstWhere(
        (x) =>
            x.membro.nome.trim().toLowerCase() ==
            widget.resumo.membro.nome.trim().toLowerCase(),
        orElse: () => widget.resumo,
      ),
      orElse: () => widget.resumo,
    );

    final pct = resumo.percentualComparecimento;
    final cor = _corPorPercentual(pct, semRegistros: resumo.semRegistros);

    return PopScope(
      onPopInvokedWithResult: (_, __) {},
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.bgBorda),
          ),
          child: LoadingOverlay(
            loading: _processando,
            mensagem: 'Atualizando...',
            child: Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.bgBorda,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                  child: Row(
                    children: [
                      AppAvatar(name: resumo.membro.nome, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resumo.membro.nome,
                              style: AppTextStyles.heading(
                                color: context.textoPrimario,
                              ),
                            ),
                            if (resumo.membro.ministerio.isNotEmpty)
                              Text(
                                resumo.membro.ministerio,
                                style: AppTextStyles.bodySmall(
                                  color: context.textoSecund,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          resumo.semRegistros
                              ? 'Sem escalas'
                              : '${pct.toStringAsFixed(1)}%',
                          style: AppTextStyles.subheading(color: cor),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, _alterado),
                        icon: Icon(
                          PhosphorIconsBold.x,
                          color: context.textoSecund,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: resumo.semRegistros
                              ? 0
                              : (pct / 100.0).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: context.bgSubtle,
                          color: cor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiMiniBox(
                              titulo: 'Presenças',
                              valor:
                                  '${resumo.presencas}/${resumo.totalCompromissos}',
                              cor: AppColors.sucesso,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _KpiMiniBox(
                              titulo: 'Faltas',
                              valor: '${resumo.faltasNaoJustificadas}',
                              cor: resumo.faltasNaoJustificadas > 0
                                  ? AppColors.perigo
                                  : context.textoMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _KpiMiniBox(
                              titulo: 'Justificadas',
                              valor: '${resumo.faltasJustificadas}',
                              cor: resumo.faltasJustificadas > 0
                                  ? AppColors.alerta
                                  : context.textoMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await abrirModalFaltaAvulsa(
                              context,
                              ref,
                              membroInicial: resumo.membro,
                              ministerioInicial: resumo.membro.ministerio,
                            );
                            if (ok == true) {
                              _alterado = true;
                            }
                          },
                          icon: const Icon(
                            PhosphorIconsBold.calendarX,
                            size: 17,
                          ),
                          label: const Text('Registrar Falta Avulsa para este Membro'),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.bgBorda),
                Expanded(
                  child: resumo.historico.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Nenhum compromisso realizado para ${resumo.membro.nome} neste período.',
                              style: AppTextStyles.body(
                                color: context.textoSecund,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: ctrl,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            24 + MediaQuery.of(context).padding.bottom,
                          ),
                          itemCount: resumo.historico.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final item = resumo.historico[idx];
                            final stCor = _corPorStatus(item.status);
                            final labelSt = item.status ==
                                        StatusFrequencia.presente &&
                                    !item.confirmadoExplicitamente
                                ? 'Presença (escala)'
                                : item.status.label;

                            return AppSurfaceCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              borderRadius: 16,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(
                                      color: stCor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${_formatarDataCurta(item.data)}${item.horario.isNotEmpty ? ' • ${item.horario}' : ''}',
                                                style: AppTextStyles.body(
                                                  color: context.textoPrimario,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: stCor.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                labelSt,
                                                style: AppTextStyles.label(
                                                  color: stCor,
                                                ).copyWith(fontSize: 11.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${item.tipoAtividade} • ${item.descricao}',
                                          style: AppTextStyles.bodySmall(
                                            color: context.textoSecund,
                                          ),
                                        ),
                                        if (item.motivo.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Motivo: ${item.motivo}',
                                            style: AppTextStyles.bodySmall(
                                              color: context.textoMuted,
                                            ).copyWith(
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      PhosphorIconsBold.dotsThreeVertical,
                                      color: context.textoSecund,
                                      size: 18,
                                    ),
                                    onSelected: (op) => _alterarHistorico(
                                      context,
                                      resumo,
                                      item,
                                      op,
                                    ),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'presente',
                                        child: Text('Marcar Presente'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'falta',
                                        child: Text('Marcar Falta'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'justificada',
                                        child: Text('Falta Justificada'),
                                      ),
                                      if (item.escalaIds.isEmpty &&
                                          item.registroId != null)
                                        const PopupMenuItem(
                                          value: 'excluir',
                                          child: Text(
                                            'Excluir registro avulso',
                                            style: TextStyle(
                                              color: AppColors.perigo,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _alterarHistorico(
    BuildContext context,
    ResumoFrequenciaMembro resumo,
    ItemHistoricoFrequencia item,
    String op,
  ) async {
    final repo = ref.read(frequenciaRepoProvider);

    if (op == 'excluir' && item.registroId != null) {
      final ok = await ConfirmDialog.show(
        context,
        titulo: 'Excluir registro avulso',
        mensagem: 'Remover este registro do histórico?',
        labelConfirmar: 'Excluir',
        perigo: true,
      );
      if (!ok) return;

      setState(() => _processando = true);
      try {
        await repo.excluirRegistro(
          FrequenciaRegistro(
            id: item.registroId!,
            membroNome: item.membroNome,
            ministerio: item.ministerio,
            data: item.data,
            horario: item.horario,
            tipoAtividade: item.tipoAtividade,
            descricaoAtividade: item.descricao,
            status: item.status,
            motivo: item.motivo,
            registradoPor: '',
            createdAt: DateTime.now(),
          ),
        );
        _alterado = true;
        _invalidarFrequencia(ref);
      } finally {
        if (mounted) setState(() => _processando = false);
      }
      return;
    }

    late StatusFrequencia novoStatus;
    String motivo = item.motivo;
    if (op == 'presente') {
      novoStatus = StatusFrequencia.presente;
      motivo = '';
    } else if (op == 'falta') {
      novoStatus = StatusFrequencia.falta;
      final resp = await _pedirMotivoDialog(
        context,
        titulo: 'Observação da falta',
        subtitulo: '${resumo.membro.nome} • ${_formatarDataCurta(item.data)}',
        valorInicial: item.motivo,
        obrigatorio: false,
      );
      if (resp == null) return;
      motivo = resp;
    } else {
      novoStatus = StatusFrequencia.faltaJustificada;
      final resp = await _pedirMotivoDialog(
        context,
        titulo: 'Justificar falta',
        subtitulo: '${resumo.membro.nome} • ${_formatarDataCurta(item.data)}',
        valorInicial: item.motivo,
        obrigatorio: true,
      );
      if (resp == null) return;
      motivo = resp;
    }

    setState(() => _processando = true);
    try {
      final liderNome =
          ref.read(userRoleProvider.notifier).selectedMembroNome ?? 'Líder';

      if (item.escalaIds.isNotEmpty) {
        // Reconstrói itens mínimos para atualizar todos os registros de escala do culto
        final itensEscala = item.escalaIds
            .map(
              (id) => EscalaItem(
                id: id,
                data: item.data,
                diaSemana: '',
                horario: item.horario,
                ministerio: item.ministerio,
                nome: item.membroNome,
                funcao: '',
                tema: '',
                statusConvite: novoStatus.code,
                tituloMensagem: '',
                textoBiblico: '',
                createdAt: DateTime.now(),
              ),
            )
            .toList();

        await repo.registrarChamadaEscala(
          itensDoMembroNoCulto: itensEscala,
          status: novoStatus,
          motivo: motivo,
          membroId: resumo.membro.id.isNotEmpty ? resumo.membro.id : null,
          registradoPor: liderNome,
        );
      } else if (item.registroId != null) {
        await repo.atualizarRegistro(
          registro: FrequenciaRegistro(
            id: item.registroId!,
            membroNome: item.membroNome,
            ministerio: item.ministerio,
            data: item.data,
            horario: item.horario,
            tipoAtividade: item.tipoAtividade,
            descricaoAtividade: item.descricao,
            status: item.status,
            motivo: item.motivo,
            registradoPor: liderNome,
            createdAt: DateTime.now(),
          ),
          novoStatus: novoStatus,
          novoMotivo: motivo,
        );
      }

      _alterado = true;
      _invalidarFrequencia(ref);
      if (context.mounted) {
        AppSnackbar.show(context, 'Frequência atualizada!');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(context, 'Erro ao atualizar: $e', erro: true);
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }
}

// ─── Componentes Visuais Auxiliares ──────────────────────────────────────────
class _SubTabPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ativo;
  final VoidCallback onTap;

  const _SubTabPill({
    required this.icon,
    required this.label,
    required this.ativo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ativo ? context.bgCard : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: ativo
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isDark ? 0.25 : 0.06,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: ativo ? context.corPrimaria : context.textoSecund,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall(
                    color: ativo ? context.textoPrimario : context.textoSecund,
                    fontWeight: ativo ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selecionado ? AppColors.acento : context.bgCard,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selecionado ? AppColors.acento : context.bgBorda,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodySmall(
                color: selecionado ? Colors.white : context.textoSecund,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiMiniBox extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? detalhe;
  final Color cor;

  const _KpiMiniBox({
    required this.titulo,
    required this.valor,
    this.detalhe,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: context.isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: AppTextStyles.label(color: context.textoSecund)
                .copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: AppTextStyles.heading(color: cor).copyWith(fontSize: 21),
          ),
          if (detalhe != null && detalhe!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detalhe!,
              style: AppTextStyles.label(color: context.textoMuted)
                  .copyWith(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _MembroFrequenciaCard extends StatelessWidget {
  final ResumoFrequenciaMembro resumo;
  final VoidCallback onTap;

  const _MembroFrequenciaCard({
    required this.resumo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = resumo.percentualComparecimento;
    final cor = _corPorPercentual(pct, semRegistros: resumo.semRegistros);

    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      borderRadius: 18,
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(name: resumo.membro.nome, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resumo.membro.nome,
                      style: AppTextStyles.subheading(
                        color: context.textoPrimario,
                      ),
                    ),
                    if (resumo.membro.ministerio.isNotEmpty)
                      Text(
                        resumo.membro.ministerio,
                        style: AppTextStyles.bodySmall(
                          color: context.textoSecund,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  resumo.semRegistros
                      ? 'Sem escalas'
                      : '${pct.toStringAsFixed(0)}%',
                  style: AppTextStyles.mono(color: cor).copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: resumo.semRegistros ? 0 : (pct / 100.0).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: context.bgSubtle,
              color: cor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniStatusTag(
                      label:
                          'Presenças: ${resumo.presencas}/${resumo.totalCompromissos}',
                      cor: AppColors.sucesso,
                    ),
                    _MiniStatusTag(
                      label: 'Faltas: ${resumo.totalFaltas}',
                      cor: resumo.totalFaltas > 0
                          ? AppColors.perigo
                          : context.textoMuted,
                    ),
                    if (resumo.faltasJustificadas > 0)
                      _MiniStatusTag(
                        label: '${resumo.faltasJustificadas} justificada(s)',
                        cor: AppColors.alerta,
                      ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsBold.caretRight,
                color: context.textoMuted,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatusTag extends StatelessWidget {
  final String label;
  final Color cor;

  const _MiniStatusTag({required this.label, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: context.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.label(color: cor).copyWith(fontSize: 11.5),
      ),
    );
  }
}

class _ChamadaMembroCard extends StatelessWidget {
  final _GrupoMembroCulto grupo;
  final void Function(StatusFrequencia) onSelectStatus;
  final VoidCallback? onEditarMotivo;

  const _ChamadaMembroCard({
    required this.grupo,
    required this.onSelectStatus,
    this.onEditarMotivo,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: grupo.nome, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grupo.nome,
                      style: AppTextStyles.body(
                        color: context.textoPrimario,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      grupo.funcoesLabel.isNotEmpty
                          ? '${grupo.ministerio} • ${grupo.funcoesLabel}'
                          : grupo.ministerio,
                      style: AppTextStyles.bodySmall(
                        color: context.textoSecund,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEditarMotivo != null)
                IconButton(
                  tooltip: 'Editar motivo/observação',
                  onPressed: onEditarMotivo,
                  icon: Icon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 18,
                    color: context.corPrimaria,
                  ),
                ),
            ],
          ),
          if (grupo.motivo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Motivo: ${grupo.motivo}',
              style: AppTextStyles.bodySmall(color: context.textoMuted)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusActionPill(
                  label: 'Presente',
                  icon: PhosphorIconsBold.checkCircle,
                  ativo: grupo.statusAtual == StatusFrequencia.presente,
                  cor: AppColors.sucesso,
                  onTap: () => onSelectStatus(StatusFrequencia.presente),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatusActionPill(
                  label: 'Falta',
                  icon: PhosphorIconsBold.xCircle,
                  ativo: grupo.statusAtual == StatusFrequencia.falta,
                  cor: AppColors.perigo,
                  onTap: () => onSelectStatus(StatusFrequencia.falta),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatusActionPill(
                  label: 'Justificada',
                  icon: PhosphorIconsBold.warningCircle,
                  ativo:
                      grupo.statusAtual == StatusFrequencia.faltaJustificada,
                  cor: AppColors.alerta,
                  onTap: () =>
                      onSelectStatus(StatusFrequencia.faltaJustificada),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool ativo;
  final Color cor;
  final VoidCallback onTap;

  const _StatusActionPill({
    required this.label,
    required this.icon,
    required this.ativo,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ativo ? cor : context.bgSubtle,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: ativo ? cor : context.bgBorda,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: ativo ? Colors.white : cor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(
                    color: ativo ? Colors.white : context.textoPrimario,
                    fontWeight: FontWeight.w700,
                  ).copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistroFrequenciaCard extends StatelessWidget {
  final FrequenciaRegistro registro;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RegistroFrequenciaCard({
    required this.registro,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cor = _corPorStatus(registro.status);

    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(name: registro.membroNome, size: 38, accentColor: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        registro.membroNome,
                        style: AppTextStyles.body(
                          color: context.textoPrimario,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _MiniStatusTag(label: registro.status.label, cor: cor),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatarDataCurta(registro.data)}${registro.horario.isNotEmpty ? ' • ${registro.horario}' : ''} • ${registro.tipoAtividade}'
                  '${registro.descricaoAtividade.isNotEmpty ? ' (${registro.descricaoAtividade})' : ''}',
                  style: AppTextStyles.bodySmall(color: context.textoSecund),
                ),
                if (registro.motivo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Motivo: ${registro.motivo}',
                    style: AppTextStyles.bodySmall(color: context.textoMuted)
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            children: [
              IconButton(
                tooltip: 'Editar',
                onPressed: onEdit,
                icon: Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 18,
                  color: context.corPrimaria,
                ),
              ),
              IconButton(
                tooltip: 'Excluir',
                onPressed: onDelete,
                icon: const Icon(
                  PhosphorIconsRegular.trash,
                  size: 18,
                  color: AppColors.perigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerSqlPendente extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.alerta.withValues(alpha: context.isDark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.alerta.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsBold.warningCircle,
            color: AppColors.alerta,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Para habilitar faltas avulsas (ensaios/reuniões) e salvar justificativas, execute o script supabase_frequencia.sql no SQL Editor do Supabase. Enquanto isso, as chamadas pelas escalas continuam funcionando normalmente.',
              style: AppTextStyles.bodySmall(color: context.textoPrimario),
            ),
          ),
        ],
      ),
    );
  }
}
