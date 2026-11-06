import '../../../paralisacao/domain/entities/paralisacao.dart' show descreverParalisacao;

// Uma paralisação de um encarregado, lida do servidor.
class ParalisacaoDaEquipe {
  final String dispositivoId;
  final int idLocal;
  final String usuarioMatricula;
  final String motivo;
  final String observacao;
  final String trecho;
  final String km;
  final DateTime inicio; // local
  final DateTime? fim; // local; null = ainda parado

  const ParalisacaoDaEquipe({
    required this.dispositivoId,
    required this.idLocal,
    required this.usuarioMatricula,
    required this.motivo,
    this.observacao = '',
    this.trecho = '',
    this.km = '',
    required this.inicio,
    this.fim,
  });

  // Chave da paralisação no servidor — as fotos apontam para ela.
  String get chave => '$dispositivoId|$idLocal';

  String get descricao => descreverParalisacao(
        inicio: inicio,
        fim: fim,
        motivo: motivo,
        trecho: trecho,
        km: km,
        observacao: observacao,
      );
}
