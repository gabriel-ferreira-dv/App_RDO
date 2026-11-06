import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/registro.dart';
import '../../domain/regras/vias_estaqueamento.dart' show textoDoKm;
import '../../domain/repositories/registro_repository.dart';

// Registros anteriores do usuário, para servir de modelo a um novo, com o
// filtro por dia.
class ImportarAtividadeViewModel extends ChangeNotifier with DescarteSeguro {
  ImportarAtividadeViewModel({
    required RegistroRepository registros,
    required this.usuarioId,
  }) : _repositorio = registros;

  final RegistroRepository _repositorio;
  final int usuarioId;

  bool _carregando = true;
  bool _falhou = false;
  List<Registro> _registros = const [];
  DateTime? _diaFiltro;

  bool get carregando => _carregando;
  bool get semRegistros => _registros.isEmpty;

  // A leitura deu erro (a tela avisa, em vez de girar para sempre).
  bool get falhou => _falhou;
  DateTime? get diaFiltro => _diaFiltro;

  // Dias com registro, do mais novo para o mais antigo.
  List<DateTime> get dias {
    final dias = <DateTime>{
      for (final r in _registros)
        if (diaLocalDe(r.criadoEm) case final dia?) dia,
    };
    return dias.toList()..sort((a, b) => b.compareTo(a));
  }

  List<Registro> get registros => _diaFiltro == null
      ? _registros
      : [
          for (final r in _registros)
            if (diaLocalDe(r.criadoEm) == _diaFiltro) r,
        ];

  // "C1 • KM 225" (sem KM, só o trecho).
  String titulo(Registro r) => [r.trecho, textoDoKm(r.km, r.kmFinal)]
      .where((t) => t.isNotEmpty)
      .join(' • ');

  String data(Registro r) => formatarData(r.criadoEm);

  Future<void> carregar() async {
    try {
      final registros = await _repositorio.listarRegistros(usuarioId);
      mudar(() {
        _registros = registros;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Importar atividade: erro ao carregar: $e');
      mudar(() {
        _falhou = true;
        _carregando = false;
      });
    }
  }

  void filtrarPorDia(DateTime? dia) => mudar(() => _diaFiltro = dia);
}
