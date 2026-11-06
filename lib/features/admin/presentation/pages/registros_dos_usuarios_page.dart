import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../../../core/widgets/foto_em_tela_cheia.dart';
import '../../../../core/widgets/seletor_de_dia.dart';
import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../registro/presentation/pages/editar_registro_page.dart';
import '../../../supervisor/domain/entities/registro_da_equipe.dart';
import '../viewmodels/registros_dos_usuarios_view_model.dart';
import '../widgets/aviso_da_lista.dart';
import '../widgets/cabecalho_do_usuario.dart';
import '../widgets/cartao_registro_do_usuario.dart';

// Só para o admin do painel: os registros de todos os usuários num dia, com a
// busca pelo nome e o Corrigir. A correção vale para o usuário também: o
// celular dele refaz o carimbo da foto quando sincronizar.
class RegistrosDosUsuariosPage extends StatefulWidget {
  // Para testes: um ViewModel já montado no lugar do padrão.
  final RegistrosDosUsuariosViewModel? viewModel;

  const RegistrosDosUsuariosPage({super.key, this.viewModel});

  @override
  State<RegistrosDosUsuariosPage> createState() =>
      _RegistrosDosUsuariosPageState();
}

class _RegistrosDosUsuariosPageState extends State<RegistrosDosUsuariosPage> {
  late final RegistrosDosUsuariosViewModel _vm =
      widget.viewModel ?? Dependencias.registrosDosUsuarios();
  final _busca = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _corrigir(RegistroDaEquipe registro) async {
    final corrigidos = await Navigator.of(context).push<CamposDoRegistro>(
      MaterialPageRoute(
        builder: (_) => EditarRegistroPage(
          campos: registro.campos,
          subtitulo: _vm.subtituloDaCorrecao(registro),
        ),
      ),
    );
    if (corrigidos == null || !mounted) return;
    final mensagem = await _vm.corrigir(registro, corrigidos);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _vm.carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Embaixo, folga para o botão do meio da barra.
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 56),
          children: [
            SeletorDeDia(dia: _vm.dia, aoMudar: _vm.mudarDia),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _busca,
                onChanged: _vm.definirBusca,
                decoration: const InputDecoration(
                  hintText: 'Buscar pelo nome ou matrícula',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            ..._lista(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _lista(BuildContext context) => switch (_vm.situacao) {
        SituacaoDaLista.carregando => const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        SituacaoDaLista.falhou => const [
            AvisoDaLista(
              icone: Icons.cloud_off_outlined,
              titulo: 'Não foi possível buscar os registros',
              detalhe: 'Confira a internet e puxe a lista para baixo.',
            ),
          ],
        SituacaoDaLista.vazia => [
            AvisoDaLista(
              icone: Icons.photo_library_outlined,
              titulo: 'Nenhum registro neste dia',
              detalhe: _vm.detalheDaListaVazia,
            ),
          ],
        SituacaoDaLista.pronta => [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                _vm.resumo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            for (final g in _vm.grupos) ...[
              CabecalhoDoUsuario(nome: _vm.nomeDe(g), resumo: _vm.resumoDe(g)),
              for (final r in g.registros)
                CartaoRegistroDoUsuario(
                  registro: r,
                  fotos: _vm.fotosDe(r),
                  aoCorrigir: () => _corrigir(r),
                  aoAbrirFoto: (endereco) =>
                      mostrarFotoEmTelaCheia(context, endereco),
                ),
            ],
          ],
      };
}
