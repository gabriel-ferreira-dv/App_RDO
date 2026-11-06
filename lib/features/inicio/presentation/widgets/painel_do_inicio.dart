import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';
import '../../../paralisacao/domain/entities/paralisacao.dart' show formatarDuracao;
import '../../../sincronizacao/sincronizacao_service.dart';
import '../../../sincronizacao/situacao_do_envio.dart' show plural;
import '../../inicio_service.dart';
import 'atalho_do_inicio.dart';
import 'botao_novo_registro.dart';
import 'cartao_do_envio.dart';
import 'numero_do_dia.dart';

// Conteúdo do Início com os dados já prontos: o estado do envio, o botão de
// novo registro, os números do dia e os atalhos. Quem busca os dados é a
// InicioPage.
class PainelDoInicio extends StatelessWidget {
  final EstadoDoEnvio envio;
  final ResumoDoDia resumo;
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

  const PainelDoInicio({
    super.key,
    required this.envio,
    required this.resumo,
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
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    final r = resumo;
    final detalheDasParadas = r.paradoAgora
        ? 'Parado agora'
        : r.paradas == 0
            ? 'nenhuma no dia'
            : '${formatarDuracao(r.tempoParado)} no dia';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Embaixo, folga para o botão do meio da barra.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
      children: [
        CartaoDoEnvio(estado: envio, onTap: aoVerAtualizacoes),
        const SizedBox(height: 12),
        BotaoNovoRegistro(onTap: aoNovoRegistro),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NumeroDoDia(
                rotulo: 'Hoje',
                valor: '${r.registros}',
                detalhe: '${r.registros == 1 ? 'registro' : 'registros'} · '
                    '${plural(r.fotos, 'foto', 'fotos')}',
                onTap: aoVerHistorico,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumeroDoDia(
                rotulo: 'Paradas',
                valor: '${r.paradas}',
                detalhe: detalheDasParadas,
                corDoDetalhe: r.paradoAgora ? cores.parada : null,
                onTap: aoVerParadas,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AtalhoDoInicio(
          icone: Icons.picture_as_pdf_outlined,
          titulo: 'RDO de hoje',
          subtitulo: 'Registros, fotos, paradas e efetivo',
          acao: 'Gerar',
          onTap: aoVerRelatorio,
        ),
        if (ehSupervisor) ...[
          const SizedBox(height: 8),
          AtalhoDoInicio(
            icone: Icons.groups_outlined,
            titulo: 'Minha equipe',
            subtitulo: 'Registros dos encarregados',
            acao: 'Abrir',
            onTap: aoVerEquipe,
          ),
        ],
        if (ehAdmin) ...[
          const SizedBox(height: 8),
          AtalhoDoInicio(
            icone: Icons.fact_check_outlined,
            titulo: 'Registros dos usuários',
            subtitulo: 'Conferir e corrigir qualquer registro',
            acao: 'Abrir',
            onTap: aoVerRegistrosDosUsuarios,
          ),
        ],
        const SizedBox(height: 8),
        AtalhoDoInicio(
          icone: Icons.help_outline,
          titulo: 'Como usar o app',
          acao: 'Ver',
          onTap: aoVerComoUsar,
        ),
      ],
    );
  }
}
