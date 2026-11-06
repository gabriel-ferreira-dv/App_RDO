import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../../core/extensions/texto_extensions.dart';
import '../../domain/entities/encarregado_da_equipe.dart';
import '../../domain/repositories/equipe_repository.dart';

// Escolha dos encarregados da equipe. A lista vem do apontamento (quem teve
// lançamento nos últimos dias): o supervisor marca nomes reais em vez de
// digitar matrícula. Quem já está na equipe e não apareceu no apontamento
// (férias, afastamento, desligado) também aparece, marcado, para ele decidir.
class MontarEquipeViewModel extends ChangeNotifier with DescarteSeguro {
  MontarEquipeViewModel({
    required EquipeRepository repositorio,
    required this.supervisorMatricula,
    required List<EncarregadoDaEquipe> equipeAtual,
  })  : _repositorio = repositorio,
        _equipeAtual = equipeAtual,
        _marcados = {for (final e in equipeAtual) e.matricula};

  final EquipeRepository _repositorio;
  final String supervisorMatricula;
  final List<EncarregadoDaEquipe> _equipeAtual;
  final Set<String> _marcados;

  // Os do apontamento e, depois, os da equipe que não estão nele.
  List<EncarregadoDaEquipe> _todos = const [];
  Set<String> _semApontamento = const {};
  String _filtro = '';
  bool _carregando = true;
  bool _salvando = false;

  bool get carregando => _carregando;
  bool get salvando => _salvando;
  bool get semEncarregados => _todos.isEmpty;
  String get selecionados => '${_marcados.length} selecionado(s)';

  bool marcado(EncarregadoDaEquipe e) => _marcados.contains(e.matricula);

  // "Matrícula 051395", com o aviso para quem não apareceu no apontamento.
  String subtituloDe(EncarregadoDaEquipe e) =>
      'Matrícula ${e.matricula}${_semApontamento.contains(e.matricula) ? ' · sem apontamento nos últimos dias' : ''}';

  // Pelo nome (sem ligar para acento) ou pela matrícula.
  List<EncarregadoDaEquipe> get visiveis {
    final filtro = _filtro.trim().toLowerCase().semAcento;
    if (filtro.isEmpty) return _todos;
    return [
      for (final e in _todos)
        if (e.nome.toLowerCase().semAcento.contains(filtro) ||
            e.matricula.contains(filtro))
          e,
    ];
  }

  Future<void> carregar() async {
    final doApontamento = await _repositorio.encarregadosRecentes();
    final noApontamento = {for (final e in doApontamento) e.matricula};
    final ausentes = [
      for (final e in _equipeAtual)
        if (!noApontamento.contains(e.matricula)) e,
    ];
    mudar(() {
      _todos = [...doApontamento, ...ausentes];
      _semApontamento = {for (final e in ausentes) e.matricula};
      _carregando = false;
    });
  }

  void definirFiltro(String texto) => mudar(() => _filtro = texto);

  void marcar(EncarregadoDaEquipe e, bool sim) => mudar(() {
        if (sim) {
          _marcados.add(e.matricula);
        } else {
          _marcados.remove(e.matricula);
        }
      });

  // Salva no servidor. Devolve a equipe salva, ou o erro para mostrar.
  Future<({List<EncarregadoDaEquipe>? equipe, String? erro})> salvar() async {
    mudar(() => _salvando = true);
    final equipe = [
      for (final e in _todos)
        if (_marcados.contains(e.matricula)) e,
    ];
    final erro = await _repositorio.salvarEquipe(supervisorMatricula, equipe);
    mudar(() => _salvando = false);
    return erro == null ? (equipe: equipe, erro: null) : (equipe: null, erro: erro);
  }
}
