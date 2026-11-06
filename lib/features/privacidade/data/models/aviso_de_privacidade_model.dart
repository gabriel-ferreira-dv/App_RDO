import '../../domain/entities/aviso_de_privacidade.dart';

// Conversão entre a linha da tabela `aviso_privacidade` (ou a cópia guardada
// no celular, no mesmo formato) e a entidade.

// null quando a linha não tem texto.
AvisoDePrivacidade? avisoDoMapa(Map<String, dynamic> linha) {
  final texto = (linha['texto'] as String?)?.trim() ?? '';
  if (texto.isEmpty) return null;
  return AvisoDePrivacidade(
    filial: (linha['filial_id'] as String?)?.trim() ?? '',
    versao: (linha['versao'] as num?)?.toInt() ?? 1,
    texto: texto,
    atualizadoEm:
        DateTime.tryParse(linha['atualizado_em'] as String? ?? '')?.toLocal(),
  );
}

extension AvisoDePrivacidadeMapa on AvisoDePrivacidade {
  Map<String, dynamic> paraMapa() => {
        'filial_id': filial,
        'versao': versao,
        'texto': texto,
        'atualizado_em': atualizadoEm?.toIso8601String(),
      };
}
