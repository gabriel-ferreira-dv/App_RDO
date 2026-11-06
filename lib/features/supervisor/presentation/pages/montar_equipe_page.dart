import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../../../core/theme/cores_app.dart';
import '../../domain/entities/encarregado_da_equipe.dart';
import '../viewmodels/montar_equipe_view_model.dart';

// Escolha dos encarregados da equipe do supervisor. Fecha com a equipe salva.
class MontarEquipePage extends StatefulWidget {
  final String supervisorMatricula;
  final List<EncarregadoDaEquipe> equipeAtual;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final MontarEquipeViewModel? viewModel;

  const MontarEquipePage({
    super.key,
    required this.supervisorMatricula,
    required this.equipeAtual,
    this.viewModel,
  });

  @override
  State<MontarEquipePage> createState() => _MontarEquipePageState();
}

class _MontarEquipePageState extends State<MontarEquipePage> {
  late final MontarEquipeViewModel _vm = widget.viewModel ??
      Dependencias.montarEquipe(widget.supervisorMatricula, widget.equipeAtual);

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

  Future<void> _salvar() async {
    final salvo = await _vm.salvar();
    if (!mounted) return;
    if (salvo.erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(salvo.erro!)));
      return;
    }
    Navigator.of(context).pop(salvo.equipe);
  }

  Widget _lista(List<EncarregadoDaEquipe> visiveis) => ListView.builder(
        itemCount: visiveis.length,
        itemBuilder: (_, i) {
          final e = visiveis[i];
          return CheckboxListTile(
            dense: true,
            value: _vm.marcado(e),
            title: Text(e.nome, style: const TextStyle(fontSize: 14)),
            subtitle:
                Text(_vm.subtituloDe(e), style: const TextStyle(fontSize: 12)),
            onChanged: (sim) => _vm.marcar(e, sim == true),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Minha equipe'),
          actions: [
            // Na cor do cabeçalho: a primária é a mesma do fundo e o Salvar
            // ficava invisível.
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: cores.noCabecalho,
                disabledForegroundColor: cores.noCabecalhoSuave,
              ),
              onPressed: _vm.salvando ? null : _salvar,
              child: Text(_vm.salvando ? 'Salvando…' : 'Salvar'),
            ),
          ],
        ),
        body: _vm.carregando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      onChanged: _vm.definirFiltro,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Buscar por nome ou matrícula',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_vm.selecionados,
                          style: Theme.of(context).textTheme.labelMedium),
                    ),
                  ),
                  Expanded(
                    child: _vm.semEncarregados
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Nenhum encarregado encontrado no apontamento '
                                'dos últimos dias. Verifique a conexão e se o '
                                'apontamento foi importado.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _lista(_vm.visiveis),
                  ),
                ],
              ),
      ),
    );
  }
}
