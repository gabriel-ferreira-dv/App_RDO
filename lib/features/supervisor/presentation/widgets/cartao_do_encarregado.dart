import 'package:flutter/material.dart';

import '../../domain/entities/registro_da_equipe.dart';
import '../viewmodels/supervisor_view_model.dart';
import 'secao_do_cartao.dart';

// O dia de um encarregado: clima, efetivo, atividades, paradas e os
// registros, cada um com o botão de corrigir.
class CartaoDoEncarregado extends StatelessWidget {
  final CartaoDoDia cartao;
  final ValueChanged<RegistroDaEquipe> aoCorrigir;

  const CartaoDoEncarregado(
      {super.key, required this.cartao, required this.aoCorrigir});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resumo = cartao.resumo;
    final clima = resumo.clima?.linha ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(resumo.encarregado.nome,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          cartao.subtitulo,
          style: theme.textTheme.labelSmall?.copyWith(
              color: resumo.aindaParado ? theme.colorScheme.error : null),
        ),
        children: [
          if (clima.isNotEmpty) SecaoDoCartao('Clima', [clima]),
          if (resumo.efetivo.isNotEmpty)
            SecaoDoCartao('Efetivo', [for (final f in resumo.efetivo) f.linha]),
          SecaoDoCartao('Atividades', cartao.atividades,
              vazio: 'Nenhuma atividade registrada no app neste dia'),
          if (resumo.paralisacoes.isNotEmpty)
            SecaoDoCartao(
                'Paralisações', [for (final p in resumo.paralisacoes) p.descricao]),
          if (cartao.registros.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registros',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  for (final r in cartao.registros)
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.linha, style: theme.textTheme.bodySmall),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Corrigir registro',
                          onPressed: () => aoCorrigir(r.registro),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          if (cartao.ultimoRegistro != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(cartao.ultimoRegistro!,
                    style: theme.textTheme.labelSmall),
              ),
            ),
        ],
      ),
    );
  }
}
