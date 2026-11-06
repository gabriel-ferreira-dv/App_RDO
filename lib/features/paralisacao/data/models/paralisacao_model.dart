import '../../domain/entities/foto_da_paralisacao.dart';
import '../../domain/entities/paralisacao.dart';

// Conversão entre as linhas das tabelas `paralisacoes` e `fotos_paralisacao`
// do banco do celular e as entidades.

Paralisacao paralisacaoDoMapa(Map<String, Object?> m) => Paralisacao(
      id: m['id'] as int?,
      usuarioId: m['usuario_id'] as int,
      motivo: m['motivo'] as String,
      observacao: (m['observacao'] as String?) ?? '',
      trecho: (m['trecho'] as String?) ?? '',
      km: (m['km'] as String?) ?? '',
      inicio: DateTime.parse(m['inicio'] as String).toUtc(),
      fim: m['fim'] == null ? null : DateTime.parse(m['fim'] as String).toUtc(),
      criadoEm: m['criado_em'] as String,
    );

extension ParalisacaoMapa on Paralisacao {
  Map<String, Object?> paraMapa() => {
        'id': id,
        'usuario_id': usuarioId,
        'motivo': motivo,
        'observacao': observacao,
        'trecho': trecho,
        'km': km,
        'inicio': inicio.toUtc().toIso8601String(),
        'fim': fim?.toUtc().toIso8601String(),
        'criado_em': criadoEm,
      };
}

FotoDaParalisacao fotoDoMapa(Map<String, Object?> m) => FotoDaParalisacao(
      id: m['id'] as int,
      caminhoArquivo: m['caminho_arquivo'] as String,
      criadoEm: m['criado_em'] as String,
    );
