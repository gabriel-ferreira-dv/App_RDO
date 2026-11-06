import 'dart:async';

import 'package:namer_app/features/historico/domain/repositories/historico_repository.dart';
import 'package:namer_app/features/registro/domain/entities/campos_do_registro.dart';
import 'package:namer_app/features/registro/domain/entities/grupo_atividade.dart';

// Data fixa: quarta-feira, 15/07/2026, ao meio-dia (local).
final agoraDeTeste = DateTime(2026, 7, 15, 12);

FotoAgrupada foto(int id, {bool pendente = false}) => FotoAgrupada(
      fotoId: id,
      caminhoArquivo: 'foto_$id.jpg',
      criadoEm: agoraDeTeste.toUtc().toIso8601String(),
      pendente: pendente,
    );

RegistroAgrupado registro(
  int id,
  DateTime criadoEm, {
  List<FotoAgrupada>? fotos,
  bool registroPendente = false,
  bool corrigido = false,
  String estacaInicial = '1115',
  String estacaFinal = '1120',
}) =>
    RegistroAgrupado(
      registroId: id,
      via: 'Via 02 Norte',
      estacaInicial: estacaInicial,
      estacaFinal: estacaFinal,
      descricao: '',
      criadoEm: criadoEm.toUtc().toIso8601String(),
      fotos: fotos ?? [foto(id)],
      registroPendente: registroPendente,
      corrigido: corrigido,
    );

GrupoAtividade grupo(List<RegistroAgrupado> registros) => GrupoAtividade(
      trecho: 'C1',
      km: '225',
      atividade: 'Terraplanagem',
      servicoNotavel: 'COMPACTAÇÃO DE ATERRO',
      servicoNotavelDetalhe: 'Aterro na saia',
      registros: registros,
    );

const camposDeTeste = CamposDoRegistro(
  trecho: 'C1',
  km: '225',
  atividade: 'Terraplanagem',
  servicoNotavel: 'COMPACTAÇÃO DE ATERRO',
);

// Repositório em memória. [falharAoCarregar] e [falharAoCorrigir] simulam
// erro do banco; [segurarCarga] deixa a leitura esperando.
class RepositorioFalso implements HistoricoRepository {
  List<GrupoAtividade> grupos = [];
  final campos = <int, CamposDoRegistro>{};
  final corrigidos = <int, CamposDoRegistro>{};
  var cargas = 0;
  bool falharAoCarregar = false;
  bool falharAoCorrigir = false;
  Completer<void>? segurarCarga;

  @override
  Future<List<GrupoAtividade>> gruposDoUsuario(int usuarioId) async {
    cargas++;
    await segurarCarga?.future;
    if (falharAoCarregar) throw StateError('banco indisponível');
    return grupos;
  }

  @override
  Future<CamposDoRegistro?> camposDoRegistro(int registroId) async =>
      campos[registroId];

  @override
  Future<void> corrigir(int registroId, CamposDoRegistro campos) async {
    if (falharAoCorrigir) throw StateError('banco indisponível');
    corrigidos[registroId] = campos;
  }
}
