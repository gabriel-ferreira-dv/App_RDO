import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../../core/obra/dia_de_trabalho.dart';
import '../../domain/entities/paralisacao.dart';
import '../../domain/entities/resumo_das_paralisacoes.dart';
import '../../domain/usecases/carregar_paralisacoes_do_dia.dart';
import '../../domain/usecases/retomar_servico.dart';

// Cartão "Paralisações de hoje/do dia": a lista, o tempo parado e o retomar.
// Vai na aba Paradas e no formulário do RDO.
class ParalisacoesDoDiaViewModel extends ChangeNotifier with DescarteSeguro {
  ParalisacoesDoDiaViewModel({
    required CarregarParalisacoesDoDia carregarDoDia,
    required RetomarServico retomarServico,
    required this.usuarioId,
    RelogioDoTurno relogio = const RelogioDoTurno(),
    DateTime? dia,
    VoidCallback? aoMudarDados,
  })  : _relogio = relogio,
        _carregarDoDia = carregarDoDia,
        _retomarServico = retomarServico,
        _diaEscolhido = dia?.soDia,
        _aoMudarDados = aoMudarDados;

  final CarregarParalisacoesDoDia _carregarDoDia;
  final RetomarServico _retomarServico;
  final VoidCallback? _aoMudarDados;

  final int usuarioId;

  // O turno é lido a cada uso: a lista do turno da noite pode chegar do
  // servidor depois de o cartão abrir.
  final RelogioDoTurno _relogio;
  bool get noturno => _relogio.noturno();

  // null = o dia de trabalho de agora (respeita o turno da noite).
  final DateTime? _diaEscolhido;

  bool _carregando = true;
  ResumoDasParalisacoes _resumo = ResumoDasParalisacoes.nenhuma;

  DateTime get _hoje => _relogio.hoje;
  DateTime get dia => _diaEscolhido ?? _hoje;
  bool get ehHoje => _diaEscolhido == null || dia == _hoje;

  bool get carregando => _carregando;
  ResumoDasParalisacoes get resumo => _resumo;

  String get titulo => ehHoje ? 'Paralisações de hoje' : 'Paralisações do dia';

  // "2h30 parado"; vazio sem tempo parado.
  String get totalParado => _resumo.totalParado > Duration.zero
      ? '${formatarDuracao(_resumo.totalParado)} parado'
      : '';

  String get semParalisacoes => ehHoje
      ? 'Se o serviço parar (chuva, falta de material, máquina quebrada…), '
          'registre aqui. Vai para o RDO e para o relatório do supervisor.'
      : 'Nenhuma paralisação registrada neste dia.';

  // "Serviço parado desde 13:10 · Chuva"
  String paradoDesde(Paralisacao p) =>
      'Serviço parado desde ${p.inicio.toLocal().horaCurta} · ${p.motivo}';

  Future<void> carregar() async {
    final resumo = await _carregarDoDia(usuarioId, dia, noturno: noturno);
    mudar(() {
      _resumo = resumo;
      _carregando = false;
    });
  }

  // Fecha a paralisação agora; devolve a mensagem para o usuário.
  Future<String> retomar(Paralisacao p) async {
    final parado = await _retomarServico(p);
    await carregar();
    _aoMudarDados?.call();
    return 'Serviço retomado. Parado por ${formatarDuracao(parado)}.';
  }

  // Depois do formulário: recarrega sempre (a foto pode ter entrado mesmo
  // saindo pelo voltar) e manda para o servidor.
  Future<void> depoisDeEditar() async {
    await carregar();
    _aoMudarDados?.call();
  }
}
