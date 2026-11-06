import 'package:flutter/material.dart';

import '../../domain/regras/vias_estaqueamento.dart';
import '../viewmodels/formulario_de_registro.dart';
import 'campo_pesquisa_unico.dart';
import 'seletor_de_autoria.dart';

// Etapa 1 do registro: onde o serviço está sendo feito (trecho, KM, via e
// estacas; sem o KM na obra que não usa). O GPS ou um registro anterior
// preenchem tudo de uma vez.
class EtapaLocal extends StatelessWidget {
  final FormularioDeRegistro formulario;
  final VoidCallback aoUsarLocalizacao;
  final VoidCallback aoImportar;
  final VoidCallback aoAvancar;

  const EtapaLocal({
    super.key,
    required this.formulario,
    required this.aoUsarLocalizacao,
    required this.aoImportar,
    required this.aoAvancar,
  });

  @override
  Widget build(BuildContext context) {
    final f = formulario;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      // Embaixo, folga para o botão do meio da barra.
      padding: const EdgeInsets.only(top: 16, bottom: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (f.equipe.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SeletorDeAutoria(
                equipe: f.equipe,
                escolhido: f.registrandoPara,
                aoEscolher: f.escolherAutoria,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              onPressed: f.buscandoGps ? null : aoUsarLocalizacao,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              icon: f.buscandoGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(f.buscandoGps
                  ? 'Procurando a estaca mais perto…'
                  : 'Usar minha localização'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: TextButton.icon(
              onPressed: aoImportar,
              icon: const Icon(Icons.history),
              label: const Text('Repetir um registro anterior'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'ou escolha na lista',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          CampoPesquisaUnico(
            key: const ValueKey('campo_trecho'),
            textoPesquisa: 'Trecho',
            initialValue: f.trecho,
            items: f.trechos,
            onSelected: f.escolherTrecho,
          ),
          // Obra (ou trecho) sem KM: as estacas vêm direto do trecho.
          if (f.pedeKm)
            CampoPesquisaUnico(
              key: const ValueKey('campo_km'),
              textoPesquisa: 'KM',
              initialValue: f.km,
              items: f.kms,
              enabled: f.trecho != null,
              onSelected: f.escolherKm,
            ),
          // A via vem antes das estacas: no C1 cada sentido tem numeração
          // própria. Os nomes e os trechos vêm da configuração da obra.
          if (f.pedeVia)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: viaSul,
                    label: Text(viaSul),
                    icon: const Icon(Icons.south),
                  ),
                  ButtonSegment(
                    value: viaNorte,
                    label: Text(viaNorte),
                    icon: const Icon(Icons.north),
                  ),
                ],
                selected: {if (f.via != null) f.via!},
                emptySelectionAllowed: true,
                onSelectionChanged: (selecao) =>
                    f.escolherVia(selecao.isEmpty ? null : selecao.first),
              ),
            ),
          if (f.pedeEstaca)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CampoPesquisaUnico(
                    key: const ValueKey('campo_estacaInicial'),
                    textoPesquisa: 'Estaca inicial',
                    initialValue: f.rotuloNoCampo(f.estacaInicial),
                    items: f.rotulosDoIntervalo,
                    itensSemBusca: 500,
                    // Abre no KM escolhido (ou na estaca já escolhida).
                    rolarParaIndice:
                        f.indiceDaEstaca(f.estacaInicial) ?? f.indiceDoKm,
                    enabled: f.podeEscolherEstaca,
                    onSelected: f.escolherEstacaInicial,
                  ),
                ),
                Expanded(
                  child: CampoPesquisaUnico(
                    key: const ValueKey('campo_estacaFinal'),
                    textoPesquisa: 'Estaca final',
                    initialValue: f.rotuloNoCampo(f.estacaFinal),
                    items: f.rotulosDoIntervalo,
                    itensSemBusca: 500,
                    // Abre na estaca inicial: a final costuma vir logo depois.
                    rolarParaIndice: f.indiceDaEstaca(f.estacaFinal) ??
                        f.indiceDaEstaca(f.estacaInicial) ??
                        f.indiceDoKm,
                    enabled: f.estacaInicial != null,
                    onSelected: f.escolherEstacaFinal,
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledButton(
              onPressed: aoAvancar,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Próximo: serviço'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
