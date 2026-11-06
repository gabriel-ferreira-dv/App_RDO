import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../domain/entities/campos_do_registro.dart';
import '../../domain/regras/correcao_de_registro.dart';
import '../viewmodels/editar_registro_view_model.dart';
import '../widgets/campo_pesquisa_unico.dart';

// Correção de um registro já feito. Devolve os campos corrigidos (ou null se a
// pessoa desistir ou nada mudar); quem chama decide onde gravar (no aparelho
// ou no servidor).
class EditarRegistroPage extends StatefulWidget {
  final CamposDoRegistro campos;

  // Contexto mostrado no topo ("Feito em 12/10 às 08:15", "De João").
  final String subtitulo;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final EditarRegistroViewModel? viewModel;

  const EditarRegistroPage({
    super.key,
    required this.campos,
    this.subtitulo = '',
    this.viewModel,
  });

  @override
  State<EditarRegistroPage> createState() => _EditarRegistroPageState();
}

class _EditarRegistroPageState extends State<EditarRegistroPage> {
  late final EditarRegistroViewModel _vm =
      widget.viewModel ?? Dependencias.editarRegistro(widget.campos);
  late final _quantidade = TextEditingController(text: _vm.quantidadeInicial);
  late final _descricao = TextEditingController(text: _vm.descricaoInicial);

  @override
  void initState() {
    super.initState();
    _vm.carregar();
  }

  @override
  void dispose() {
    _quantidade.dispose();
    _descricao.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _salvar() {
    final resultado = _vm.salvar(
        textoQuantidade: _quantidade.text, descricao: _descricao.text);
    switch (resultado) {
      case CorrecaoInvalida(:final erro):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(erro)));
      case SemMudanca():
        Navigator.of(context).pop();
      case Corrigido(:final campos):
        Navigator.of(context).pop(campos);
    }
  }

  void _semMedicao() {
    _quantidade.clear();
    _vm.escolherUnidade(null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Corrigir registro')),
        body: _vm.carregando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Explicacao(subtitulo: widget.subtitulo),
                  ..._local(),
                  ..._servico(),
                  _Medicao(
                    quantidade: _quantidade,
                    unidade: _vm.unidade,
                    aoEscolherUnidade: _vm.escolherUnidade,
                    aoLimpar: _semMedicao,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _descricao,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      onPressed: _salvar,
                      icon: const Icon(Icons.check),
                      label: const Text('Salvar correção'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _local() => [
        CampoPesquisaUnico(
          items: _vm.trechos,
          textoPesquisa: 'Trecho',
          initialValue: _vm.trecho,
          onSelected: _vm.escolherTrecho,
        ),
        if (_vm.pedeKm)
          CampoPesquisaUnico(
            items: _vm.kms,
            textoPesquisa: 'KM',
            initialValue: _vm.km,
            enabled: _vm.trecho != null,
            onSelected: _vm.escolherKm,
          ),
        if (_vm.pedeVia)
          _SeletorDeVia(
            vias: _vm.vias,
            escolhida: _vm.via,
            aoEscolher: _vm.escolherVia,
          ),
        if (_vm.pedeEstaca) ...[
          CampoPesquisaUnico(
            items: _vm.rotulosDasEstacas,
            textoPesquisa: 'Estaca inicial',
            initialValue: _vm.rotuloNoCampo(_vm.estacaInicial),
            enabled: _vm.temEstacas,
            onSelected: _vm.escolherEstacaInicial,
          ),
          CampoPesquisaUnico(
            items: _vm.rotulosDasEstacas,
            textoPesquisa: 'Estaca final',
            initialValue: _vm.rotuloNoCampo(_vm.estacaFinal),
            enabled: _vm.temEstacas,
            onSelected: _vm.escolherEstacaFinal,
          ),
        ],
      ];

  List<Widget> _servico() => [
        CampoPesquisaUnico(
          items: _vm.atividades,
          textoPesquisa: 'Atividade',
          initialValue: _vm.atividade,
          enabled: _vm.trecho != null,
          onSelected: _vm.escolherAtividade,
        ),
        CampoPesquisaUnico(
          items: _vm.servicos,
          textoPesquisa: 'Serviço',
          initialValue: _vm.servico,
          enabled: _vm.atividade != null,
          onSelected: _vm.escolherServico,
        ),
        CampoPesquisaUnico(
          items: _vm.passos,
          textoPesquisa: 'Passo do serviço',
          initialValue: _vm.passo,
          enabled: _vm.passos.isNotEmpty,
          onSelected: _vm.escolherPasso,
        ),
      ];
}

class _Explicacao extends StatelessWidget {
  final String subtitulo;

  const _Explicacao({required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        [
          if (subtitulo.isNotEmpty) subtitulo,
          'Data, hora, coordenada e minimapa da foto não mudam. '
              'O carimbo das fotos é refeito com os dados corrigidos.',
        ].join('\n'),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

// Sentido da via em pista dupla (a primeira é a sul, a segunda a norte).
class _SeletorDeVia extends StatelessWidget {
  final List<String> vias;
  final String? escolhida;
  final ValueChanged<String?> aoEscolher;

  const _SeletorDeVia({
    required this.vias,
    required this.escolhida,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(
              value: vias[0],
              label: Text(vias[0]),
              icon: const Icon(Icons.south)),
          ButtonSegment(
              value: vias[1],
              label: Text(vias[1]),
              icon: const Icon(Icons.north)),
        ],
        selected: {if (escolhida != null) escolhida!},
        emptySelectionAllowed: true,
        onSelectionChanged: (selecao) =>
            aoEscolher(selecao.isEmpty ? null : selecao.first),
      ),
    );
  }
}

// Quantidade e unidade da medição; o X tira a medição.
class _Medicao extends StatelessWidget {
  final TextEditingController quantidade;
  final String? unidade;
  final ValueChanged<String?> aoEscolherUnidade;
  final VoidCallback aoLimpar;

  const _Medicao({
    required this.quantidade,
    required this.unidade,
    required this.aoEscolherUnidade,
    required this.aoLimpar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: quantidade,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: unidade,
            hint: const Text('Unidade'),
            items: [
              for (final u in unidadesDeMedicao)
                DropdownMenuItem(value: u, child: Text(u)),
            ],
            onChanged: aoEscolherUnidade,
          ),
          if (unidade != null)
            IconButton(
              tooltip: 'Sem medição',
              icon: const Icon(Icons.clear),
              onPressed: aoLimpar,
            ),
        ],
      ),
    );
  }
}
