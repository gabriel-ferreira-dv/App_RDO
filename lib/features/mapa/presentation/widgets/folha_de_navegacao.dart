import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../domain/entities/estaca_navegavel.dart';
import '../viewmodels/escolha_de_estaca_view_model.dart';

// Abre a folha "Ir para uma estaca"; devolve a estaca escolhida.
Future<EstacaNavegavel?> escolherEstacaParaNavegar(
  BuildContext context, {
  EstacaNavegavel? destinoAtual,
}) =>
    showModalBottomSheet<EstacaNavegavel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FolhaDeNavegacao(destinoAtual: destinoAtual),
    );

// Trecho → KM → estaca. A folha é dona do ViewModel e o cria uma vez só, no
// State: o builder da folha roda de novo a cada arrasto, e um ViewModel
// criado lá trocaria o que está em uso por um novo, sem dados.
class FolhaDeNavegacao extends StatefulWidget {
  // Reabre no trecho e KM deste destino.
  final EstacaNavegavel? destinoAtual;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final EscolhaDeEstacaViewModel? viewModel;

  const FolhaDeNavegacao({super.key, this.destinoAtual, this.viewModel});

  @override
  State<FolhaDeNavegacao> createState() => _FolhaDeNavegacaoState();
}

class _FolhaDeNavegacaoState extends State<FolhaDeNavegacao> {
  late final EscolhaDeEstacaViewModel _vm =
      widget.viewModel ?? Dependencias.escolhaDeEstaca(widget.destinoAtual);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ir para uma estaca', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_vm.carregando)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_vm.semEstacas)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nenhuma estaca com coordenada e KM cadastrados — '
                    'verifique os arquivos do projeto na tela de Atualizações.',
                  ),
                )
              else
                ..._escolhas(theme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _escolhas(ThemeData theme) => [
        DropdownButtonFormField<String>(
          // Recria quando o trecho do destino atual chega.
          key: ValueKey('trecho_${_vm.trecho}'),
          initialValue: _vm.trecho,
          decoration: const InputDecoration(
            labelText: 'Trecho',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final t in _vm.trechos)
              DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (t) => t == null ? null : _vm.escolherTrecho(t),
        ),
        const SizedBox(height: 12),
        if (!_vm.semKm) ...[
          DropdownButtonFormField<String>(
            // Recria ao trocar o trecho, para o KM antigo sair.
            key: ValueKey('km_${_vm.trecho}'),
            initialValue: _vm.km,
            decoration: const InputDecoration(
              labelText: 'KM',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final km in _vm.kms)
                DropdownMenuItem(value: km, child: Text('KM $km')),
            ],
            onChanged: _vm.trecho == null
                ? null
                : (km) => km == null ? null : _vm.escolherKm(km),
          ),
          const SizedBox(height: 12),
        ],
        if (_vm.km != null) ...[
          Text('Estaca', style: theme.textTheme.labelLarge),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: _vm.estacas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _vm.estacas.length,
                    itemBuilder: (_, i) {
                      final estaca = _vm.estacas[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(estaca.descricao),
                        onTap: () => Navigator.of(context).pop(estaca),
                      );
                    },
                  ),
          ),
        ],
      ];
}
