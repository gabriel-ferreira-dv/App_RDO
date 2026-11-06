import 'dart:typed_data';

import 'package:namer_app/features/registro/domain/entities/campos_do_registro.dart';
import 'package:namer_app/features/relatorio/domain/entities/funcao_equipe.dart';
import 'package:namer_app/features/supervisor/data/datasources/equipe_supabase.dart';
import 'package:namer_app/features/supervisor/data/datasources/registros_equipe_supabase.dart';
import 'package:namer_app/features/supervisor/domain/entities/clima_da_equipe.dart';
import 'package:namer_app/features/supervisor/domain/entities/encarregado_da_equipe.dart';
import 'package:namer_app/features/supervisor/domain/entities/paralisacao_da_equipe.dart';
import 'package:namer_app/features/supervisor/domain/entities/registro_da_equipe.dart';
import 'package:namer_app/features/supervisor/domain/repositories/equipe_repository.dart';
import 'package:namer_app/features/supervisor/domain/repositories/registros_da_equipe_repository.dart';

// Quinta, 24/09/2026, 15:00 (hora local).
final agoraDeTeste = DateTime(2026, 9, 24, 15);

const ana = EncarregadoDaEquipe(matricula: '051395', nome: 'Ana Lima');
const joao = EncarregadoDaEquipe(matricula: '045020', nome: 'João Souza');

RegistroDaEquipe registroDaEquipe(
  String matricula,
  DateTime quando, {
  int idLocal = 1,
  String dispositivo = 'aparelho-1',
  String servico = 'COMPACTAÇÃO DE ATERRO',
  String trecho = 'C1',
  String km = '225',
  String estacaInicial = 'EST. 1115',
  String estacaFinal = 'EST. 1115',
  String nome = '',
  double? quantidade,
  String unidade = '',
}) =>
    RegistroDaEquipe(
      dispositivoId: dispositivo,
      idLocal: idLocal,
      usuarioNome: nome.isEmpty ? matricula : nome,
      usuarioMatricula: matricula,
      trecho: trecho,
      km: km,
      via: '',
      atividade: 'Terraplenagem',
      estacaInicial: estacaInicial,
      estacaFinal: estacaFinal,
      servicoNotavel: servico,
      servicoNotavelDetalhe: '',
      quantidade: quantidade,
      unidade: unidade,
      descricao: '',
      criadoEm: quando,
    );

ParalisacaoDaEquipe parada(String matricula, DateTime inicio,
        {DateTime? fim, int idLocal = 1, String motivo = 'Chuva'}) =>
    ParalisacaoDaEquipe(
      dispositivoId: 'aparelho-1',
      idLocal: idLocal,
      usuarioMatricula: matricula,
      motivo: motivo,
      inicio: inicio,
      fim: fim,
    );

// Repositório em memória. As buscas guardam o que foi pedido.
class RegistrosFalsos implements RegistrosDaEquipeRepository {
  List<RegistroDaEquipe> registros = [];
  List<ParalisacaoDaEquipe> paradas = [];
  Map<String, ClimaDaEquipe> clima = {};
  Map<String, List<FuncaoEquipe>> efetivo = {};
  Map<String, List<String>> fotosDosRegistros = {};
  Map<String, List<String>> fotosDasParadas = {};

  // Caminho → bytes; caminho sem entrada = download que falha.
  Map<String, Uint8List> arquivos = {};

  // null = sem resposta (busca falhou).
  List<RegistroDaEquipe>? doPeriodo = [];
  String? erroAoCorrigir;

  final janelasPedidas = <({DateTime de, DateTime ate})>[];
  final periodosPedidos = <DateTime?>[];
  final corrigidos = <String, CamposDoRegistro>{};
  var downloads = 0;

  @override
  Future<List<RegistroDaEquipe>> registrosEntre(
      List<String> matriculas, DateTime de, DateTime ate) async {
    janelasPedidas.add((de: de, ate: ate));
    return [
      for (final r in registros)
        if (matriculas.contains(r.usuarioMatricula) &&
            !r.criadoEm.isBefore(de) &&
            r.criadoEm.isBefore(ate))
          r,
    ];
  }

  @override
  Future<List<ParalisacaoDaEquipe>> paralisacoesEntre(
          List<String> matriculas, DateTime de, DateTime ate) async =>
      [
        for (final p in paradas)
          if (matriculas.contains(p.usuarioMatricula) &&
              !p.inicio.isBefore(de) &&
              p.inicio.isBefore(ate))
            p,
      ];

  @override
  Future<Map<String, ClimaDaEquipe>> climaDoDia(
          List<String> matriculas, DateTime dia) async =>
      clima;

  @override
  Future<Map<String, List<FuncaoEquipe>>> efetivoDoDia(DateTime dia) async =>
      efetivo;

  @override
  Future<List<RegistroDaEquipe>?> registrosDoPeriodo(List<String> matriculas,
      {DateTime? desde}) async {
    periodosPedidos.add(desde);
    return doPeriodo;
  }

  @override
  Future<String?> corrigir(
      RegistroDaEquipe registro, CamposDoRegistro campos) async {
    if (erroAoCorrigir != null) return erroAoCorrigir;
    corrigidos[registro.chave] = campos;
    return null;
  }

  @override
  Future<Map<String, List<String>>> caminhosDasFotos(
          List<RegistroDaEquipe> registros) async =>
      {
        for (final r in registros)
          if (fotosDosRegistros[r.chave] case final c?) r.chave: c,
      };

  @override
  Future<Map<String, List<String>>> caminhosDasFotosDeParalisacao(
          List<ParalisacaoDaEquipe> paralisacoes) async =>
      {
        for (final p in paralisacoes)
          if (fotosDasParadas[p.chave] case final c?) p.chave: c,
      };

  @override
  Future<Uint8List?> baixarFoto(String caminho) async {
    downloads++;
    return arquivos[caminho];
  }
}

class EquipeFalsa implements EquipeRepository {
  Map<String, List<EncarregadoDaEquipe>> equipes = {};
  List<EncarregadoDaEquipe> recentes = [];
  String? erroAoSalvar;
  final salvas = <String, List<EncarregadoDaEquipe>>{};

  @override
  Future<List<EncarregadoDaEquipe>> equipeDe(String supervisorMatricula) async =>
      equipes[supervisorMatricula] ?? const [];

  @override
  Future<String?> salvarEquipe(
      String supervisorMatricula, List<EncarregadoDaEquipe> equipe) async {
    if (erroAoSalvar != null) return erroAoSalvar;
    salvas[supervisorMatricula] = equipe;
    equipes[supervisorMatricula] = equipe;
    return null;
  }

  @override
  Future<List<EncarregadoDaEquipe>> encarregadosRecentes() async => recentes;
}

// Servidor falso dos registros da equipe (para testar o repositório).
class RemotoFalso implements RegistrosEquipeRemoto {
  List<Map<String, dynamic>> linhasDeFotos = [];
  List<List<Map<String, dynamic>>> paginas = [];
  List<Map<String, dynamic>> alteradas = [];
  bool falhar = false;
  final paginasPedidas = <int>[];

  void _talvezFalhar() {
    if (falhar) throw Exception('sem rede');
  }

  @override
  Future<List<Map<String, dynamic>>> registrosEntre(
      List<String> matriculas, DateTime de, DateTime ate) async {
    _talvezFalhar();
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> paralisacoesEntre(
      List<String> matriculas, DateTime de, DateTime ate) async {
    _talvezFalhar();
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> climaDoDia(
      List<String> matriculas, DateTime dia) async {
    _talvezFalhar();
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> paginaDeRegistros(
      List<String> matriculas, DateTime? desde, int inicio) async {
    _talvezFalhar();
    paginasPedidas.add(inicio);
    final i = inicio ~/ RegistrosEquipeSupabase.pagina;
    return i < paginas.length ? paginas[i] : [];
  }

  @override
  Future<List<Map<String, dynamic>>> corrigir(
      String dispositivoId, int idLocal, Map<String, dynamic> campos) async {
    _talvezFalhar();
    return alteradas;
  }

  @override
  Future<List<Map<String, dynamic>>> fotosDosRegistros(
      List<String> dispositivos, List<int> idsLocais) async {
    _talvezFalhar();
    return linhasDeFotos;
  }

  @override
  Future<List<Map<String, dynamic>>> fotosDasParalisacoes(
      List<String> dispositivos, List<int> idsLocais) async {
    _talvezFalhar();
    return linhasDeFotos;
  }

  @override
  Future<Uint8List> baixarFoto(String caminho) async {
    _talvezFalhar();
    return Uint8List(0);
  }
}

class EquipeRemotaFalsa implements EquipeRemota {
  List<Map<String, dynamic>> linhas = [];
  bool falhar = false;
  final trocas = <String, List<Map<String, String>>>{};

  @override
  Future<List<Map<String, dynamic>>> equipeDe(String supervisorMatricula) async {
    if (falhar) throw Exception('sem rede');
    return linhas;
  }

  @override
  Future<void> trocarEquipe(
      String supervisorMatricula, List<Map<String, String>> encarregados) async {
    if (falhar) throw Exception('sem rede');
    trocas[supervisorMatricula] = encarregados;
  }
}
