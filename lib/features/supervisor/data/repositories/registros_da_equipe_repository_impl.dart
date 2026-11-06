import 'package:flutter/foundation.dart';

import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../relatorio/domain/entities/funcao_equipe.dart';
import '../../domain/entities/clima_da_equipe.dart';
import '../../domain/entities/paralisacao_da_equipe.dart';
import '../../domain/entities/registro_da_equipe.dart';
import '../../domain/repositories/registros_da_equipe_repository.dart';
import '../datasources/registros_equipe_supabase.dart';
import '../models/linhas_da_equipe.dart';

class RegistrosDaEquipeRepositoryImpl implements RegistrosDaEquipeRepository {
  final RegistrosEquipeRemoto _remoto;

  // Efetivo do SIMOVA do dia inteiro (ver EquipeSimovaService.equipesDoDia).
  final Future<Map<String, List<FuncaoEquipe>>> Function(DateTime dia)
      _efetivoDoDia;

  const RegistrosDaEquipeRepositoryImpl({
    required RegistrosEquipeRemoto remoto,
    required Future<Map<String, List<FuncaoEquipe>>> Function(DateTime dia)
        efetivoDoDia,
  })  : _remoto = remoto,
        _efetivoDoDia = efetivoDoDia;

  // Busca do dia que falha volta vazia: a tela mostra o resto.
  Future<T> _ouVazio<T>(String o, Future<T> Function() busca, T vazio) async {
    try {
      return await busca();
    } catch (e) {
      debugPrint('Busca $o da equipe falhou: $e');
      return vazio;
    }
  }

  @override
  Future<List<RegistroDaEquipe>> registrosEntre(
          List<String> matriculas, DateTime de, DateTime ate) =>
      matriculas.isEmpty
          ? Future.value(const [])
          : _ouVazio(
              'dos registros',
              () async => [
                    for (final l in await _remoto.registrosEntre(matriculas, de, ate))
                      RegistroDaEquipe.fromMap(l),
                  ],
              const []);

  @override
  Future<List<ParalisacaoDaEquipe>> paralisacoesEntre(
          List<String> matriculas, DateTime de, DateTime ate) =>
      matriculas.isEmpty
          ? Future.value(const [])
          : _ouVazio(
              'das paralisações',
              () async => [
                    for (final l
                        in await _remoto.paralisacoesEntre(matriculas, de, ate))
                      paralisacaoDaEquipeDoMapa(l),
                  ],
              const []);

  @override
  Future<Map<String, ClimaDaEquipe>> climaDoDia(
          List<String> matriculas, DateTime dia) =>
      matriculas.isEmpty
          ? Future.value(const {})
          : _ouVazio(
              'do clima',
              () async => {
                    for (final l in await _remoto.climaDoDia(matriculas, dia))
                      (l['usuario_matricula'] as String?) ?? '':
                          climaDaEquipeDoMapa(l),
                  },
              const {});

  @override
  Future<Map<String, List<FuncaoEquipe>>> efetivoDoDia(DateTime dia) =>
      _ouVazio('do efetivo', () => _efetivoDoDia(dia), const {});

  @override
  Future<List<RegistroDaEquipe>?> registrosDoPeriodo(List<String> matriculas,
      {DateTime? desde}) async {
    if (matriculas.isEmpty) return const [];
    final todos = <RegistroDaEquipe>[];
    try {
      for (var inicio = 0;; inicio += RegistrosEquipeSupabase.pagina) {
        final linhas = await _remoto.paginaDeRegistros(matriculas, desde, inicio);
        todos.addAll(linhas.map(RegistroDaEquipe.fromMap));
        if (linhas.length < RegistrosEquipeSupabase.pagina) return todos;
      }
    } catch (e) {
      debugPrint('Busca dos registros do período falhou: $e');
      return null;
    }
  }

  // O servidor guarda o histórico; o aparelho do encarregado recebe a correção
  // e refaz o carimbo das fotos na próxima sincronização.
  @override
  Future<String?> corrigir(
      RegistroDaEquipe registro, CamposDoRegistro campos) async {
    try {
      final alteradas = await _remoto.corrigir(
          registro.dispositivoId, registro.idLocal, campos.paraMapa());
      return alteradas.isEmpty ? 'Sem permissão para corrigir este registro' : null;
    } catch (e) {
      debugPrint('Correção do registro ${registro.chave} falhou: $e');
      return 'Não foi possível corrigir — verifique a internet e tente de novo';
    }
  }

  @override
  Future<Map<String, List<String>>> caminhosDasFotos(
          List<RegistroDaEquipe> registros) =>
      registros.isEmpty
          ? Future.value(const {})
          : _ouVazio(
              'dos caminhos das fotos',
              () async => _porChave(
                    await _remoto.fotosDosRegistros(
                        {for (final r in registros) r.dispositivoId}.toList(),
                        {for (final r in registros) r.idLocal}.toList()),
                    coluna: 'registro_id_local',
                    desejadas: {for (final r in registros) r.chave},
                  ),
              const {});

  @override
  Future<Map<String, List<String>>> caminhosDasFotosDeParalisacao(
          List<ParalisacaoDaEquipe> paralisacoes) =>
      paralisacoes.isEmpty
          ? Future.value(const {})
          : _ouVazio(
              'das fotos das paralisações',
              () async => _porChave(
                    await _remoto.fotosDasParalisacoes(
                        {for (final p in paralisacoes) p.dispositivoId}.toList(),
                        {for (final p in paralisacoes) p.idLocal}.toList()),
                    coluna: 'paralisacao_id_local',
                    desejadas: {for (final p in paralisacoes) p.chave},
                  ),
              const {});

  @override
  Future<Uint8List?> baixarFoto(String caminho) async {
    try {
      return await _remoto.baixarFoto(caminho);
    } catch (e) {
      debugPrint('Download da foto "$caminho" falhou: $e');
      return null;
    }
  }
}

// Caminhos por chave ("dispositivo|id_local"), só das [desejadas]: a busca
// filtra aparelho e id separados e pode trazer combinações de outros.
Map<String, List<String>> _porChave(List<Map<String, dynamic>> linhas,
    {required String coluna, required Set<String> desejadas}) {
  final porChave = <String, List<String>>{};
  for (final l in linhas) {
    final chave = '${l['dispositivo_id']}|${(l[coluna] as num).toInt()}';
    final caminho = (l['caminho_storage'] as String?) ?? '';
    if (!desejadas.contains(chave) || caminho.isEmpty) continue;
    porChave.putIfAbsent(chave, () => []).add(caminho);
  }
  return porChave;
}
