import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../registro/domain/regras/textos_do_registro.dart';

// Um registro feito por um encarregado, lido de volta do servidor.
class RegistroDaEquipe {
  final String dispositivoId;
  final int idLocal;
  final String usuarioNome;
  final String usuarioMatricula;
  final String trecho;
  final String km;

  // KM da estaca final quando o serviço atravessa o KM; vazio quando não.
  final String kmFinal;

  final String via;
  final String atividade;
  final String estacaInicial;
  final String estacaFinal;
  final String servicoNotavel;
  final String servicoNotavelDetalhe;
  final double? quantidade;
  final String unidade;

  // Quem lançou, quando foi o supervisor; vazio no registro comum.
  final String registradoPorNome;

  final String descricao;
  final DateTime criadoEm;

  const RegistroDaEquipe({
    required this.dispositivoId,
    required this.idLocal,
    required this.usuarioNome,
    required this.usuarioMatricula,
    required this.trecho,
    required this.km,
    this.kmFinal = '',
    required this.via,
    required this.atividade,
    required this.estacaInicial,
    required this.estacaFinal,
    required this.servicoNotavel,
    required this.servicoNotavelDetalhe,
    this.quantidade,
    required this.unidade,
    this.registradoPorNome = '',
    required this.descricao,
    required this.criadoEm,
  });

  factory RegistroDaEquipe.fromMap(Map<String, dynamic> m) => RegistroDaEquipe(
        dispositivoId: (m['dispositivo_id'] as String?) ?? '',
        idLocal: (m['id_local'] as num?)?.toInt() ?? 0,
        usuarioNome: (m['usuario_nome'] as String?) ?? '',
        usuarioMatricula: (m['usuario_matricula'] as String?) ?? '',
        trecho: (m['trecho'] as String?) ?? '',
        km: (m['km'] as String?) ?? '',
        kmFinal: (m['km_final'] as String?) ?? '',
        via: (m['via'] as String?) ?? '',
        atividade: (m['atividade'] as String?) ?? '',
        estacaInicial: (m['estaca_inicial'] as String?) ?? '',
        estacaFinal: (m['estaca_final'] as String?) ?? '',
        servicoNotavel: (m['servico_notavel'] as String?) ?? '',
        servicoNotavelDetalhe: (m['servico_notavel_detalhe'] as String?) ?? '',
        quantidade: (m['quantidade'] as num?)?.toDouble(),
        unidade: (m['unidade'] as String?) ?? '',
        registradoPorNome: (m['registrado_por_nome'] as String?) ?? '',
        descricao: (m['descricao'] as String?) ?? '',
        criadoEm:
            DateTime.tryParse((m['criado_em'] as String?) ?? '')?.toLocal() ??
                DateTime.now(),
      );

  // Chave do registro no servidor — as fotos apontam para ela.
  String get chave => '$dispositivoId|$idLocal';

  // "C1 / KM 225"
  String get local => textoDoLocal(trecho, km, kmFinal);

  // "EST. 1115 a EST. 1120"; vazio sem estaca.
  String get estacas => textoDasEstacas(estacaInicial, estacaFinal);

  // "1850 m³"; vazio sem medição.
  String get medicao => textoDaMedicao(quantidade, unidade);

  // O que pode ser corrigido (ver EditarRegistroPage).
  CamposDoRegistro get campos => CamposDoRegistro(
        trecho: trecho,
        km: km,
        kmFinal: kmFinal,
        via: via,
        atividade: atividade,
        estacaInicial: estacaInicial,
        estacaFinal: estacaFinal,
        servicoNotavel: servicoNotavel,
        servicoNotavelDetalhe: servicoNotavelDetalhe,
        quantidade: quantidade,
        unidade: unidade,
        descricao: descricao,
      );
}
