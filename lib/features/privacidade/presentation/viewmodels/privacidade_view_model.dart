import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../../core/extensions/data_hora_extensions.dart';
import '../../domain/entities/aviso_de_privacidade.dart';
import '../../domain/entities/linha_do_aviso.dart';
import '../../domain/usecases/carregar_aviso_de_privacidade.dart';
import '../../domain/usecases/confirmar_leitura_do_aviso.dart';

enum SituacaoDoAviso { carregando, pronto, indisponivel }

// Estado e ações da tela do aviso de privacidade. Dois modos:
// - consulta (Mais, login): carrega o aviso da filial;
// - ciência (primeira abertura ou versão nova): recebe o aviso pendente e
//   pede "Li e entendi" antes de sair.
class PrivacidadeViewModel extends ChangeNotifier with DescarteSeguro {
  PrivacidadeViewModel({
    required CarregarAvisoDePrivacidade carregarAviso,
    required ConfirmarLeituraDoAviso confirmarLeitura,
    required this.filial,
    this.email = '',
    AvisoDePrivacidade? avisoPendente,
  })  : _carregarAviso = carregarAviso,
        _confirmarLeitura = confirmarLeitura,
        _aviso = avisoPendente,
        pedirCiencia = avisoPendente != null,
        _situacao = avisoPendente != null
            ? SituacaoDoAviso.pronto
            : SituacaoDoAviso.carregando;

  final CarregarAvisoDePrivacidade _carregarAviso;
  final ConfirmarLeituraDoAviso _confirmarLeitura;

  final String filial;

  // E-mail de quem está logado; vazio na tela de login.
  final String email;

  // Modo ciência: botão "Li e entendi" e sem voltar.
  final bool pedirCiencia;

  AvisoDePrivacidade? _aviso;
  SituacaoDoAviso _situacao;
  bool _confirmando = false;

  SituacaoDoAviso get situacao => _situacao;
  bool get confirmando => _confirmando;
  List<LinhaDoAviso> get linhas => _aviso?.linhas ?? const [];

  // "Versão 2 · atualizado em 22/10/2026"
  String get versaoEData {
    final aviso = _aviso;
    if (aviso == null) return '';
    final quando = aviso.atualizadoEm;
    return quando == null
        ? 'Versão ${aviso.versao}'
        : 'Versão ${aviso.versao} · atualizado em ${quando.dataCurta}';
  }

  // Busca o aviso da filial (no modo ciência ele já veio pronto).
  Future<void> carregar() async {
    if (pedirCiencia) return;
    mudar(() => _situacao = SituacaoDoAviso.carregando);
    final aviso = await _carregarAviso(filial);
    mudar(() {
      _aviso = aviso;
      _situacao =
          aviso == null ? SituacaoDoAviso.indisponivel : SituacaoDoAviso.pronto;
    });
  }

  // "Li e entendi". true quando a leitura foi guardada e a tela pode fechar.
  Future<bool> confirmar() async {
    final aviso = _aviso;
    if (!pedirCiencia || aviso == null || _confirmando) return false;
    mudar(() => _confirmando = true);
    await _confirmarLeitura(email, aviso);
    return true;
  }

  // Avisa a tela, a não ser que ela já tenha fechado.
}
