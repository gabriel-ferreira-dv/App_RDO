import '../auth/models/usuario.dart';
import '../../app/dependencias.dart';
import '../paralisacao/domain/entities/paralisacao.dart';
import '../registro/domain/entities/grupo_atividade.dart';
import '../relatorio/turno_noturno.dart';

class ResumoDoDia {
  final int registros;
  final int fotos;
  final int paradas;
  final Paralisacao? paradaAberta;
  final Duration tempoParado;

  const ResumoDoDia({
    this.registros = 0,
    this.fotos = 0,
    this.paradas = 0,
    this.paradaAberta,
    this.tempoParado = Duration.zero,
  });

  bool get paradoAgora => paradaAberta != null;
}

class InicioService {
  InicioService._interno();
  static final InicioService instancia = InicioService._interno();

  Future<ResumoDoDia> resumoDoDia(Usuario usuario) async {
    final noturno = Dependencias.ehNoturno(usuario);
    final agora = DateTime.now();
    final dia = diaDoTurno(agora, noturno: noturno);
    final desde =
        DateTime(dia.year, dia.month, dia.day - 1).toUtc().toIso8601String();

    final fotos = await Dependencias.registros
        .listarFotosComContexto(usuario.id!, desde: desde);
    final paradas = await Dependencias.paralisacoes
        .listarDoDia(usuario.id!, dia, noturno: noturno);
    return montarResumoDoDia(
      grupos: agruparPorAtividade(fotos),
      paradas: paradas,
      dia: dia,
      noturno: noturno,
      agora: agora,
    );
  }
}
ResumoDoDia montarResumoDoDia({
  required List<GrupoAtividade> grupos,
  required List<Paralisacao> paradas,
  required DateTime dia,
  required bool noturno,
  required DateTime agora,
}) {
  var registros = 0;
  var fotos = 0;
  for (final grupo in grupos) {
    for (final registro in grupo.registros) {
      final criado = DateTime.tryParse(registro.criadoEm)?.toLocal();
      if (criado == null || diaDoTurno(criado, noturno: noturno) != dia) {
        continue;
      }
      registros++;
      fotos += registro.fotos.length;
    }
  }

  Paralisacao? aberta;
  var parado = Duration.zero;
  for (final p in paradas) {
    if (p.emAndamento) aberta = p;
    final fim = p.fim ?? agora.toUtc();
    if (fim.isAfter(p.inicio)) parado += fim.difference(p.inicio);
  }

  return ResumoDoDia(
    registros: registros,
    fotos: fotos,
    paradas: paradas.length,
    paradaAberta: aberta,
    tempoParado: parado,
  );
}

String saudacao(DateTime agora) {
  if (agora.hour >= 5 && agora.hour < 12) return 'Bom dia';
  if (agora.hour >= 12 && agora.hour < 18) return 'Boa tarde';
  return 'Boa noite';
}
