import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';

// O que fica no "Mais" da barra de baixo.
enum OpcaoDoMais {
  paradas,
  relatorio,
  equipe,
  registrosDosUsuarios,
  comoUsar,
  atualizacoes,
  privacidade,
}

// Abre a lista do "Mais" de baixo para cima; devolve o que foi escolhido.
Future<OpcaoDoMais?> mostrarMenuMais(
  BuildContext context, {
  required bool paradoAgora,
  required bool ehSupervisor,
  bool ehAdmin = false,
}) {
  return showModalBottomSheet<OpcaoDoMais>(
    context: context,
    // Com todas as opções (supervisor e admin) a lista passa da altura padrão
    // da folha: ela cresce até o tamanho da tela e rola se ainda faltar.
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final cores = CoresDaObra.de(context);
      Widget opcao(OpcaoDoMais valor, IconData icone, String titulo,
              {String? subtitulo, Color? corDoSubtitulo}) =>
          ListTile(
            leading: Icon(icone),
            title: Text(titulo),
            subtitle: subtitulo == null
                ? null
                : Text(subtitulo,
                    style: TextStyle(
                      color: corDoSubtitulo,
                      fontWeight:
                          corDoSubtitulo == null ? null : FontWeight.w600,
                    )),
            onTap: () => Navigator.of(context).pop(valor),
          );

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              opcao(
                OpcaoDoMais.paradas,
                Icons.pause_circle_outline,
                'Paradas',
                subtitulo: paradoAgora
                    ? 'Serviço parado agora'
                    : 'Chuva, falta de material, máquina',
                corDoSubtitulo: paradoAgora ? cores.parada : null,
              ),
              opcao(OpcaoDoMais.relatorio, Icons.picture_as_pdf_outlined,
                  'Relatório do dia',
                  subtitulo: 'Gerar o RDO em PDF'),
              if (ehSupervisor)
                opcao(OpcaoDoMais.equipe, Icons.groups_outlined, 'Equipe',
                    subtitulo: 'Registros e relatório da equipe'),
              if (ehAdmin)
                opcao(OpcaoDoMais.registrosDosUsuarios,
                    Icons.fact_check_outlined, 'Registros dos usuários',
                    subtitulo: 'Admin: conferir e corrigir qualquer registro'),
              opcao(OpcaoDoMais.atualizacoes, Icons.system_update_alt,
                  'Atualizações',
                  subtitulo: 'Envio, mapas e versão do app'),
              opcao(
                  OpcaoDoMais.comoUsar, Icons.help_outline, 'Como usar o app'),
              opcao(OpcaoDoMais.privacidade, Icons.privacy_tip_outlined,
                  'Privacidade'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
