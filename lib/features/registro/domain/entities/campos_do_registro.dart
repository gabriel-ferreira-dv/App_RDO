// Campos do registro que podem ser corrigidos depois de feito. Data, hora,
// coordenada e minimapa nunca mudam. As chaves são as mesmas no SQLite e em
// registros_app.
class CamposDoRegistro {
  final String trecho;
  final String km;
  final String kmFinal;
  final String via;
  final String atividade;
  final String estacaInicial;
  final String estacaFinal;
  final String servicoNotavel;
  final String servicoNotavelDetalhe;
  final double? quantidade;
  final String unidade;
  final String descricao;

  const CamposDoRegistro({
    required this.trecho,
    required this.km,
    this.kmFinal = '',
    this.via = '',
    required this.atividade,
    this.estacaInicial = '',
    this.estacaFinal = '',
    required this.servicoNotavel,
    this.servicoNotavelDetalhe = '',
    this.quantidade,
    this.unidade = '',
    this.descricao = '',
  });

  factory CamposDoRegistro.deMapa(Map<String, dynamic> m) => CamposDoRegistro(
        trecho: _texto(m['trecho']),
        km: _texto(m['km']),
        kmFinal: _texto(m['km_final']),
        via: _texto(m['via']),
        atividade: _texto(m['atividade']),
        estacaInicial: _texto(m['estaca_inicial']),
        estacaFinal: _texto(m['estaca_final']),
        servicoNotavel: _texto(m['servico_notavel']),
        servicoNotavelDetalhe: _texto(m['servico_notavel_detalhe']),
        quantidade: (m['quantidade'] as num?)?.toDouble(),
        unidade: _texto(m['unidade']),
        descricao: _texto(m['descricao']),
      );

  Map<String, dynamic> paraMapa() => {
        'trecho': trecho,
        'km': km,
        'km_final': kmFinal,
        'via': via,
        'atividade': atividade,
        'estaca_inicial': estacaInicial,
        'estaca_final': estacaFinal,
        'servico_notavel': servicoNotavel,
        'servico_notavel_detalhe': servicoNotavelDetalhe,
        'quantidade': quantidade,
        'unidade': unidade,
        'descricao': descricao,
      };

  bool mesmoQue(CamposDoRegistro outro) {
    final a = paraMapa();
    final b = outro.paraMapa();
    return a.keys.every((chave) => a[chave] == b[chave]);
  }
}

String _texto(Object? valor) => (valor as String?) ?? '';
