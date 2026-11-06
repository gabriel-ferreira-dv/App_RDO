import 'package:flutter/material.dart';

import '../../../auth/models/usuario.dart';
import '../../../sincronizacao/sincronizacao_service.dart';
import '../../inicio_service.dart';
import '../widgets/painel_do_inicio.dart';
import '../../../../app/dependencias.dart';

// Aba Início: busca o resumo do dia e acompanha o envio; o conteúdo é o
// PainelDoInicio. A navegação é da casca (HomePage), que passa os atalhos.
class InicioPage extends StatefulWidget {
  final Usuario usuario;
  final bool ehSupervisor;
  final bool ehAdmin;
  final VoidCallback aoNovoRegistro;
  final VoidCallback aoVerHistorico;
  final VoidCallback aoVerParadas;
  final VoidCallback aoVerRelatorio;
  final VoidCallback aoVerEquipe;
  final VoidCallback aoVerRegistrosDosUsuarios;
  final VoidCallback aoVerAtualizacoes;
  final VoidCallback aoVerComoUsar;

  const InicioPage({
    super.key,
    required this.usuario,
    required this.ehSupervisor,
    this.ehAdmin = false,
    required this.aoNovoRegistro,
    required this.aoVerHistorico,
    required this.aoVerParadas,
    required this.aoVerRelatorio,
    required this.aoVerEquipe,
    required this.aoVerRegistrosDosUsuarios,
    required this.aoVerAtualizacoes,
    required this.aoVerComoUsar,
  });

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  final _envio = Dependencias.sincronizacao;
  ResumoDoDia _resumo = const ResumoDoDia();

  @override
  void initState() {
    super.initState();
    _carregarResumo();
    // Antes da primeira rodada o estado não tem as contagens.
    if (_envio.estado.value.pendentes == null) _envio.atualizarPendentes();
  }

  Future<void> _carregarResumo() async {
    final resumo = await InicioService.instancia.resumoDoDia(widget.usuario);
    if (mounted) setState(() => _resumo = resumo);
  }

  // Puxar para baixo: relê o dia e tenta enviar o que falta.
  Future<void> _atualizar() async {
    await Future.wait([_carregarResumo(), _envio.sincronizar()]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _atualizar,
      child: ValueListenableBuilder<EstadoDoEnvio>(
        valueListenable: _envio.estado,
        builder: (context, envio, _) => PainelDoInicio(
          envio: envio,
          resumo: _resumo,
          ehSupervisor: widget.ehSupervisor,
          ehAdmin: widget.ehAdmin,
          aoNovoRegistro: widget.aoNovoRegistro,
          aoVerHistorico: widget.aoVerHistorico,
          aoVerParadas: widget.aoVerParadas,
          aoVerRelatorio: widget.aoVerRelatorio,
          aoVerEquipe: widget.aoVerEquipe,
          aoVerRegistrosDosUsuarios: widget.aoVerRegistrosDosUsuarios,
          aoVerAtualizacoes: widget.aoVerAtualizacoes,
          aoVerComoUsar: widget.aoVerComoUsar,
        ),
      ),
    );
  }
}
