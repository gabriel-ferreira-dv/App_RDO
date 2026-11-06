import 'package:namer_app/core/extensions/data_hora_extensions.dart';
import 'package:namer_app/features/paralisacao/data/datasources/paralisacao_local_datasource.dart';
import 'package:namer_app/features/paralisacao/domain/entities/foto_da_paralisacao.dart';
import 'package:namer_app/features/paralisacao/domain/entities/paralisacao.dart';
import 'package:namer_app/features/paralisacao/domain/repositories/paralisacao_repository.dart';

// Quinta, 24/09/2026, 15:00 (hora local).
final agoraDeTeste = DateTime(2026, 9, 24, 15);

Paralisacao parada({
  int? id,
  int usuarioId = 1,
  String motivo = 'Chuva',
  required DateTime inicio,
  DateTime? fim,
  String trecho = '',
  String km = '',
  String observacao = '',
}) =>
    Paralisacao(
      id: id,
      usuarioId: usuarioId,
      motivo: motivo,
      inicio: inicio.toUtc(),
      fim: fim?.toUtc(),
      trecho: trecho,
      km: km,
      observacao: observacao,
      criadoEm: inicio.toUtc().toIso8601String(),
    );

Paralisacao _comMudancas(Paralisacao p, {int? id, DateTime? fim}) =>
    Paralisacao(
      id: id ?? p.id,
      usuarioId: p.usuarioId,
      motivo: p.motivo,
      observacao: p.observacao,
      trecho: p.trecho,
      km: p.km,
      inicio: p.inicio,
      fim: fim ?? p.fim,
      criadoEm: p.criadoEm,
    );

// Repositório em memória para os casos de uso e os ViewModels.
class RepositorioFalso implements ParalisacaoRepository {
  final paralisacoes = <Paralisacao>[];
  final fotos = <int, List<FotoDaParalisacao>>{};
  final excluidas = <int>{};
  LocalDaParada? ultimoLocal;
  var _proximoId = 1;

  @override
  Future<int> salvar(Paralisacao p) async {
    if (p.id == null) {
      final id = _proximoId++;
      paralisacoes.add(_comMudancas(p, id: id));
      return id;
    }
    paralisacoes[paralisacoes.indexWhere((x) => x.id == p.id)] = p;
    return p.id!;
  }

  @override
  Future<void> encerrar(int id, DateTime quando) async {
    final i = paralisacoes.indexWhere((x) => x.id == id);
    paralisacoes[i] = _comMudancas(paralisacoes[i], fim: quando.toUtc());
  }

  @override
  Future<void> excluir(int id) async => excluidas.add(id);

  @override
  Future<List<Paralisacao>> listarDoDia(int usuarioId, DateTime dia,
          {required bool noturno}) async =>
      [
        for (final p in paralisacoes)
          if (p.usuarioId == usuarioId &&
              !excluidas.contains(p.id) &&
              p.diaDeTrabalho(noturno: noturno) == dia.soDia)
            p,
      ];

  @override
  Future<void> adicionarFoto({
    required int paralisacaoId,
    required String caminhoArquivo,
    double? latitude,
    double? longitude,
    required DateTime quando,
  }) async {
    final lista = fotos.putIfAbsent(paralisacaoId, () => []);
    lista.add(FotoDaParalisacao(
      id: lista.length + 1,
      caminhoArquivo: caminhoArquivo,
      criadoEm: quando.toUtc().toIso8601String(),
    ));
  }

  @override
  Future<List<FotoDaParalisacao>> fotosDe(int paralisacaoId) async =>
      fotos[paralisacaoId] ?? [];

  @override
  Future<Map<int, int>> contarFotos(List<int> ids) async => {
        for (final id in ids)
          if (fotos[id] case final lista?) id: lista.length,
      };

  @override
  Future<LocalDaParada?> ultimoLocalDesde(
          int usuarioId, DateTime desde) async =>
      ultimoLocal;
}

// Banco do celular falso: listas em memória que imitam as consultas.
class BancoFalso implements ParalisacaoLocalDataSource {
  final linhas = <Map<String, Object?>>[];
  final fotos = <Map<String, Object?>>[];
  Map<String, Object?>? ultimoRegistro;
  String? desdePedido;
  var consultasDeFotos = 0;

  @override
  Future<int> inserir(Map<String, Object?> dados) async {
    final id = linhas.length + 1;
    linhas.add({'excluida': 0, ...dados, 'id': id});
    return id;
  }

  @override
  Future<void> atualizar(int id, Map<String, Object?> dados) async {
    final i = linhas.indexWhere((l) => l['id'] == id);
    linhas[i] = {...linhas[i], ...dados};
  }

  @override
  Future<List<Map<String, Object?>>> doUsuarioEntre(
          int usuarioId, String de, String ate) async =>
      [
        for (final l in linhas)
          if (l['usuario_id'] == usuarioId &&
              l['excluida'] == 0 &&
              (l['inicio'] as String).compareTo(de) >= 0 &&
              (l['inicio'] as String).compareTo(ate) < 0)
            l,
      ]..sort(
          (a, b) => (a['inicio'] as String).compareTo(b['inicio'] as String));

  @override
  Future<void> inserirFoto(Map<String, Object?> dados) async =>
      fotos.add({...dados, 'id': fotos.length + 1});

  @override
  Future<List<Map<String, Object?>>> fotosDe(int paralisacaoId) async => [
        for (final f in fotos)
          if (f['paralisacao_id'] == paralisacaoId) f
      ];

  @override
  Future<List<Map<String, Object?>>> contarFotos(List<int> ids) async {
    consultasDeFotos++;
    final contagem = <int, int>{};
    for (final f in fotos) {
      final id = f['paralisacao_id'] as int;
      if (ids.contains(id)) contagem[id] = (contagem[id] ?? 0) + 1;
    }
    return [
      for (final e in contagem.entries) {'paralisacao_id': e.key, 'n': e.value},
    ];
  }

  @override
  Future<Map<String, Object?>?> ultimoRegistroDesde(
      int usuarioId, String desde) async {
    desdePedido = desde;
    return ultimoRegistro;
  }
}
