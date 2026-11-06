import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/entities/aviso_de_privacidade.dart';
import '../../domain/entities/ciencia_do_aviso.dart';
import '../../domain/repositories/aviso_de_privacidade_repository.dart';
import '../datasources/aviso_local_datasource.dart';
import '../datasources/aviso_remoto_datasource.dart';
import '../models/aviso_de_privacidade_model.dart';
import '../models/ciencia_do_aviso_model.dart';

// Busca no Supabase e guarda uma cópia no celular; sem internet (ou com o
// servidor sem aviso para a filial), usa a cópia.
class AvisoDePrivacidadeRepositoryImpl implements AvisoDePrivacidadeRepository {
  final AvisoRemotoDataSource _remoto;
  final AvisoLocalDataSource _local;

  const AvisoDePrivacidadeRepositoryImpl({
    required AvisoRemotoDataSource remoto,
    required AvisoLocalDataSource local,
  })  : _remoto = remoto,
        _local = local;

  @override
  Future<AvisoDePrivacidade?> buscar(String filial) async {
    try {
      final linha = await _remoto.buscar(filial);
      final aviso = linha == null ? null : avisoDoMapa(linha);
      if (aviso != null) {
        await _guardarCopia(aviso);
        return aviso;
      }
    } catch (e) {
      debugPrint('Aviso de privacidade: busca no servidor falhou: $e');
    }
    return _copia(filial);
  }

  @override
  Future<CienciaDoAviso?> ciencia(String email, String filial) async {
    try {
      return cienciaDoTexto(await _local.ciencia(email, filial));
    } catch (e) {
      debugPrint('Aviso de privacidade: falha ao ler a ciência: $e');
      return null;
    }
  }

  @override
  Future<void> guardarCiencia(
      String email, String filial, CienciaDoAviso ciencia) async {
    try {
      await _local.guardarCiencia(email, filial, ciencia.paraTexto());
    } catch (e) {
      debugPrint('Aviso de privacidade: falha ao guardar a ciência: $e');
    }
  }

  Future<AvisoDePrivacidade?> _copia(String filial) async {
    try {
      final json = await _local.copia(filial);
      if (json == null) return null;
      return avisoDoMapa(Map<String, dynamic>.from(jsonDecode(json) as Map));
    } catch (e) {
      debugPrint('Aviso de privacidade: cópia do celular ilegível: $e');
      return null;
    }
  }

  Future<void> _guardarCopia(AvisoDePrivacidade aviso) async {
    try {
      await _local.guardarCopia(aviso.filial, jsonEncode(aviso.paraMapa()));
    } catch (e) {
      debugPrint('Aviso de privacidade: falha ao guardar a cópia: $e');
    }
  }
}
