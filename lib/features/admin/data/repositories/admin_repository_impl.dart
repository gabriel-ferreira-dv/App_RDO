import 'package:flutter/foundation.dart';

import '../../../../core/obra/dia_de_trabalho.dart';
import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../supervisor/domain/entities/registro_da_equipe.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_local_datasource.dart';
import '../datasources/admin_remoto_datasource.dart';

typedef CaminhosDasFotos = Future<Map<String, List<String>>> Function(
    List<RegistroDaEquipe> registros);
typedef CorrigirNoServidor = Future<String?> Function(
    RegistroDaEquipe registro, CamposDoRegistro campos);

// O que vem do Supervisor (turno da noite, caminhos das fotos e a correção
// no servidor) chega como funções: dá para trocar por falsos nos testes.
class AdminRepositoryImpl implements AdminRepository {
  final AdminRemotoDataSource _remoto;
  final AdminLocalDataSource _local;
  final bool Function(String matricula) _ehNoturno;
  final CaminhosDasFotos _caminhosDasFotos;
  final CorrigirNoServidor _corrigirNoServidor;

  const AdminRepositoryImpl({
    required AdminRemotoDataSource remoto,
    required AdminLocalDataSource local,
    required bool Function(String matricula) ehNoturno,
    required CaminhosDasFotos caminhosDasFotos,
    required CorrigirNoServidor corrigirNoServidor,
  })  : _remoto = remoto,
        _local = local,
        _ehNoturno = ehNoturno,
        _caminhosDasFotos = caminhosDasFotos,
        _corrigirNoServidor = corrigirNoServidor;

  @override
  Future<bool> souAdmin() async {
    try {
      final admin = await _remoto.souAdmin();
      await _local.guardarSouAdmin(admin);
      return admin;
    } catch (e) {
      debugPrint('Admin do painel: não deu para conferir agora: $e');
      return await _local.souAdmin() ?? false;
    }
  }

  @override
  Future<List<RegistroDaEquipe>?> registrosDoDia(DateTime dia) async {
    final janela = janelaDoDiaDeTrabalho(dia);
    try {
      final linhas = await _remoto.registrosEntre(janela.de, janela.ate);
      return [
        for (final linha in linhas)
          if (RegistroDaEquipe.fromMap(linha) case final r
              when ehDoDiaDeTrabalho(r.criadoEm, dia,
                  noturno: _ehNoturno(r.usuarioMatricula)))
            r,
      ];
    } catch (e) {
      debugPrint('Admin do painel: busca dos registros falhou: $e');
      return null;
    }
  }

  @override
  Future<Map<String, List<String>>> enderecosDasFotos(
      List<RegistroDaEquipe> registros) async {
    try {
      final caminhos = await _caminhosDasFotos(registros);
      final todos = [for (final lista in caminhos.values) ...lista];
      if (todos.isEmpty) return {};
      final porCaminho = await _remoto.enderecosTemporarios(todos);
      return {
        for (final e in caminhos.entries)
          e.key: [
            for (final c in e.value)
              if (porCaminho[c] case final endereco?) endereco,
          ],
      };
    } catch (e) {
      debugPrint('Admin do painel: endereços das fotos falharam: $e');
      return {};
    }
  }

  @override
  Future<String?> corrigir(
          RegistroDaEquipe registro, CamposDoRegistro campos) =>
      _corrigirNoServidor(registro, campos);
}
