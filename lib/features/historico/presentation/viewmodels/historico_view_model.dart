import '../../../../core/estado/descarte_seguro.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../registro/domain/entities/grupo_atividade.dart';
import '../../domain/entities/item_do_historico.dart';
import '../../domain/repositories/historico_repository.dart';

// O que a lista mostra, em ordem: cabeçalhos de dia e registros.
sealed class LinhaDoHistorico {
  const LinhaDoHistorico();
}

class CabecalhoDoDia extends LinhaDoHistorico {
  final String texto;
  const CabecalhoDoDia(this.texto);
}

class RegistroNaLista extends LinhaDoHistorico {
  final ItemDoHistorico item;
  const RegistroNaLista(this.item);
}

// Histórico do usuário: carregar, filtrar por período e corrigir.
class HistoricoViewModel extends ChangeNotifier with DescarteSeguro {
  HistoricoViewModel({
    required HistoricoRepository repositorio,
    required this.usuarioId,
    VoidCallback? aoCorrigir,
    DateTime Function() agora = DateTime.now,
  })  : _repositorio = repositorio,
        _aoCorrigir = aoCorrigir,
        _agora = agora;

  final HistoricoRepository _repositorio;

  // Depois de corrigir (manda a correção para o servidor).
  final VoidCallback? _aoCorrigir;
  final DateTime Function() _agora;

  final int usuarioId;

  bool _carregando = true;
  bool _falhou = false;
  List<GrupoAtividade> _grupos = const [];
  PeriodoDoHistorico _periodo = PeriodoDoHistorico.hoje;

  bool get carregando => _carregando;

  // A última leitura deu erro; a lista fica como estava.
  bool get falhou => _falhou;
  PeriodoDoHistorico get periodo => _periodo;
  bool get podeVerTodos => _periodo != PeriodoDoHistorico.tudo;

  List<LinhaDoHistorico> get linhas {
    final agora = _agora();
    final linhas = <LinhaDoHistorico>[];
    DateTime? diaAnterior;
    for (final item in itensDoPeriodo(_grupos, _periodo, agora)) {
      if (_periodo.variosDias && item.dia != diaAnterior) {
        linhas.add(CabecalhoDoDia(rotuloDoDia(item.dia, agora)));
        diaAnterior = item.dia;
      }
      linhas.add(RegistroNaLista(item));
    }
    return linhas;
  }

  // Erro na leitura não deixa a tela girando: mostra o aviso, e puxar para
  // baixo tenta de novo.
  Future<void> carregar() async {
    mudar(() => _carregando = true);
    try {
      final grupos = await _repositorio.gruposDoUsuario(usuarioId);
      mudar(() {
        _grupos = grupos;
        _falhou = false;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Histórico: erro ao carregar: $e');
      mudar(() {
        _falhou = true;
        _carregando = false;
      });
    }
  }

  void escolherPeriodo(PeriodoDoHistorico periodo) =>
      mudar(() => _periodo = periodo);

  void verTodos() => escolherPeriodo(PeriodoDoHistorico.tudo);

  // ── Correção ──────────────────────────────────────────────────────────────

  Future<CamposDoRegistro?> camposParaCorrigir(RegistroAgrupado registro) =>
      _repositorio.camposDoRegistro(registro.registroId);

  String subtituloDaCorrecao(RegistroAgrupado registro) =>
      'Registro de ${formatarDataHora(registro.criadoEm)}';

  // Grava no celular, refaz o carimbo e manda para o servidor; devolve false
  // se não conseguiu gravar. A lista recarrega em seguida, sem prender quem
  // chamou (a tela fecha o "Refazendo o carimbo" assim que gravou).
  Future<bool> corrigir(
      RegistroAgrupado registro, CamposDoRegistro campos) async {
    try {
      await _repositorio.corrigir(registro.registroId, campos);
    } catch (e) {
      debugPrint('Histórico: erro ao corrigir: $e');
      return false;
    }
    _aoCorrigir?.call();
    unawaited(carregar());
    return true;
  }
}
