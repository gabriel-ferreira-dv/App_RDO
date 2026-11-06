import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../auth/models/usuario.dart';
import '../../../camera/presentation/pages/camera_page.dart';
import '../../domain/entities/registro.dart';
import '../viewmodels/formulario_de_registro.dart';
import '../widgets/etapa_local.dart';
import '../widgets/etapa_servico.dart';
import '../widgets/guia_das_atividades.dart';
import 'importar_atividade_page.dart';
import '../../../../app/dependencias.dart';

// Aba Registro: as etapas Local e Serviço; a terceira é a câmera. O estado e
// as regras ficam no FormularioDeRegistro; aqui só os avisos e a navegação.
class RegistroPage extends StatefulWidget {
  final FormularioDeRegistro formulario;
  final Usuario usuario;
  final List<CameraDescription> cameras;

  const RegistroPage({
    super.key,
    required this.formulario,
    required this.usuario,
    required this.cameras,
  });

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  FormularioDeRegistro get _f => widget.formulario;

  void _avisar(String mensagem, {Duration? duracao}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mensagem),
        duration: duracao ?? const Duration(seconds: 4),
      ));
  }

  Future<void> _usarLocalizacao() async {
    final mensagem = await _f.preencherPelaLocalizacao();
    if (mounted) _avisar(mensagem, duracao: const Duration(seconds: 8));
  }

  Future<void> _importar() async {
    final registro = await Navigator.of(context).push<Registro>(
      MaterialPageRoute(
        builder: (_) => ImportarAtividadePage(usuario: widget.usuario),
      ),
    );
    if (registro != null) await _f.importar(registro);
  }

  void _avancar() {
    final erro = _f.avancar();
    if (erro != null) _avisar(erro);
  }

  Future<void> _ditar() async {
    final erro = await _f.alternarDitado();
    if (erro != null && mounted) _avisar(erro);
  }

  Future<void> _tirarFotos() async {
    final erro = _f.erroDoServico();
    if (erro != null) {
      _avisar(erro);
      return;
    }
    if (widget.cameras.isEmpty) {
      _avisar('Nenhuma câmera disponível');
      return;
    }

    final r = await _f.gravar(widget.usuario.id!);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraPage(
          cameras: widget.cameras,
          registroId: r.registroId,
          trecho: r.trecho,
          kmtrecho: r.faixaDeKm,
          estacaInicial: r.estacaInicial,
          estacaFinal: r.estacaFinal,
          via: r.via,
          descricao: r.descricao,
          servNotavel: r.servico,
          servNotavelDetalhes: r.passo,
        ),
      ),
    );
    _f.depoisDasFotos();
    // Envia já; sem rede, vai quando ela voltar.
    Dependencias.sincronizacao.sincronizar();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _f,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        // Ocupa a tela toda, a partir do topo (o padrão centraliza a etapa).
        layoutBuilder: (atual, anteriores) => Stack(
          fit: StackFit.expand,
          children: [...anteriores, if (atual != null) atual],
        ),
        transitionBuilder: (child, animacao) => FadeTransition(
          opacity: animacao,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animacao),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_f.etapa),
          child: _f.etapa == EtapaDoRegistro.local
              ? EtapaLocal(
                  formulario: _f,
                  aoUsarLocalizacao: _usarLocalizacao,
                  aoImportar: _importar,
                  aoAvancar: _avancar,
                )
              : EtapaServico(
                  formulario: _f,
                  aoAbrirGuia: () => mostrarGuiaDasAtividades(context),
                  aoDitar: _ditar,
                  aoTirarFotos: _tirarFotos,
                ),
        ),
      ),
    );
  }
}
