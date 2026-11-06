import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';
import '../../../registro/domain/regras/local_e_hora.dart';
import '../../../supervisor/domain/entities/registro_da_equipe.dart';

// Um registro de um usuário, para o admin conferir e corrigir: a foto (do
// servidor), o serviço, onde e quando, a descrição e o botão Corrigir.
class CartaoRegistroDoUsuario extends StatelessWidget {
  final RegistroDaEquipe registro;

  // Endereços temporários das fotos; vazio enquanto carrega ou sem foto.
  final List<String> fotos;

  final VoidCallback aoCorrigir;
  final ValueChanged<String> aoAbrirFoto;

  const CartaoRegistroDoUsuario({
    super.key,
    required this.registro,
    required this.fotos,
    required this.aoCorrigir,
    required this.aoAbrirFoto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suave = theme.colorScheme.onSurfaceVariant;
    final r = registro;
    final detalhes = [
      r.atividade,
      if (r.servicoNotavelDetalhe.isNotEmpty) r.servicoNotavelDetalhe,
      if (r.via.trim().isNotEmpty) r.via,
      if (r.medicao.isNotEmpty) r.medicao,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Foto(fotos: fotos, aoAbrir: aoAbrirFoto),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.servicoNotavel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(localEHora(r),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: suave)),
                      Text(detalhes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: suave)),
                      if (r.registradoPorNome.isNotEmpty)
                        Text('Lançado por ${r.registradoPorNome}',
                            style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              ],
            ),
            if (r.descricao.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r.descricao.trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: aoCorrigir,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Corrigir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "C1 · est. 2245 – 2247 · 14:12" (área de apoio não tem estaca).
  static String localEHora(RegistroDaEquipe r) => localEHoraDoRegistro(
        trecho: r.trecho,
        estacaInicial: r.estacaInicial,
        estacaFinal: r.estacaFinal,
        km: r.km,
        momento: r.criadoEm,
      );
}

// Primeira foto do registro, com o número de fotos no canto.
class _Foto extends StatelessWidget {
  final List<String> fotos;
  final ValueChanged<String> aoAbrir;

  const _Foto({required this.fotos, required this.aoAbrir});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vazio = Icon(Icons.image_outlined, color: cs.onSurfaceVariant);

    return SizedBox(
      width: 72,
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Material(
          color: cs.surfaceContainerHighest,
          child: fotos.isEmpty
              ? Center(child: vazio)
              : InkWell(
                  onTap: () => aoAbrir(fotos.first),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        fotos.first,
                        fit: BoxFit.cover,
                        cacheWidth: 216,
                        errorBuilder: (_, __, ___) => Center(child: vazio),
                      ),
                      if (fotos.length > 1)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: grafite.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${fotos.length}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
