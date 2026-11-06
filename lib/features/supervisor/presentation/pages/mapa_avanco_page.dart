import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/dependencias.dart';
import '../../../auth/models/usuario.dart';
import '../../domain/entities/registro_da_equipe.dart';
import '../viewmodels/mapa_avanco_view_model.dart';
import '../widgets/filtros_do_mapa.dart';
import '../widgets/mapa_do_avanco.dart';
import '../widgets/resumo_do_avanco.dart';

// Onde cada serviço foi executado, pintado sobre as estacas do projeto, com
// o acumulado por serviço e KM. Duas versões: a da equipe (supervisor, do
// servidor, por período) e a do encarregado (só o dele, dia a dia).
class MapaAvancoPage extends StatefulWidget {
  // Matrículas da equipe (e a do próprio supervisor).
  final List<String> matriculas;

  // Encarregado vendo o próprio dia; null no mapa da equipe.
  final Usuario? usuario;

  // Dia em que o mapa do encarregado abre.
  final DateTime? dia;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final MapaAvancoViewModel? viewModel;

  const MapaAvancoPage.daEquipe({super.key, required this.matriculas, this.viewModel})
      : usuario = null,
        dia = null;

  const MapaAvancoPage.doEncarregado(
      {super.key, required Usuario this.usuario, this.dia, this.viewModel})
      : matriculas = const [];

  @override
  State<MapaAvancoPage> createState() => _MapaAvancoPageState();
}

class _MapaAvancoPageState extends State<MapaAvancoPage> {
  late final MapaAvancoViewModel _vm = widget.viewModel ??
      (widget.usuario != null
          ? Dependencias.mapaDoEncarregado(widget.usuario!, dia: widget.dia)
          : Dependencias.mapaDaEquipe(widget.matriculas));
  final _mapa = MapController();
  final LayerHitNotifier<RegistroDaEquipe> _toque = ValueNotifier(null);
  bool _mapaPronto = false;

  @override
  void initState() {
    super.initState();
    _vm.carregar().then((_) => _enquadrar());
  }

  @override
  void dispose() {
    _vm.dispose();
    _mapa.dispose();
    _toque.dispose();
    super.dispose();
  }

  // Enquadra os pontos (ou tudo o que está filtrado).
  void _enquadrar([List<LatLng>? pontos]) {
    if (!_mapaPronto || !mounted) return;
    enquadrarNoMapa(_mapa, pontos ?? _vm.pontosFiltrados);
  }

  void _mostrarDetalhes(List<RegistroDaEquipe> registros) {
    if (registros.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final r in registros.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_vm.tituloDoDetalhe(r),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_vm.subtituloDoDetalhe(r)),
            ),
        ],
      ),
    );
  }

  Widget _mensagem(String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(texto, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _vm.carregar().then((_) => _enquadrar()),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(_vm.titulo)),
        body: Column(
          children: [
            FiltrosDoMapa(
              doEncarregado: _vm.doEncarregado,
              carregando: _vm.carregando,
              dia: _vm.dia,
              hoje: _vm.hoje,
              aoMudarDia: (d) => _vm.mudarDia(d).then((_) => _enquadrar()),
              periodo: _vm.periodo,
              aoEscolherPeriodo: (p) =>
                  _vm.escolherPeriodo(p).then((_) => _enquadrar()),
              servicos: _vm.servicos,
              servico: _vm.servico,
              aoEscolherServico: (s) {
                _vm.escolherServico(s);
                _enquadrar();
              },
              encarregados: _vm.encarregados,
              encarregado: _vm.encarregado,
              aoEscolherEncarregado: (m) {
                _vm.escolherEncarregado(m);
                _enquadrar();
              },
            ),
            Expanded(
              child: _vm.semNadaAinda
                  ? const Center(child: CircularProgressIndicator())
                  : _vm.erro != null
                      ? _mensagem(_vm.erro!)
                      : Stack(
                          children: [
                            MapaDoAvanco(
                              controlador: _mapa,
                              toque: _toque,
                              tracos: _vm.tracos,
                              eixos: _vm.eixos,
                              aoTocar: _mostrarDetalhes,
                              aoFicarPronto: () => _mapaPronto = true,
                            ),
                            if (_vm.carregando)
                              const LinearProgressIndicator(minHeight: 3),
                            ResumoDoAvanco(
                              titulo: _vm.tituloDoResumo,
                              dica: _vm.dicaDoResumo,
                              servicos: _vm.resumo,
                              corDe: _vm.corDe,
                              numeros: _vm.numeros,
                              tituloDoKm: _vm.tituloDoKm,
                              aoEnquadrar: _enquadrar,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
