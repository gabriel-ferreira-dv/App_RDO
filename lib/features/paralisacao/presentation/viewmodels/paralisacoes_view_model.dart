import 'package:flutter/foundation.dart';

import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../../core/obra/dia_de_trabalho.dart';

// Aba "Paradas": qual dia de trabalho está na tela. "Hoje" respeita o turno
// da noite (a madrugada ainda é do dia anterior).
class ParalisacoesViewModel extends ChangeNotifier {
  ParalisacoesViewModel({
    RelogioDoTurno relogio = const RelogioDoTurno(),
    Listenable? mudancasNoTurno,
  })  : _relogio = relogio,
        _mudancasNoTurno = mudancasNoTurno {
    _mudancasNoTurno?.addListener(notifyListeners);
  }

  // O turno é lido a cada uso: a lista do turno da noite pode chegar do
  // servidor depois de a aba abrir ([mudancasNoTurno] avisa).
  final RelogioDoTurno _relogio;
  final Listenable? _mudancasNoTurno;

  // null = hoje, que acompanha o turno e a virada do dia.
  DateTime? _diaEscolhido;

  bool get noturno => _relogio.noturno();
  DateTime get hoje => _relogio.hoje;
  DateTime get dia => _diaEscolhido ?? hoje;

  void mudarDia(DateTime dia) {
    final novo = dia.soDia;
    // Hoje ou depois (não passa de hoje): volta a acompanhar o hoje.
    final escolhido = novo.isBefore(hoje) ? novo : null;
    if (escolhido == _diaEscolhido) return;
    _diaEscolhido = escolhido;
    notifyListeners();
  }

  @override
  void dispose() {
    _mudancasNoTurno?.removeListener(notifyListeners);
    super.dispose();
  }
}
