import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

// Aviso da filial na tabela `aviso_privacidade` do Supabase (ver
// supabase_consultas/aviso_privacidade.sql).
abstract interface class AvisoRemotoDataSource {
  // A linha da [filial]; null se ela não tem aviso. Lança erro sem internet.
  Future<Map<String, dynamic>?> buscar(String filial);
}

class AvisoRemotoSupabase implements AvisoRemotoDataSource {
  const AvisoRemotoSupabase();

  @override
  Future<Map<String, dynamic>?> buscar(String filial) =>
      Supabase.instance.client
          .from('aviso_privacidade')
          .select('filial_id, versao, texto, atualizado_em')
          .eq('filial_id', filial)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
}
