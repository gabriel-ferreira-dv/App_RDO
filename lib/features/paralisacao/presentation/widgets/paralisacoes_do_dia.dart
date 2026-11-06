import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../../../app/rotas.dart';
import '../../../auth/models/usuario.dart';
import '../../domain/entities/paralisacao.dart';
import '../viewmodels/paralisacoes_do_dia_view_model.dart';
import 'cartao_parado_agora.dart';
import 'linha_da_paralisacao.dart';

// Paralisações de um dia de trabalho, com registrar e retomar. Vai na aba
// Paradas e no formulário do RDO; monta o próprio ViewModel.
class ParalisacoesDoDia extends StatefulWidget {
  final Usuario usuario;

  // Dia de trabalho; null = o de agora (respeita o turno da noite).
  final DateTime? dia;

  // Chamado depois de registrar, editar ou retomar.
  final VoidCallback? aoMudar;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final ParalisacoesDoDiaViewModel? viewModel;

  const ParalisacoesDoDia({
    super.key,
    required this.usuario,
    this.dia,
    this.aoMudar,
    this.viewModel,
  });

  @override
  State<ParalisacoesDoDia> createState() => _ParalisacoesDoDiaState();
}

class _ParalisacoesDoDiaState extends State<ParalisacoesDoDia> {
  late final ParalisacoesDoDiaViewModel _vm = widget.viewModel ??
      Dependencias.paralisacoesDoDia(
        usuario: widget.usuario,
        dia: widget.dia,
        aoMudar: () => widget.aoMudar?.call(),
      );

  @override
  void initState() {
    super.initState();
    _vm.carregar();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _abrir([Paralisacao? paralisacao]) async {
    await Rotas.formularioDeParalisacao(
      context,
      usuarioId: _vm.usuarioId,
      dia: _vm.dia,
      noturno: _vm.noturno,
      paralisacao: paralisacao,
    );
    await _vm.depoisDeEditar();
  }

  Future<void> _retomar(Paralisacao p) async {
    final mensagem = await _vm.retomar(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecalho(titulo: _vm.titulo, totalParado: _vm.totalParado),
              const SizedBox(height: 8),
              if (_vm.carregando)
                const Center(child: CircularProgressIndicator())
              else
                ..._conteudo(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudo(BuildContext context) {
    final theme = Theme.of(context);
    final resumo = _vm.resumo;
    return [
      for (final p in resumo.emAndamento)
        CartaoParadoAgora(
          titulo: _vm.paradoDesde(p),
          detalhe: p.localEObservacao,
          aoRetomar: () => _retomar(p),
          aoEditar: () => _abrir(p),
        ),
      if (resumo.semParalisacoes)
        Text(
          _vm.semParalisacoes,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      for (final p in resumo.encerradas)
        LinhaDaParalisacao(
          descricao: p.descricao,
          fotos: resumo.fotosDe(p),
          aoTocar: () => _abrir(p),
        ),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => _abrir(),
        icon: const Icon(Icons.add),
        label: const Text('Registrar paralisação'),
      ),
    ];
  }
}

class _Cabecalho extends StatelessWidget {
  final String titulo;
  final String totalParado;

  const _Cabecalho({required this.titulo, required this.totalParado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.pause_circle_outline, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (totalParado.isNotEmpty)
          Text(totalParado, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
