import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/extensions/data_hora_extensions.dart';

// Consultas do que a equipe produziu no servidor. Lança erro sem internet.
abstract interface class RegistrosEquipeRemoto {
  Future<List<Map<String, dynamic>>> registrosEntre(
      List<String> matriculas, DateTime de, DateTime ate);
  Future<List<Map<String, dynamic>>> paralisacoesEntre(
      List<String> matriculas, DateTime de, DateTime ate);
  Future<List<Map<String, dynamic>>> climaDoDia(
      List<String> matriculas, DateTime dia);
  Future<List<Map<String, dynamic>>> paginaDeRegistros(
      List<String> matriculas, DateTime? desde, int inicio);
  Future<List<Map<String, dynamic>>> corrigir(
      String dispositivoId, int idLocal, Map<String, dynamic> campos);
  Future<List<Map<String, dynamic>>> fotosDosRegistros(
      List<String> dispositivos, List<int> idsLocais);
  Future<List<Map<String, dynamic>>> fotosDasParalisacoes(
      List<String> dispositivos, List<int> idsLocais);
  Future<Uint8List> baixarFoto(String caminho);
}

class RegistrosEquipeSupabase implements RegistrosEquipeRemoto {
  const RegistrosEquipeSupabase();

  static const String tabelaRegistros = 'registros_app';
  static const String tabelaFotos = 'fotos_app';
  static const String tabelaParalisacoes = 'paralisacoes_app';
  static const String tabelaFotosParalisacao = 'paralisacao_fotos_app';
  static const String tabelaClima = 'clima_dia_app';
  static const String bucketFotos = 'fotos';

  // Linhas por página do Supabase.
  static const int pagina = 1000;

  SupabaseClient get _cliente => Supabase.instance.client;

  // O padrão do order() é decrescente: aqui é sempre do mais antigo.
  @override
  Future<List<Map<String, dynamic>>> registrosEntre(
          List<String> matriculas, DateTime de, DateTime ate) =>
      _cliente
          .from(tabelaRegistros)
          .select()
          .inFilter('usuario_matricula', matriculas)
          .gte('criado_em', de.toUtc().toIso8601String())
          .lt('criado_em', ate.toUtc().toIso8601String())
          .order('criado_em', ascending: true);

  @override
  Future<List<Map<String, dynamic>>> paralisacoesEntre(
          List<String> matriculas, DateTime de, DateTime ate) =>
      _cliente
          .from(tabelaParalisacoes)
          .select()
          .inFilter('usuario_matricula', matriculas)
          .eq('excluida', false)
          .gte('inicio', de.toUtc().toIso8601String())
          .lt('inicio', ate.toUtc().toIso8601String())
          .order('inicio', ascending: true);

  @override
  Future<List<Map<String, dynamic>>> climaDoDia(
          List<String> matriculas, DateTime dia) =>
      _cliente
          .from(tabelaClima)
          .select()
          .inFilter('usuario_matricula', matriculas)
          .eq('data', dia.dataIso);

  // Uma página dos registros desde [desde] (null = tudo). O id desempata:
  // sem ele, uma página repetiria linhas da outra.
  @override
  Future<List<Map<String, dynamic>>> paginaDeRegistros(
      List<String> matriculas, DateTime? desde, int inicio) {
    var consulta =
        _cliente.from(tabelaRegistros).select().inFilter('usuario_matricula', matriculas);
    if (desde != null) {
      consulta = consulta.gte('criado_em', desde.toUtc().toIso8601String());
    }
    return consulta
        .order('criado_em', ascending: true)
        .order('id', ascending: true)
        .range(inicio, inicio + pagina - 1);
  }

  // Linhas alteradas (vazio = sem permissão).
  @override
  Future<List<Map<String, dynamic>>> corrigir(
          String dispositivoId, int idLocal, Map<String, dynamic> campos) =>
      _cliente
          .from(tabelaRegistros)
          .update(campos)
          .eq('dispositivo_id', dispositivoId)
          .eq('id_local', idLocal)
          .select('id');

  // Filtra pelo registro também: o limite de linhas cortava as fotos do dia.
  @override
  Future<List<Map<String, dynamic>>> fotosDosRegistros(
          List<String> dispositivos, List<int> idsLocais) =>
      _cliente
          .from(tabelaFotos)
          .select('dispositivo_id, registro_id_local, caminho_storage')
          .inFilter('dispositivo_id', dispositivos)
          .inFilter('registro_id_local', idsLocais)
          .order('id', ascending: true);

  @override
  Future<List<Map<String, dynamic>>> fotosDasParalisacoes(
          List<String> dispositivos, List<int> idsLocais) =>
      _cliente
          .from(tabelaFotosParalisacao)
          .select('dispositivo_id, paralisacao_id_local, caminho_storage')
          .inFilter('dispositivo_id', dispositivos)
          .inFilter('paralisacao_id_local', idsLocais)
          .order('id', ascending: true);

  @override
  Future<Uint8List> baixarFoto(String caminho) =>
      _cliente.storage.from(bucketFotos).download(caminho);
}
