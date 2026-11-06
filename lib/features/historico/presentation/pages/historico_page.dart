import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../../../core/widgets/galeria_imagens_page.dart';
import '../../../auth/models/usuario.dart';
import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../registro/domain/entities/grupo_atividade.dart';
import '../../../registro/presentation/pages/editar_registro_page.dart';
import '../viewmodels/historico_view_model.dart';
import '../widgets/cartao_do_registro.dart';
import '../widgets/filtro_de_periodo.dart';
import '../widgets/historico_vazio.dart';
import '../widgets/titulo_do_dia.dart';

// Registros do usuário, do mais recente para o mais antigo, com o filtro de
// período. Tocar abre as fotos; o lápis abre a correção.
class HistoricoPage extends StatefulWidget {
  final Usuario usuario;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final HistoricoViewModel? viewModel;

  const HistoricoPage({super.key, required this.usuario, this.viewModel});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  late final HistoricoViewModel _vm =
      widget.viewModel ?? Dependencias.historico(widget.usuario);

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

  void _abrirFotos(RegistroAgrupado registro) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GaleriaImagensPage(
        fotos: registro.fotos.map((f) => f.caminhoArquivo).toList(),
        descricao: registro.descricao,
      ),
    ));
  }

  Future<void> _corrigir(RegistroAgrupado registro) async {
    final campos = await _vm.camposParaCorrigir(registro);
    if (campos == null || !mounted) return;
    final corrigidos = await Navigator.of(context).push<CamposDoRegistro>(
      MaterialPageRoute(
        builder: (_) => EditarRegistroPage(
          campos: campos,
          subtitulo: _vm.subtituloDaCorrecao(registro),
        ),
      ),
    );
    if (corrigidos == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Refazendo o carimbo das fotos...')),
          ],
        ),
      ),
    );
    final corrigiu = await _vm.corrigir(registro, corrigidos);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(corrigiu
          ? 'Registro corrigido'
          : 'Não foi possível corrigir o registro. Tente de novo.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Column(
        children: [
          FiltroDePeriodo(
            escolhido: _vm.periodo,
            aoEscolher: _vm.escolherPeriodo,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _vm.carregar,
              child: _conteudo(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conteudo() {
    if (_vm.carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    final linhas = _vm.linhas;
    if (linhas.isEmpty && _vm.falhou) {
      return const HistoricoVazio(
        mensagem: 'Não foi possível abrir o histórico',
        detalhe: 'Puxe para baixo para tentar de novo',
      );
    }
    if (linhas.isEmpty) {
      return HistoricoVazio(
        mensagem: _vm.periodo.semRegistros,
        aoVerTodos: _vm.podeVerTodos ? _vm.verTodos : null,
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Embaixo, folga para o botão do meio da barra.
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 56),
      children: [
        for (final linha in linhas)
          switch (linha) {
            CabecalhoDoDia(:final texto) => TituloDoDia(texto),
            RegistroNaLista(:final item) => CartaoDoRegistro(
                item: item,
                aoAbrir: () => _abrirFotos(item.registro),
                aoCorrigir: () => _corrigir(item.registro),
              ),
          },
      ],
    );
  }
}
