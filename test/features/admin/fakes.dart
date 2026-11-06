import 'package:namer_app/features/admin/data/datasources/admin_local_datasource.dart';
import 'package:namer_app/features/admin/data/datasources/admin_remoto_datasource.dart';
import 'package:namer_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:namer_app/features/registro/domain/entities/campos_do_registro.dart';
import 'package:namer_app/features/supervisor/domain/entities/registro_da_equipe.dart';

RegistroDaEquipe registroDe(
  String nome,
  String matricula,
  int idLocal, {
  String estacaInicial = '2245',
  String estacaFinal = '2247',
  DateTime? criadoEm,
}) =>
    RegistroDaEquipe(
      dispositivoId: 'aparelho',
      idLocal: idLocal,
      usuarioNome: nome,
      usuarioMatricula: matricula,
      trecho: 'C1',
      km: '225',
      via: 'Via 01 Sul',
      atividade: 'Civil',
      estacaInicial: estacaInicial,
      estacaFinal: estacaFinal,
      servicoNotavel: 'ANDAIME',
      servicoNotavelDetalhe: 'Montagem',
      unidade: '',
      descricao: '',
      criadoEm: criadoEm ?? DateTime(2026, 10, 15, 14, 12),
    );

// Repositório em memória para o caso de uso e o ViewModel.
class RepositorioFalso implements AdminRepository {
  final registrosPorDia = <DateTime, List<RegistroDaEquipe>?>{};
  Map<String, List<String>> fotos = {};
  String? erroAoCorrigir;
  final corrigidos = <RegistroDaEquipe>[];
  var buscasDeFotos = 0;

  @override
  Future<bool> souAdmin() async => true;

  @override
  Future<List<RegistroDaEquipe>?> registrosDoDia(DateTime dia) async =>
      registrosPorDia.containsKey(dia) ? registrosPorDia[dia] : const [];

  @override
  Future<Map<String, List<String>>> enderecosDasFotos(
      List<RegistroDaEquipe> registros) async {
    buscasDeFotos++;
    return fotos;
  }

  @override
  Future<String?> corrigir(
      RegistroDaEquipe registro, CamposDoRegistro campos) async {
    if (erroAoCorrigir == null) corrigidos.add(registro);
    return erroAoCorrigir;
  }
}

// Supabase falso. [falhar] simula estar sem internet.
class RemotoFalso implements AdminRemotoDataSource {
  bool admin = false;
  bool falhar = false;
  List<Map<String, dynamic>> linhas = [];
  Map<String, String> enderecos = {};
  final pedidosDeEndereco = <List<String>>[];

  void _talvezFalhe() {
    if (falhar) throw Exception('sem internet');
  }

  @override
  Future<bool> souAdmin() async {
    _talvezFalhe();
    return admin;
  }

  @override
  Future<List<Map<String, dynamic>>> registrosEntre(
      DateTime de, DateTime ate) async {
    _talvezFalhe();
    return linhas;
  }

  @override
  Future<Map<String, String>> enderecosTemporarios(
      List<String> caminhos) async {
    _talvezFalhe();
    pedidosDeEndereco.add(caminhos);
    return enderecos;
  }
}

class LocalFalso implements AdminLocalDataSource {
  bool? guardado;

  @override
  Future<bool?> souAdmin() async => guardado;

  @override
  Future<void> guardarSouAdmin(bool admin) async => guardado = admin;
}
