import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../../../core/widgets/filtro_dia_dropdown.dart';
import '../../../auth/models/usuario.dart';
import '../viewmodels/importar_atividade_view_model.dart';
import '../widgets/cartao_de_registro_anterior.dart';

// Lista os registros anteriores do usuário para servir de modelo a um novo
// registro. Ao tocar num item, a página fecha devolvendo o Registro escolhido
// (Navigator.pop(registro)).
class ImportarAtividadePage extends StatefulWidget {
  final Usuario usuario;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final ImportarAtividadeViewModel? viewModel;

  const ImportarAtividadePage(
      {super.key, required this.usuario, this.viewModel});

  @override
  State<ImportarAtividadePage> createState() => _ImportarAtividadePageState();
}

class _ImportarAtividadePageState extends State<ImportarAtividadePage> {
  late final ImportarAtividadeViewModel _vm =
      widget.viewModel ?? Dependencias.importarAtividade(widget.usuario);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar atividade anterior')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.carregando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_vm.falhou) {
            return const _SemRegistros(
                'Não foi possível ler os registros anteriores');
          }
          if (_vm.semRegistros) {
            return const _SemRegistros('Nenhum registro anterior encontrado');
          }
          final registros = _vm.registros;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            // +1 para o cabeçalho (instrução + filtro por dia).
            itemCount: registros.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Cabecalho(
                  dias: _vm.dias,
                  diaFiltro: _vm.diaFiltro,
                  aoFiltrar: _vm.filtrarPorDia,
                );
              }
              final r = registros[index - 1];
              return CartaoDeRegistroAnterior(
                registro: r,
                titulo: _vm.titulo(r),
                data: _vm.data(r),
                aoEscolher: () => Navigator.of(context).pop(r),
              );
            },
          );
        },
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final List<DateTime> dias;
  final DateTime? diaFiltro;
  final ValueChanged<DateTime?> aoFiltrar;

  const _Cabecalho({
    required this.dias,
    required this.diaFiltro,
    required this.aoFiltrar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toque numa atividade para reaproveitar os campos dela num novo '
            'registro.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FiltroDiaDropdown(
            dias: dias,
            selecionado: diaFiltro,
            onSelected: aoFiltrar,
          ),
        ],
      ),
    );
  }
}

class _SemRegistros extends StatelessWidget {
  final String mensagem;

  const _SemRegistros(this.mensagem);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(mensagem),
        ],
      ),
    );
  }
}
