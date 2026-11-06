import 'package:flutter/foundation.dart';

import '../../domain/entities/encarregado_da_equipe.dart';
import '../../domain/repositories/equipe_repository.dart';
import '../datasources/equipe_supabase.dart';

class EquipeRepositoryImpl implements EquipeRepository {
  final EquipeRemota _remota;

  // Quem teve apontamento no SIMOVA nos últimos dias (ver EquipeSimovaService).
  final Future<List<({String matricula, String nome})>> Function()
      _encarregadosDoApontamento;

  const EquipeRepositoryImpl({
    required EquipeRemota remota,
    required Future<List<({String matricula, String nome})>> Function()
        encarregadosDoApontamento,
  })  : _remota = remota,
        _encarregadosDoApontamento = encarregadosDoApontamento;

  @override
  Future<List<EncarregadoDaEquipe>> equipeDe(String supervisorMatricula) async {
    final matricula = supervisorMatricula.trim();
    if (matricula.isEmpty) return const [];
    try {
      return [
        for (final l in await _remota.equipeDe(matricula))
          EncarregadoDaEquipe(
            matricula: (l['encarregado_matricula'] as String?) ?? '',
            nome: (l['encarregado_nome'] as String?) ?? '',
          ),
      ];
    } catch (e) {
      debugPrint('Carregar equipe do supervisor falhou: $e');
      return const [];
    }
  }

  @override
  Future<String?> salvarEquipe(
      String supervisorMatricula, List<EncarregadoDaEquipe> equipe) async {
    final matricula = supervisorMatricula.trim();
    if (matricula.isEmpty) return 'Supervisor sem matrícula cadastrada';
    try {
      await _remota.trocarEquipe(matricula, [
        for (final e in equipe)
          {'encarregado_matricula': e.matricula, 'encarregado_nome': e.nome},
      ]);
      return null;
    } catch (e) {
      debugPrint('Salvar equipe do supervisor falhou: $e');
      return 'Não foi possível salvar a equipe — verifique a conexão';
    }
  }

  @override
  Future<List<EncarregadoDaEquipe>> encarregadosRecentes() async => [
        for (final e in await _encarregadosDoApontamento())
          EncarregadoDaEquipe(matricula: e.matricula, nome: e.nome),
      ];
}
