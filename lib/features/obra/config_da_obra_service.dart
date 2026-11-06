import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/obra/config_da_obra.dart';
import '../mapa/data/datasources/navegacao_estacas_service.dart';
import '../registro/data/datasources/estaqueamento_service.dart';
import '../registro/data/datasources/sugestao_gps_service.dart';
import '../../core/obra/filial_do_usuario.dart';

// Configuração da obra do usuário: a coluna `config` da tabela `filiais`, da
// filial que está em perfis_app (ver supabase/filiais.sql). Fica guardada no
// aparelho, porque o app funciona sem sinal. Config vazia, ou servidor ainda
// sem filiais, vale a obra atual.
class ConfigDaObraService {
  ConfigDaObraService(this._filial);

  // A filial que esta classe grava; os outros serviços leem a mesma.
  final FilialDoUsuario _filial;

  static const String tabela = 'filiais';
  static const String _chavePrefs = 'config_da_obra';
  static const String _chaveFilial = 'filial_da_obra';

  // Conta para a qual a obra já foi conferida no servidor nesta abertura.
  String? _obraConferidaPara;

  // true quando a obra do usuário logado já foi lida do servidor: a pasta das
  // fotos no bucket é a dela (ver caminhoNoBucket).
  bool get obraConferida =>
      _obraConferidaPara != null &&
      _obraConferidaPara == Supabase.instance.client.auth.currentUser?.id;

  // Lê a configuração guardada no aparelho (no boot).
  Future<void> carregarDoAparelho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _filial.definir(prefs.getString(_chaveFilial) ?? filialPadrao);
      final salva = prefs.getString(_chavePrefs);
      if (salva != null) _aplicar(configDoServidor(jsonDecode(salva)));
    } catch (e) {
      debugPrint('Config da obra: falha ao ler do aparelho: $e');
    }
  }

  // Busca a config da filial do usuário e guarda no aparelho; sem rede, ou
  // antes de o servidor ter filiais, vale a guardada.
  Future<void> sincronizar() async {
    try {
      final cliente = Supabase.instance.client;
      final usuario = cliente.auth.currentUser;
      if (usuario == null) return;

      final perfil = await cliente
          .from('perfis_app')
          .select('filial_id')
          .eq('user_id', usuario.id)
          .maybeSingle();
      _obraConferidaPara = usuario.id;
      final filial = perfil?['filial_id'] as String?;
      if (filial == null) return;
      if (filial != _filial.codigo) {
        _filial.definir(filial);
        await (await SharedPreferences.getInstance()).setString(_chaveFilial, filial);
      }

      final linha = await cliente
          .from(tabela)
          .select('config')
          .eq('id', filial)
          .maybeSingle();
      if (linha == null) return;

      final config = configDoServidor(linha['config']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chavePrefs, jsonEncode(config.paraJson()));
      _aplicar(config);
    } catch (e) {
      debugPrint('Config da obra: falha ao sincronizar: $e');
    }
  }

  void _aplicar(ConfigDaObra config) {
    if (jsonEncode(config.paraJson()) == jsonEncode(obraAtual.paraJson())) {
      return;
    }
    definirObraAtual(config);
    // Listas que dependem da obra (vias, fuso das coordenadas).
    EstaqueamentoService.instancia.limparCache();
    SugestaoGpsService.instancia.limparCache();
    NavegacaoEstacasService.instancia.limparCache();
  }
}

// Config vinda do servidor; vazia (ou nula) vale a obra atual.
ConfigDaObra configDoServidor(Object? json) {
  if (json is! Map || json.isEmpty) return configPadrao;
  return ConfigDaObra.deJson(Map<String, dynamic>.from(json));
}
