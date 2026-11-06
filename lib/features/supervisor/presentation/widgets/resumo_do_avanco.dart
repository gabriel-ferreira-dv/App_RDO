import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/regras/avanco.dart';

// Folha de baixo do mapa de avanço: o total e um cartão por serviço, com o
// detalhe por KM (o toque no KM leva o mapa até ele).
class ResumoDoAvanco extends StatelessWidget {
  final String titulo;
  final String dica;
  final List<AvancoDoServico> servicos;
  final int Function(String servico) corDe;
  final String Function(Map<String, double> quantidades, double metros, int registros)
      numeros;
  final String Function(AvancoDoKm km) tituloDoKm;
  final ValueChanged<List<LatLng>> aoEnquadrar;

  const ResumoDoAvanco({
    super.key,
    required this.titulo,
    required this.dica,
    required this.servicos,
    required this.corDe,
    required this.numeros,
    required this.tituloDoKm,
    required this.aoEnquadrar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.1,
      maxChildSize: 0.85,
      builder: (context, rolagem) => Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: ListView(
          controller: rolagem,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(titulo,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(dica,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final s in servicos) _cartao(theme, s),
          ],
        ),
      ),
    );
  }

  Widget _cartao(ThemeData theme, AvancoDoServico s) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(radius: 8, backgroundColor: Color(corDe(s.servico))),
          title: Text(s.servico,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(numeros(s.quantidades, s.metros, s.registros),
              style: theme.textTheme.bodySmall),
          children: [
            for (final km in s.kms)
              ListTile(
                dense: true,
                title: Text(tituloDoKm(km)),
                subtitle: Text(numeros(km.quantidades, km.metros, km.registros)),
                trailing: km.pontos.isEmpty
                    ? null
                    : const Icon(Icons.center_focus_strong_outlined, size: 20),
                onTap: km.pontos.isEmpty ? null : () => aoEnquadrar(km.pontos),
              ),
          ],
        ),
      );
}
