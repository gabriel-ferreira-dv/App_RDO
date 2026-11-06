import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../../core/obra/dia_de_trabalho.dart';
import '../../domain/entities/foto_da_paralisacao.dart';
import '../../domain/entities/paralisacao.dart';
import '../../domain/repositories/paralisacao_repository.dart';
import '../datasources/paralisacao_local_datasource.dart';
import '../models/paralisacao_model.dart';

class ParalisacaoRepositoryImpl implements ParalisacaoRepository {
  final ParalisacaoLocalDataSource _local;

  const ParalisacaoRepositoryImpl(this._local);

  // Toda mudança fica pendente de envio ao servidor.
  static const _pendente = {'sincronizado': 0};

  @override
  Future<int> salvar(Paralisacao p) async {
    final dados = p.paraMapa()
      ..remove('id')
      ..addAll(_pendente);
    if (p.id == null) return _local.inserir(dados);
    await _local.atualizar(p.id!, dados);
    return p.id!;
  }

  @override
  Future<void> encerrar(int id, DateTime quando) => _local
      .atualizar(id, {'fim': quando.toUtc().toIso8601String(), ..._pendente});

  @override
  Future<void> excluir(int id) =>
      _local.atualizar(id, {'excluida': 1, ..._pendente});

  @override
  Future<List<Paralisacao>> listarDoDia(int usuarioId, DateTime dia,
      {required bool noturno}) async {
    // Janela larga (por causa do turno da noite); o dia exato é conferido
    // abaixo.
    final janela = janelaDoDiaDeTrabalho(dia);
    final linhas = await _local.doUsuarioEntre(
        usuarioId, janela.de.toIso8601String(), janela.ate.toIso8601String());
    return [
      for (final linha in linhas)
        if (paralisacaoDoMapa(linha) case final p
            when p.diaDeTrabalho(noturno: noturno) == dia.soDia)
          p,
    ];
  }

  @override
  Future<void> adicionarFoto({
    required int paralisacaoId,
    required String caminhoArquivo,
    double? latitude,
    double? longitude,
    required DateTime quando,
  }) =>
      _local.inserirFoto({
        'paralisacao_id': paralisacaoId,
        'caminho_arquivo': caminhoArquivo,
        'latitude': latitude,
        'longitude': longitude,
        'criado_em': quando.toUtc().toIso8601String(),
      });

  @override
  Future<List<FotoDaParalisacao>> fotosDe(int paralisacaoId) async =>
      [for (final l in await _local.fotosDe(paralisacaoId)) fotoDoMapa(l)];

  @override
  Future<Map<int, int>> contarFotos(List<int> ids) async {
    if (ids.isEmpty) return {};
    return {
      for (final l in await _local.contarFotos(ids))
        l['paralisacao_id'] as int: (l['n'] as num).toInt(),
    };
  }

  @override
  Future<LocalDaParada?> ultimoLocalDesde(int usuarioId, DateTime desde) async {
    final linha = await _local.ultimoRegistroDesde(
        usuarioId, desde.toUtc().toIso8601String());
    if (linha == null) return null;
    return (
      trecho: (linha['trecho'] as String?) ?? '',
      km: (linha['km'] as String?) ?? '',
    );
  }
}
