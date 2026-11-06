import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supervisor/data/datasources/registros_equipe_supabase.dart'
    show RegistrosEquipeSupabase;

// Acesso cru ao Supabase para o admin; as regras ficam no repositório.
abstract interface class AdminRemotoDataSource {
  Future<bool> souAdmin();

  // Linhas de registros_app com criado_em em [de, ate).
  Future<List<Map<String, dynamic>>> registrosEntre(DateTime de, DateTime ate);

  // Endereço temporário (1 hora) de cada caminho do bucket; os que falharem
  // ficam de fora.
  Future<Map<String, String>> enderecosTemporarios(List<String> caminhos);
}

class AdminRemotoSupabase implements AdminRemotoDataSource {
  const AdminRemotoSupabase();

  SupabaseClient get _cliente => Supabase.instance.client;

  @override
  Future<bool> souAdmin() async =>
      await _cliente.rpc('sou_admin_painel') == true;

  @override
  Future<List<Map<String, dynamic>>> registrosEntre(
          DateTime de, DateTime ate) =>
      _cliente
          .from(RegistrosEquipeSupabase.tabelaRegistros)
          .select()
          .gte('criado_em', de.toUtc().toIso8601String())
          .lt('criado_em', ate.toUtc().toIso8601String())
          .order('criado_em', ascending: true)
          .limit(1000);

  @override
  Future<Map<String, String>> enderecosTemporarios(
      List<String> caminhos) async {
    final resultados = await _cliente.storage
        .from(RegistrosEquipeSupabase.bucketFotos)
        .createSignedUrlsResult(caminhos, 3600);
    return {
      for (final r in resultados.whereType<SignedUrlSuccess>())
        r.path: r.signedUrl,
    };
  }
}
