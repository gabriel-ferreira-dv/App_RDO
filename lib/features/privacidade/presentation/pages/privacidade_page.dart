import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../domain/entities/aviso_de_privacidade.dart';
import '../viewmodels/privacidade_view_model.dart';
import '../widgets/aviso_indisponivel.dart';
import '../widgets/barra_de_ciencia.dart';
import '../widgets/texto_do_aviso.dart';

// Tela do aviso de privacidade. Só desenha o estado do ViewModel e repassa
// os toques; abra pela rota em app/rotas.dart. A tela é dona do ViewModel:
// cria uma vez só, no State (o builder da rota pode rodar de novo), e o
// descarta ao fechar.
class PrivacidadePage extends StatefulWidget {
  // Quem lê; vazio antes do login.
  final String email;

  // Aviso novo que pede "Li e entendi"; null = só consulta.
  final AvisoDePrivacidade? avisoPendente;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final PrivacidadeViewModel? viewModel;

  const PrivacidadePage({
    super.key,
    this.email = '',
    this.avisoPendente,
    this.viewModel,
  });

  @override
  State<PrivacidadePage> createState() => _PrivacidadePageState();
}

class _PrivacidadePageState extends State<PrivacidadePage> {
  late final PrivacidadeViewModel _vm = widget.viewModel ??
      Dependencias.privacidade(
          email: widget.email, avisoPendente: widget.avisoPendente);

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

  Future<void> _confirmar() async {
    if (await _vm.confirmar() && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => PopScope(
        canPop: !_vm.pedirCiencia,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Aviso de privacidade'),
            automaticallyImplyLeading: !_vm.pedirCiencia,
          ),
          bottomNavigationBar: _vm.pedirCiencia
              ? BarraDeCiencia(aoConfirmar: _vm.confirmando ? null : _confirmar)
              : null,
          body: switch (_vm.situacao) {
            SituacaoDoAviso.carregando =>
              const Center(child: CircularProgressIndicator()),
            SituacaoDoAviso.indisponivel =>
              AvisoIndisponivel(aoTentarDeNovo: _vm.carregar),
            SituacaoDoAviso.pronto =>
              TextoDoAviso(versaoEData: _vm.versaoEData, linhas: _vm.linhas),
          },
        ),
      ),
    );
  }
}
