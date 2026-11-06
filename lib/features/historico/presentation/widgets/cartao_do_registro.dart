import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';
import '../../../../core/widgets/etiqueta.dart';
import '../../domain/entities/item_do_historico.dart';

// Um registro no Histórico: miniatura da primeira foto com o número de fotos,
// o serviço, onde e quando, e se já subiu para o servidor.
class CartaoDoRegistro extends StatelessWidget {
  final ItemDoHistorico item;
  final VoidCallback aoAbrir;
  final VoidCallback aoCorrigir;

  const CartaoDoRegistro({
    super.key,
    required this.item,
    required this.aoAbrir,
    required this.aoCorrigir,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detalhes = item.detalhes;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: aoAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Miniatura(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.grupo.servicoNotavel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.localEHora,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (detalhes.isNotEmpty)
                      Text(
                        detalhes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 6),
                    _etiquetaDaSituacao(CoresDaObra.de(context)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Corrigir registro',
                icon: const Icon(Icons.edit_outlined),
                onPressed: aoCorrigir,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etiquetaDaSituacao(CoresDaObra cores) => switch (item.situacao) {
        SituacaoDoRegistro.aguardando => Etiqueta(
            texto: 'Aguardando sinal',
            icone: Icons.cloud_upload_outlined,
            cor: cores.pendente,
            fundo: cores.fundoPendente,
          ),
        SituacaoDoRegistro.corrigido => Etiqueta(
            texto: 'Corrigido e enviado',
            icone: Icons.edit_note,
            cor: cores.neutro,
            fundo: cores.fundoNeutro,
          ),
        SituacaoDoRegistro.enviado => Etiqueta(
            texto: 'Enviado',
            icone: Icons.cloud_done_outlined,
            cor: cores.enviado,
            fundo: cores.fundoEnviado,
          ),
      };
}

// Primeira foto, pequena, com o número de fotos no canto.
class _Miniatura extends StatelessWidget {
  final ItemDoHistorico item;

  const _Miniatura({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fotos = item.registro.fotos;
    final vazio = Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child:
          Icon(Icons.image_not_supported_outlined, color: cs.onSurfaceVariant),
    );

    return SizedBox(
      width: 64,
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fundo enquanto a foto carrega.
            ColoredBox(color: cs.surfaceContainerHighest),
            if (fotos.isEmpty)
              vazio
            else
              Image.file(
                File(fotos.first.caminhoArquivo),
                fit: BoxFit.cover,
                // Decodifica pequeno: é só uma miniatura.
                cacheWidth: 192,
                errorBuilder: (_, __, ___) => vazio,
              ),
            if (fotos.length > 1)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: grafite.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${fotos.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
