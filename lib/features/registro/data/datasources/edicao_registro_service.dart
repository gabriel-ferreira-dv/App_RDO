import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../core/database/db_helper.dart';
import '../../../camera/data/datasources/carimbo_service.dart';
import '../../domain/entities/campos_do_registro.dart';
import '../../domain/regras/vias_estaqueamento.dart' show faixaDeKm;

export '../../domain/entities/campos_do_registro.dart';

// Correção de registro no aparelho. A edição sobe na sincronização
// (edicao_pendente) e o servidor guarda o histórico (ver
// supabase/editar_registros.sql).
class EdicaoRegistroService {
  EdicaoRegistroService._interno();
  static final EdicaoRegistroService instancia =
      EdicaoRegistroService._interno();

  Future<CamposDoRegistro?> campos(int registroId) async {
    final db = await DbHelper.instancia.database;
    final linhas =
        await db.query('registros', where: 'id = ?', whereArgs: [registroId]);
    return linhas.isEmpty ? null : CamposDoRegistro.deMapa(linhas.first);
  }

  // Grava a correção feita aqui e refaz o carimbo das fotos.
  Future<void> editar(int registroId, CamposDoRegistro campos) async {
    final db = await DbHelper.instancia.database;
    await db.update(
      'registros',
      {
        ...campos.paraMapa(),
        'editado_em': DateTime.now().toUtc().toIso8601String(),
        'edicao_pendente': 1,
      },
      where: 'id = ?',
      whereArgs: [registroId],
    );
    await refazerCarimbos(registroId);
  }

  // Correção que chegou do servidor (do supervisor ou de outro aparelho).
  Future<void> aplicarDoServidor(
      int registroId, CamposDoRegistro campos, String editadoEm) async {
    final db = await DbHelper.instancia.database;
    await db.update(
      'registros',
      {...campos.paraMapa(), 'editado_em': editadoEm},
      where: 'id = ?',
      whereArgs: [registroId],
    );
    await refazerCarimbos(registroId);
  }

  // Refaz o carimbo das fotos do registro que têm a original guardada, com a
  // hora em que cada foto foi tirada. Foto já enviada volta para a fila: a
  // carimbada nova sobe com outro nome. Devolve quantas foram refeitas.
  Future<int> refazerCarimbos(int registroId) async {
    final db = await DbHelper.instancia.database;
    final registros =
        await db.query('registros', where: 'id = ?', whereArgs: [registroId]);
    if (registros.isEmpty) return 0;
    final c = CamposDoRegistro.deMapa(registros.first);

    final fotos = await db.query('fotos',
        where: "registro_id = ? AND caminho_original <> ''",
        whereArgs: [registroId]);
    var refeitas = 0;
    for (final f in fotos) {
      final original = f['caminho_original'] as String;
      if (!File(original).existsSync()) continue;
      final minimapa = (f['caminho_minimapa'] as String?) ?? '';
      final carimbada = f['caminho_arquivo'] as String;
      try {
        await processarFoto(
          original,
          (f['latitude'] as num?)?.toDouble() ?? 0,
          (f['longitude'] as num?)?.toDouble() ?? 0,
          c.trecho,
          faixaDeKm(c.km, c.kmFinal),
          c.estacaInicial,
          c.estacaFinal,
          c.via,
          c.descricao,
          c.servicoNotavel,
          c.servicoNotavelDetalhe,
          minimapBytes: minimapa.isNotEmpty && File(minimapa).existsSync()
              ? await File(minimapa).readAsBytes()
              : null,
          destino: carimbada,
          momento: DateTime.tryParse((f['criado_em'] as String?) ?? ''),
        );
        // A tela guarda a imagem pelo caminho: sem isso mostraria a antiga.
        await FileImage(File(carimbada)).evict();
        if (f['sincronizado'] == 1) {
          await db.update('fotos', {'carimbo_pendente': 1},
              where: 'id = ?', whereArgs: [f['id']]);
        }
        refeitas++;
      } catch (e) {
        debugPrint('Carimbo da foto ${f['id']} não foi refeito: $e');
      }
    }
    return refeitas;
  }
}
