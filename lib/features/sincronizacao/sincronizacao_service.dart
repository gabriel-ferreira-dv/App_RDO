import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show Database;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/db_helper.dart';
import '../auth/auth_service.dart';
import '../obra/config_da_obra_service.dart';
import '../registro/data/datasources/edicao_registro_service.dart';
import 'trava_do_envio.dart';
import '../../core/obra/filial_do_usuario.dart';

// Resultado de uma rodada de sincronização. Com [erro], o que já foi enviado
// fica marcado e a próxima rodada continua de onde parou.
class ResultadoSincronizacao {
  final int registrosEnviados;
  final int fotosEnviadas;

  // Registros de outro aparelho trazidos para cá.
  final int registrosBaixados;

  // Fotos trazidas do servidor (podem chegar depois do registro).
  final int fotosBaixadas;

  final String? erro;

  // A rodada parou por falta de internet (o envio em segundo plano tenta de
  // novo mais tarde).
  final bool semRede;

  const ResultadoSincronizacao({
    required this.registrosEnviados,
    required this.fotosEnviadas,
    this.registrosBaixados = 0,
    this.fotosBaixadas = 0,
    this.erro,
    this.semRede = false,
  });
}

// Como está o envio para o servidor, para a tela de Atualizações.
class EstadoDoEnvio {
  final bool enviando;

  // O que ainda está no aparelho; null antes da primeira rodada.
  final ({int registros, int fotos, int paralisacoes})? pendentes;

  // Última rodada que foi até o fim (com ou sem recusas).
  final DateTime? ultimaRodadaCompleta;
  final String? ultimoErro;
  final DateTime? quandoErro;

  // O último erro foi falta de internet (e não recusa do servidor).
  final bool erroDeRede;

  const EstadoDoEnvio({
    this.enviando = false,
    this.pendentes,
    this.ultimaRodadaCompleta,
    this.ultimoErro,
    this.quandoErro,
    this.erroDeRede = false,
  });

  EstadoDoEnvio copiar({
    bool? enviando,
    ({int registros, int fotos, int paralisacoes})? pendentes,
  }) =>
      EstadoDoEnvio(
        enviando: enviando ?? this.enviando,
        pendentes: pendentes ?? this.pendentes,
        ultimaRodadaCompleta: ultimaRodadaCompleta,
        ultimoErro: ultimoErro,
        quandoErro: quandoErro,
        erroDeRede: erroDeRede,
      );
}

// Coluna que o servidor disse não ter (PGRST204); null se o erro é outro.
// Casa o nome ENTRE ASPAS, como vem na mensagem ("Could not find the
// 'km_final' column of 'registros_app'..."): sem as aspas, 'km' casava dentro
// de 'km_final', o app tirava a coluna km (obrigatória) e o registro nunca
// subia — travava a fila inteira do aparelho.
String? colunaDesconhecida(PostgrestException e, Iterable<String> campos) {
  if (e.code != 'PGRST204') return null;
  for (final campo in campos) {
    if (e.message.contains("'$campo'")) return campo;
  }
  return null;
}

// O app manda uma coluna que o servidor ainda não tem: falta aplicar a
// migration. O item fica pendente no celular até lá. Antes a coluna era
// tirada e o item marcado como enviado, e o dado dela se perdia.
class ColunaFaltandoNoServidor implements Exception {
  final String tabela;
  final String coluna;

  const ColunaFaltandoNoServidor(this.tabela, this.coluna);

  @override
  String toString() => 'o servidor não tem a coluna $coluna em $tabela';
}

// Mensagem que aponta a causa: rede, servidor recusando ou Supabase fora.
String descreverErroDoEnvio(Object e) {
  if (e is ColunaFaltandoNoServidor) {
    return 'o servidor ainda não tem a coluna "${e.coluna}" (${e.tabela}). '
        'Falta aplicar a migration no Supabase; os dados ficam no celular até lá';
  }
  if (e is PostgrestException) return 'Servidor recusou os dados: ${e.message}';
  if (e is TimeoutException) return 'Internet lenta demais: o envio não terminou';
  if (ehFalhaDeRede(e)) return 'Sem conexão com a internet';
  // Com o código, para o suporte achar a causa no Supabase.
  if (e is StorageException) {
    return 'Falha ao enviar foto (${e.statusCode}): ${e.message}';
  }
  final texto = e.toString();
  return texto.length > 140 ? texto.substring(0, 140) : texto;
}

// Sem rede (ou rede travada): não adianta tentar os próximos itens agora.
// O resto (o servidor respondeu recusando) é problema daquele item só.
bool ehFalhaDeRede(Object e) {
  if (e is SocketException ||
      e is TimeoutException ||
      e is HttpException ||
      e is HandshakeException) {
    return true;
  }
  // Recusa do servidor tem código HTTP; falha de rede vem com o nome da
  // exceção no lugar do código.
  if (e is StorageException) return int.tryParse(e.statusCode ?? '') == null;
  if (e is PostgrestException) return false;
  // ClientException do pacote http, sem depender dele.
  return e.runtimeType.toString().contains('ClientException');
}

// Envia ao Supabase os registros e fotos pendentes e baixa os lançados por
// outro aparelho. Cada linha é única por (dispositivo_id, id_local); o reenvio
// usa INSERT tratando duplicata como sucesso (upsert exigiria permissão de
// leitura que o RLS não dá).
// Nome seguro para arquivo no Storage: "REMOÇÃO DE CERCA" → "remocao_de_cerca".
String slugParaArquivo(String texto) {
  const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñªº';
  const semAcento = 'aaaaaeeeeiiiiooooouuuucnao';
  final resultado = StringBuffer();
  for (final rune in texto.trim().toLowerCase().runes) {
    var letra = String.fromCharCode(rune);
    final i = comAcento.indexOf(letra);
    if (i >= 0) letra = semAcento[i];
    resultado.write(RegExp(r'[a-z0-9]').hasMatch(letra) ? letra : '_');
  }
  final limpo = resultado
      .toString()
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return limpo.isEmpty ? 'sem_nome' : limpo;
}

class SincronizacaoService {
  SincronizacaoService({
    required ConfigDaObraService configDaObra,
    required FilialDoUsuario filial,
  })  : _configDaObra = configDaObra,
        _filial = filial;

  final ConfigDaObraService _configDaObra;

  // Decide a pasta das fotos no bucket.
  final FilialDoUsuario _filial;

  static const _chaveDispositivo = 'dispositivo_id';

  // Outra rodada (aqui ou no envio em segundo plano) ainda não terminou.
  static const erroEmAndamento = 'Sincronização já em andamento';

  // Teto para subir uma foto (uns 200 KB: sobra até em 3G ruim).
  static const _limiteDaFoto = Duration(seconds: 90);

  // Teto para gravar uma linha no banco.
  static const _limiteDaGravacao = Duration(seconds: 30);

  bool _executando = false;

  // Estado do envio, para mostrar na tela.
  final ValueNotifier<EstadoDoEnvio> estado = ValueNotifier(const EstadoDoEnvio());

  bool _ehFalhaDeRede(Object e) => ehFalhaDeRede(e);

  // Id deste aparelho (coluna dispositivo_id no Supabase), para o suporte.
  Future<String> idDoAparelho() => _dispositivoId();

  // Id fixo deste aparelho: separa no servidor os ids locais de cada celular.
  Future<String> _dispositivoId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_chaveDispositivo);
    if (id == null) {
      final aleatorio = Random.secure();
      id = List.generate(16, (_) => aleatorio.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(_chaveDispositivo, id);
    }
    return id;
  }

  // Até quantos dias atrás buscar registros de outro aparelho.
  static const int _diasParaBaixar = 30;

  // Traz os registros deste usuário feitos em outro aparelho, com as fotos.
  // Entram como já sincronizados e com a origem, para não serem reenviados.
  Future<int> _baixarRegistrosDeTerceiros(
    SupabaseClient supabase,
    String dispositivo,
    Database db,
  ) async {
    var usuario = AuthService.instancia.usuarioLogado;
    // Sem matrícula não dá para achar os registros: revalida o perfil aqui,
    // o que também renova o token que o RLS confere.
    if ((usuario?.matricula.trim() ?? '').isEmpty) {
      usuario = await AuthService.instancia.sincronizarPerfil();
    }
    final matricula = usuario?.matricula.trim() ?? '';
    if (usuario?.id == null || matricula.isEmpty) {
      debugPrint('Download de registros: usuário sem matrícula, nada a buscar');
      return 0;
    }

    final desde = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: _diasParaBaixar))
        .toIso8601String();

    // Tudo desta matrícula, de qualquer aparelho: cobre o lançado pelo
    // supervisor e o histórico num celular novo. O laço pula o que já existe.
    final linhas = await supabase
        .from('registros_app')
        .select()
        .eq('usuario_matricula', matricula)
        .gte('criado_em', desde);

    debugPrint('Download de registros: matrícula $matricula, '
        '${linhas.length} no servidor');

    var baixados = 0;
    for (final r in linhas) {
      final origemDispositivo = (r['dispositivo_id'] as String?) ?? '';
      final origemIdLocal = (r['id_local'] as num?)?.toInt();
      if (origemDispositivo.isEmpty || origemIdLocal == null) continue;

      // Saiu deste aparelho: só pula se a linha local for deste usuário
      // (pode ser do supervisor, em outro login no mesmo celular).
      if (origemDispositivo == dispositivo) {
        final propria = await db.query('registros',
            columns: ['id'],
            where: 'id = ? AND usuario_id = ?',
            whereArgs: [origemIdLocal, usuario!.id],
            limit: 1);
        if (propria.isNotEmpty) continue;
      }

      final jaTem = await db.query('registros',
          columns: ['id'],
          where: 'origem_dispositivo = ? AND origem_id_local = ?',
          whereArgs: [origemDispositivo, origemIdLocal],
          limit: 1);

      // Já baixado: não pula, porque as fotos podem ter subido depois ou
      // falhado na vez anterior.
      if (jaTem.isNotEmpty) {
        await _baixarFotosDoRegistro(
          supabase: supabase,
          db: db,
          registroLocalId: jaTem.first['id'] as int,
          origemDispositivo: origemDispositivo,
          origemRegistroIdLocal: origemIdLocal,
        );
        continue;
      }

      final registroId = await db.insert('registros', {
        'usuario_id': usuario!.id,
        'trecho': r['trecho'] ?? '',
        'km': r['km'] ?? '',
        'km_final': r['km_final'] ?? '',
        'via': r['via'] ?? '',
        'atividade': r['atividade'] ?? '',
        'estaca_inicial': r['estaca_inicial'] ?? '',
        'estaca_final': r['estaca_final'] ?? '',
        'servico_notavel': r['servico_notavel'] ?? '',
        'servico_notavel_detalhe': r['servico_notavel_detalhe'] ?? '',
        'quantidade': r['quantidade'],
        'unidade': r['unidade'] ?? '',
        'registrado_por_nome': r['registrado_por_nome'] ?? '',
        'origem_dispositivo': origemDispositivo,
        'origem_id_local': origemIdLocal,
        'descricao': r['descricao'] ?? '',
        'criado_em': r['criado_em'],
        'sincronizado': 1,
      });
      baixados++;

      await _baixarFotosDoRegistro(
        supabase: supabase,
        db: db,
        registroLocalId: registroId,
        origemDispositivo: origemDispositivo,
        origemRegistroIdLocal: origemIdLocal,
      );
    }
    return baixados;
  }

  // Teto de fotos baixadas por rodada; o resto vem nas seguintes.
  static const int _maxFotosPorRodada = 60;

  // Fotos trazidas na rodada atual.
  int _fotosBaixadasNaRodada = 0;

  Future<void> _baixarFotosDoRegistro({
    required SupabaseClient supabase,
    required Database db,
    required int registroLocalId,
    required String origemDispositivo,
    required int origemRegistroIdLocal,
  }) async {
    final fotos = await supabase
        .from('fotos_app')
        .select()
        .eq('dispositivo_id', origemDispositivo)
        .eq('registro_id_local', origemRegistroIdLocal);

    if (fotos.isEmpty) return;
    final pasta = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/fotos_baixadas');
    if (!pasta.existsSync()) pasta.createSync(recursive: true);

    for (final f in fotos) {
      if (_fotosBaixadasNaRodada >= _maxFotosPorRodada) return;
      final origemIdLocal = (f['id_local'] as num?)?.toInt();
      final caminhoStorage = (f['caminho_storage'] as String?) ?? '';
      if (origemIdLocal == null || caminhoStorage.isEmpty) continue;

      final jaTem = await db.query('fotos',
          columns: ['id'],
          where: 'origem_dispositivo = ? AND origem_id_local = ?',
          whereArgs: [origemDispositivo, origemIdLocal],
          limit: 1);
      if (jaTem.isNotEmpty) continue;

      try {
        final bytes =
            await supabase.storage.from('fotos').download(caminhoStorage);
        final destino = File(
            '${pasta.path}/${origemDispositivo.substring(0, 8)}_$origemIdLocal.jpg');
        // Assíncrono: gravar síncrono aqui congelava a tela.
        await destino.writeAsBytes(bytes);

        await db.insert('fotos', {
          'registro_id': registroLocalId,
          'caminho_arquivo': destino.path,
          'latitude': f['latitude'],
          'longitude': f['longitude'],
          'criado_em': f['criado_em'],
          'sincronizado': 1,
          'origem_dispositivo': origemDispositivo,
          'origem_id_local': origemIdLocal,
        });
        _fotosBaixadasNaRodada++;
      } catch (e) {
        // Foto que falha não derruba o registro; tenta de novo depois.
        debugPrint('Download da foto "$caminhoStorage" falhou: $e');
      }
    }
  }

  Future<ResultadoSincronizacao> sincronizar() async {
    const emAndamento = ResultadoSincronizacao(
      registrosEnviados: 0,
      fotosEnviadas: 0,
      erro: erroEmAndamento,
    );
    if (_executando) return emAndamento;
    _executando = true;
    // O envio em segundo plano roda em outro isolate (ver TravaDoEnvio).
    TravaDoEnvio? trava;
    try {
      trava = await TravaDoEnvio.doAparelho();
    } catch (e) {
      debugPrint('Trava do envio indisponível: $e');
    }
    if (trava != null && !await trava.pegar()) {
      _executando = false;
      return emAndamento;
    }
    estado.value = estado.value.copiar(enviando: true);
    var registrosEnviados = 0;
    var fotosEnviadas = 0;
    // Recusados pelo servidor nesta rodada: ficam para a próxima.
    var recusados = 0;
    String? motivoDaRecusa;
    try {
      final supabase = Supabase.instance.client;
      final dispositivo = await _dispositivoId();
      final db = await DbHelper.instancia.database;

      // A obra decide a pasta das fotos no bucket: confere antes de subir
      // (logo depois de atualizar o app, o aparelho ainda não a conhece).
      final obra = _configDaObra;
      if (!obra.obraConferida) await obra.sincronizar();

      // ── Registros pendentes (a matrícula liga à equipe do supervisor) ──
      final registros = await db.rawQuery('''
        SELECT r.*, u.email AS usuario_email, u.nome AS usuario_nome,
               u.matricula AS usuario_matricula
        FROM registros r JOIN usuarios u ON u.id = r.usuario_id
        WHERE r.sincronizado = 0 ORDER BY r.id
      ''');
      for (final r in registros) {
        // Em nome de terceiro: o dono é o encarregado e quem digitou vai em
        // registrado_por_*.
        final emNomeDeMatricula = (r['em_nome_de_matricula'] as String?) ?? '';
        final porTerceiro = emNomeDeMatricula.isNotEmpty;
        try {
          await _inserirIgnorandoDuplicata(supabase, 'registros_app', {
            'dispositivo_id': dispositivo,
            'id_local': r['id'],
            // usuario_* é o dono. Em nome de terceiro o e-mail fica vazio.
            'usuario_email': porTerceiro ? '' : r['usuario_email'],
            'usuario_nome': porTerceiro ? r['em_nome_de_nome'] : r['usuario_nome'],
            'usuario_matricula':
                porTerceiro ? emNomeDeMatricula : r['usuario_matricula'],
            'registrado_por_nome': porTerceiro ? r['usuario_nome'] : '',
            'registrado_por_matricula': porTerceiro ? r['usuario_matricula'] : '',
            'trecho': r['trecho'],
            'km': r['km'],
            'km_final': r['km_final'] ?? '',
            'via': r['via'],
            'atividade': r['atividade'],
            'estaca_inicial': r['estaca_inicial'],
            'estaca_final': r['estaca_final'],
            'servico_notavel': r['servico_notavel'],
            'servico_notavel_detalhe': r['servico_notavel_detalhe'],
            'quantidade': r['quantidade'],
            'unidade': r['unidade'],
            'descricao': r['descricao'],
            'criado_em': r['criado_em'],
          });
          // O insert já leva os campos corrigidos: nada de edição pendente.
          await db.update('registros', {'sincronizado': 1, 'edicao_pendente': 0},
              where: 'id = ?', whereArgs: [r['id']]);
          registrosEnviados++;
        } catch (e) {
          // Sem rede: para a rodada. Recusa do servidor: este fica para a
          // próxima e os outros seguem (antes, um travava a fila inteira).
          if (_ehFalhaDeRede(e)) rethrow;
          recusados++;
          motivoDaRecusa = _descreverErro(e);
          debugPrint('Registro ${r['id']} recusado: $e');
        }
      }

      // ── Fotos pendentes ──────────────────────────────────────────────────
      final fotos = await db.rawQuery('''
        SELECT f.*, r.atividade, u.nome AS usuario_nome
        FROM fotos f
        JOIN registros r ON r.id = f.registro_id
        JOIN usuarios u ON u.id = r.usuario_id
        WHERE f.sincronizado = 0 ORDER BY f.id
      ''');
      for (final f in fotos) {
        try {
          final caminhoLocal = f['caminho_arquivo'] as String;
          // Num isolate: ler e conferir a foto não trava a tela.
          final bytes = await compute(_prepararFotoParaUpload, caminhoLocal);
          if (bytes != null) {
            // Pasta por encarregado; id + aparelho evitam nomes repetidos.
            final atividade = slugParaArquivo(f['atividade'] as String);
            final caminhoStorage = caminhoNoBucket(_filial.codigo, f['usuario_nome'] as String,
                '${atividade}_${f['id']}_${dispositivo.substring(0, 8)}.jpg');
            await _subirArquivo(supabase, caminhoStorage, bytes, 'image/jpeg');

            // Original sem carimbo e minimapa, quando a foto os tem (o
            // painel mostra a foto sem carimbo e o carimbo pode ser refeito).
            final base = caminhoStorage.substring(0, caminhoStorage.length - 4);
            var originalStorage = '';
            var minimapaStorage = '';
            final caminhoOriginal = (f['caminho_original'] as String?) ?? '';
            if (caminhoOriginal.isNotEmpty) {
              final original =
                  await compute(_prepararFotoParaUpload, caminhoOriginal);
              if (original != null) {
                originalStorage = '${base}_original.jpg';
                await _subirArquivo(
                    supabase, originalStorage, original, 'image/jpeg');
              }
            }
            final caminhoMinimapa = (f['caminho_minimapa'] as String?) ?? '';
            if (caminhoMinimapa.isNotEmpty && File(caminhoMinimapa).existsSync()) {
              minimapaStorage = '${base}_minimapa.png';
              await _subirArquivo(supabase, minimapaStorage,
                  await File(caminhoMinimapa).readAsBytes(), 'image/png');
            }

            await _inserirIgnorandoDuplicata(supabase, 'fotos_app', {
              'dispositivo_id': dispositivo,
              'id_local': f['id'],
              'registro_id_local': f['registro_id'],
              'caminho_storage': caminhoStorage,
              'caminho_original_storage': originalStorage,
              'caminho_minimapa_storage': minimapaStorage,
              'latitude': f['latitude'],
              'longitude': f['longitude'],
              'criado_em': f['criado_em'],
            });
            fotosEnviadas++;
          } else {
            debugPrint('Foto ${f['id']}: arquivo não está mais no aparelho '
                '($caminhoLocal)');
          }
          // Arquivo sumiu do aparelho: marca assim mesmo, senão trava a fila.
          await db.update('fotos', {'sincronizado': 1, 'carimbo_pendente': 0},
              where: 'id = ?', whereArgs: [f['id']]);
        } catch (e) {
          if (_ehFalhaDeRede(e)) rethrow;
          recusados++;
          motivoDaRecusa = _descreverErro(e);
          debugPrint('Foto ${f['id']} recusada: $e');
        }
      }

      // ── Paralisações e clima do RDO (falha aqui não trava o resto) ──────
      await _enviarParalisacoes(supabase, dispositivo, db);
      await _enviarClima(supabase, db);

      // ── Correções feitas aqui em registros já enviados ──────────────────
      final correcoesRecusadas = await _enviarEdicoes(supabase, dispositivo, db) +
          await _enviarCarimbosRefeitos(supabase, dispositivo, db);
      if (correcoesRecusadas > 0) {
        recusados += correcoesRecusadas;
        motivoDaRecusa = 'correção sem permissão no servidor '
            '(rode supabase/editar_registros.sql)';
      }

      // ── Registros deste usuário feitos em outro aparelho ────────────────
      _fotosBaixadasNaRodada = 0;
      final baixados = await _baixarRegistrosDeTerceiros(supabase, dispositivo, db);

      // ── Correções feitas no servidor (supervisor ou outro aparelho) ─────
      // Quem tirou a foto refaz o carimbo e sobe a carimbada nova.
      if (await _baixarEdicoes(supabase, dispositivo, db) > 0) {
        await _enviarCarimbosRefeitos(supabase, dispositivo, db);
      }

      final erro = recusados == 0
          ? null
          : '$recusados item(ns) recusado(s) pelo servidor: $motivoDaRecusa';
      await _terminarRodada(erro: erro, ok: true);
      return ResultadoSincronizacao(
        registrosEnviados: registrosEnviados,
        fotosEnviadas: fotosEnviadas,
        registrosBaixados: baixados,
        fotosBaixadas: _fotosBaixadasNaRodada,
        erro: erro,
      );
    } catch (e) {
      debugPrint('Sincronização falhou: $e');
      final erro = _descreverErro(e);
      await _terminarRodada(erro: erro, ok: false, erroDeRede: _ehFalhaDeRede(e));
      return ResultadoSincronizacao(
        registrosEnviados: registrosEnviados,
        fotosEnviadas: fotosEnviadas,
        erro: erro,
        semRede: _ehFalhaDeRede(e),
      );
    } finally {
      _executando = false;
      await trava?.soltar();
    }
  }

  // Atualiza o [estado] no fim da rodada, com o que ainda falta enviar.
  Future<void> _terminarRodada(
      {String? erro, required bool ok, bool erroDeRede = false}) async {
    final pendentes = await contarPendentes();
    final agora = DateTime.now();
    estado.value = EstadoDoEnvio(
      enviando: false,
      pendentes: pendentes,
      ultimaRodadaCompleta: ok ? agora : estado.value.ultimaRodadaCompleta,
      ultimoErro: erro,
      quandoErro: erro == null ? null : agora,
      erroDeRede: erroDeRede,
    );
  }

  // Reconta o que falta enviar sem rodar o envio (antes da primeira rodada o
  // estado não tem as contagens, e um registro novo muda o número).
  Future<void> atualizarPendentes() async {
    final pendentes = await contarPendentes();
    estado.value = estado.value.copiar(pendentes: pendentes);
  }

  // O que ainda está no aparelho esperando para subir.
  Future<({int registros, int fotos, int paralisacoes})> contarPendentes() async {
    final db = await DbHelper.instancia.database;
    Future<int> contar(String tabela,
            [String condicao = 'sincronizado = 0']) async =>
        (await db.rawQuery('SELECT COUNT(*) AS n FROM $tabela WHERE $condicao'))
            .first['n'] as int;
    return (
      // Correção de registro já enviado também espera para subir.
      registros: await contar(
          'registros', 'sincronizado = 0 OR edicao_pendente = 1'),
      fotos: await contar('fotos', 'sincronizado = 0 OR carimbo_pendente = 1') +
          await contar('fotos_paralisacao'),
      paralisacoes: await contar('paralisacoes'),
    );
  }

  // Correções feitas aqui em registros já enviados. No servidor, a chave é a
  // do aparelho que criou o registro. Sem permissão (ou antes de
  // editar_registros.sql), nada é alterado e a correção fica na fila.
  // Devolve quantas foram recusadas.
  Future<int> _enviarEdicoes(
      SupabaseClient supabase, String dispositivo, Database db) async {
    var recusadas = 0;
    try {
      final pendentes = await db.query('registros',
          where: 'sincronizado = 1 AND edicao_pendente = 1', orderBy: 'id');
      for (final r in pendentes) {
        final origem = (r['origem_dispositivo'] as String?) ?? '';
        final alteradas = await supabase
            .from('registros_app')
            .update(CamposDoRegistro.deMapa(r).paraMapa())
            .eq('dispositivo_id', origem.isEmpty ? dispositivo : origem)
            .eq('id_local', (origem.isEmpty ? r['id'] : r['origem_id_local']) as int)
            .select('id')
            .timeout(_limiteDaGravacao);
        if (alteradas.isEmpty) {
          recusadas++;
          continue;
        }
        await db.update('registros', {'edicao_pendente': 0},
            where: 'id = ?', whereArgs: [r['id']]);
      }
    } catch (e) {
      debugPrint('Envio das correções falhou (tenta de novo depois): $e');
    }
    return recusadas;
  }

  // Fotos deste aparelho com o carimbo refeito depois de enviadas. A
  // carimbada nova sobe com outro nome (o painel não mostra a antiga do cache)
  // e fotos_app passa a apontar para ela. Devolve quantas foram recusadas.
  Future<int> _enviarCarimbosRefeitos(
      SupabaseClient supabase, String dispositivo, Database db) async {
    var recusadas = 0;
    try {
      final fotos = await db.rawQuery("""
        SELECT f.*, r.atividade, u.nome AS usuario_nome
        FROM fotos f
        JOIN registros r ON r.id = f.registro_id
        JOIN usuarios u ON u.id = r.usuario_id
        WHERE f.sincronizado = 1 AND f.carimbo_pendente = 1
          AND f.origem_dispositivo = ''
        ORDER BY f.id
      """);
      for (final f in fotos) {
        final bytes =
            await compute(_prepararFotoParaUpload, f['caminho_arquivo'] as String);
        if (bytes != null) {
          final caminhoStorage = caminhoNoBucket(
              _filial.codigo,
              f['usuario_nome'] as String,
              '${slugParaArquivo(f['atividade'] as String)}_${f['id']}_'
              '${dispositivo.substring(0, 8)}_e${DateTime.now().millisecondsSinceEpoch}.jpg');
          await _subirArquivo(supabase, caminhoStorage, bytes, 'image/jpeg');
          final alteradas = await supabase
              .from('fotos_app')
              .update({'caminho_storage': caminhoStorage})
              .eq('dispositivo_id', dispositivo)
              .eq('id_local', f['id'] as int)
              .select('id')
              .timeout(_limiteDaGravacao);
          if (alteradas.isEmpty) {
            recusadas++;
            continue;
          }
        }
        await db.update('fotos', {'carimbo_pendente': 0},
            where: 'id = ?', whereArgs: [f['id']]);
      }
    } catch (e) {
      debugPrint('Envio dos carimbos refeitos falhou (tenta de novo depois): $e');
    }
    return recusadas;
  }

  // Até onde as correções do servidor já foram trazidas.
  static const String _chaveUltimaCorrecao = 'ultima_correcao_baixada';

  // Correções feitas no servidor nos registros criados neste aparelho ou do
  // usuário logado. A correção daqui que ainda não subiu vale por cima (é a
  // mais recente). Devolve quantos registros mudaram.
  Future<int> _baixarEdicoes(
      SupabaseClient supabase, String dispositivo, Database db) async {
    var aplicadas = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final desde =
          prefs.getString(_chaveUltimaCorrecao) ?? '1970-01-01T00:00:00Z';
      final matricula =
          AuthService.instancia.usuarioLogado?.matricula.trim() ?? '';

      var consulta = supabase
          .from('registros_app')
          .select('dispositivo_id, id_local, editado_em, trecho, km, km_final, '
              'via, atividade, estaca_inicial, estaca_final, servico_notavel, '
              'servico_notavel_detalhe, quantidade, unidade, descricao')
          .gt('editado_em', desde);
      consulta = matricula.isEmpty
          ? consulta.eq('dispositivo_id', dispositivo)
          : consulta.or(
              'dispositivo_id.eq.$dispositivo,usuario_matricula.eq.$matricula');
      final linhas =
          await consulta.order('editado_em').limit(500).timeout(_limiteDaGravacao);

      var maisRecente = desde;
      for (final l in linhas) {
        final editadoEm = l['editado_em'] as String;
        if (editadoEm.compareTo(maisRecente) > 0) maisRecente = editadoEm;

        final doAparelho = l['dispositivo_id'] == dispositivo;
        final locais = await db.query(
          'registros',
          where: doAparelho
              ? "id = ? AND origem_dispositivo = ''"
              : 'origem_dispositivo = ? AND origem_id_local = ?',
          whereArgs: doAparelho
              ? [l['id_local']]
              : [l['dispositivo_id'], l['id_local']],
        );
        if (locais.isEmpty) continue;
        final local = locais.first;
        if (local['edicao_pendente'] == 1) continue;

        final campos = CamposDoRegistro.deMapa(l);
        if (campos.mesmoQue(CamposDoRegistro.deMapa(local))) {
          // A própria correção que subiu deste aparelho.
          await db.update('registros', {'editado_em': editadoEm},
              where: 'id = ?', whereArgs: [local['id']]);
          continue;
        }
        await EdicaoRegistroService.instancia
            .aplicarDoServidor(local['id'] as int, campos, editadoEm);
        aplicadas++;
      }
      await prefs.setString(_chaveUltimaCorrecao, maisRecente);
    } catch (e) {
      debugPrint('Busca das correções do servidor falhou (tenta de novo depois): $e');
    }
    return aplicadas;
  }

  // Paralisações pendentes e as fotos delas. Só as do usuário logado: o
  // servidor confere a matrícula de quem envia (ver clima_paralisacoes.sql).
  // Mudança numa paralisação já enviada sobrescreve a linha do servidor.
  Future<void> _enviarParalisacoes(
      SupabaseClient supabase, String dispositivo, Database db) async {
    final usuario = AuthService.instancia.usuarioLogado;
    final matricula = usuario?.matricula.trim() ?? '';
    if (usuario?.id == null || matricula.isEmpty) return;
    try {
      final pendentes = await db.query('paralisacoes',
          where: 'sincronizado = 0 AND usuario_id = ?',
          whereArgs: [usuario!.id],
          orderBy: 'id');
      for (final p in pendentes) {
        await _gravar(
          supabase,
          'paralisacoes_app',
          {
            'dispositivo_id': dispositivo,
            'id_local': p['id'],
            'usuario_matricula': matricula,
            'usuario_nome': usuario.nome,
            'motivo': p['motivo'],
            'observacao': p['observacao'],
            'trecho': p['trecho'],
            'km': p['km'],
            'inicio': p['inicio'],
            'fim': p['fim'],
            'excluida': p['excluida'] == 1,
            'criado_em': p['criado_em'],
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'dispositivo_id,id_local',
        );
        await db.update('paralisacoes', {'sincronizado': 1},
            where: 'id = ?', whereArgs: [p['id']]);
      }

      // Só com a paralisação já no servidor: a foto aponta para ela.
      final fotos = await db.rawQuery('''
        SELECT f.*, p.motivo FROM fotos_paralisacao f
        JOIN paralisacoes p ON p.id = f.paralisacao_id
        WHERE f.sincronizado = 0 AND p.sincronizado = 1 AND p.usuario_id = ?
        ORDER BY f.id
      ''', [usuario.id]);
      for (final f in fotos) {
        final bytes =
            await compute(_prepararFotoParaUpload, f['caminho_arquivo'] as String);
        if (bytes != null) {
          final caminhoStorage = caminhoNoBucket(
              _filial.codigo,
              usuario.nome,
              'paralisacao_${slugParaArquivo(f['motivo'] as String)}_${f['id']}_'
              '${dispositivo.substring(0, 8)}.jpg');
          try {
            await supabase.storage.from('fotos').uploadBinary(
                  caminhoStorage,
                  bytes,
                  fileOptions: const FileOptions(contentType: 'image/jpeg'),
                );
          } on StorageException catch (e) {
            if (e.statusCode != '409') rethrow;
          }
          await _inserirIgnorandoDuplicata(supabase, 'paralisacao_fotos_app', {
            'dispositivo_id': dispositivo,
            'id_local': f['id'],
            'paralisacao_id_local': f['paralisacao_id'],
            'caminho_storage': caminhoStorage,
            'latitude': f['latitude'],
            'longitude': f['longitude'],
            'criado_em': f['criado_em'],
          });
        }
        await db.update('fotos_paralisacao', {'sincronizado': 1},
            where: 'id = ?', whereArgs: [f['id']]);
      }
    } catch (e) {
      debugPrint('Envio das paralisações falhou (tenta de novo depois): $e');
    }
  }

  // Clima do RDO de cada dia, para o relatório do supervisor. Um por
  // matrícula e dia: gerar o RDO de novo sobrescreve.
  Future<void> _enviarClima(SupabaseClient supabase, Database db) async {
    final usuario = AuthService.instancia.usuarioLogado;
    final matricula = usuario?.matricula.trim() ?? '';
    if (usuario?.id == null || matricula.isEmpty) return;
    try {
      final pendentes = await db.query('relatorio_diario_info',
          where: 'sincronizado = 0 AND usuario_id = ?', whereArgs: [usuario!.id]);
      for (final i in pendentes) {
        await _gravar(
          supabase,
          'clima_dia_app',
          {
            'usuario_matricula': matricula,
            'data': i['data'],
            'usuario_nome': usuario.nome,
            'clima_manha': i['clima_manha'] ?? '',
            'clima_tarde': i['clima_tarde'] ?? '',
            'clima_noite': i['clima_noite'] ?? '',
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'usuario_matricula,data',
        );
        await db.update('relatorio_diario_info', {'sincronizado': 1},
            where: 'id = ?', whereArgs: [i['id']]);
      }
    } catch (e) {
      debugPrint('Envio do clima falhou (tenta de novo depois): $e');
    }
  }

  // Sobe um arquivo para o bucket fotos. 409 = já existe (reenvio após falha
  // na marcação): tudo certo.
  Future<void> _subirArquivo(SupabaseClient supabase, String caminho,
      Uint8List bytes, String tipo) async {
    try {
      await supabase.storage
          .from('fotos')
          .uploadBinary(caminho, bytes, fileOptions: FileOptions(contentType: tipo))
          // Sem limite, um envio preso no 4G fraco deixava a sincronização
          // "em andamento" até o app fechar.
          .timeout(_limiteDaFoto);
    } on StorageException catch (e) {
      if (e.statusCode != '409') rethrow;
    }
  }

  // Upsert pela chave [onConflict]. Coluna que o servidor não tem: o item
  // fica pendente (ver [ColunaFaltandoNoServidor]).
  Future<void> _gravar(
    SupabaseClient supabase,
    String tabela,
    Map<String, dynamic> dados, {
    required String onConflict,
  }) async {
    try {
      await supabase
          .from(tabela)
          .upsert(dados, onConflict: onConflict)
          .timeout(_limiteDaGravacao);
    } on PostgrestException catch (e) {
      final campo = _campoDesconhecido(e, dados.keys);
      if (campo == null) rethrow;
      throw ColunaFaltandoNoServidor(tabela, campo);
    }
  }

  // INSERT que trata duplicata (23505) como sucesso: a linha já tinha chegado.
  Future<void> _inserirIgnorandoDuplicata(
    SupabaseClient supabase,
    String tabela,
    Map<String, dynamic> dados,
  ) async {
    try {
      await supabase.from(tabela).insert(dados).timeout(_limiteDaGravacao);
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      // Coluna que o servidor ainda não tem: o item fica pendente, e os
      // outros seguem.
      final campo = _campoDesconhecido(e, dados.keys);
      if (campo == null) rethrow;
      throw ColunaFaltandoNoServidor(tabela, campo);
    }
  }

  String? _campoDesconhecido(PostgrestException e, Iterable<String> campos) =>
      colunaDesconhecida(e, campos);

  String _descreverErro(Object e) => descreverErroDoEnvio(e);
}

// Caminho de um arquivo no bucket fotos: pasta da filial, pasta do
// encarregado e o nome ("010152/joao_silva/terraplanagem_12_ab12cd34.jpg").
String caminhoNoBucket(
        String filial, String usuarioNome, String nomeArquivo) =>
    '$filial/${slugParaArquivo(usuarioNome)}/$nomeArquivo';

// Largura máxima da foto no servidor.
const int larguraMaximaNoServidor = 1920;

// Roda no compute: a foto que vai para o servidor; null se sumiu ou não abre.
// A foto do app (720p, já carimbada) sobe como está: comprimir de novo só
// perdia qualidade. Reduz só a que passa de [larguraMaximaNoServidor].
Uint8List? _prepararFotoParaUpload(String caminho) {
  final arquivo = File(caminho);
  if (!arquivo.existsSync()) return null;
  try {
    final bytes = arquivo.readAsBytesSync();
    // Só o cabeçalho: decodificar a foto inteira para saber a largura é caro.
    final largura = img.JpegDecoder().startDecode(bytes)?.width;
    if (largura != null && largura > 0 && largura <= larguraMaximaNoServidor) {
      return bytes;
    }
    final original = img.decodeImage(bytes);
    if (original == null) return null;
    if (original.width <= larguraMaximaNoServidor) return bytes;
    final reduzida = img.copyResize(original,
        width: larguraMaximaNoServidor, interpolation: img.Interpolation.average);
    return Uint8List.fromList(img.encodeJpg(reduzida, quality: 90));
  } catch (_) {
    return null;
  }
}

// Para os testes.
@visibleForTesting
Uint8List? prepararFotoParaUploadParaTeste(String caminho) =>
    _prepararFotoParaUpload(caminho);
