import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

// Trava entre o app aberto e o envio em segundo plano. No Android a tarefa do
// WorkManager roda num isolate separado, no mesmo processo, e cada isolate
// tem as próprias variáveis: o `_executando` da sincronização não enxerga o
// outro. Dois enviando juntos baixariam o mesmo registro duas vezes.
//
// A trava é um arquivo criado em modo exclusivo, com o pid do processo e a
// hora. Quem segura renova a hora a cada minuto. Trava de outro processo (o
// app foi fechado no meio do envio) ou sem renovação há mais de [validade]
// não vale mais.
class TravaDoEnvio {
  TravaDoEnvio(this.arquivo,
      {this.validade = const Duration(minutes: 3), int? processo})
      : _processo = processo ?? pid;

  final File arquivo;
  final Duration validade;
  final int _processo;

  // Quantas vezes este isolate pegou a trava (a tarefa pega, e a
  // sincronização que ela chama pega de novo).
  int _usos = 0;
  Timer? _renovacao;

  static TravaDoEnvio? _doAparelho;

  // A trava do aparelho, na pasta de dados do app.
  static Future<TravaDoEnvio> doAparelho() async {
    final pasta = await getApplicationSupportDirectory();
    return _doAparelho ??= TravaDoEnvio(File('${pasta.path}/envio.trava'));
  }

  bool get segurando => _usos > 0;

  // true se conseguiu a trava (ou se este isolate já a segura).
  Future<bool> pegar() async {
    if (_usos > 0) {
      _usos++;
      return true;
    }
    for (var tentativa = 0; tentativa < 2; tentativa++) {
      try {
        await arquivo.create(exclusive: true);
        _usos = 1;
        await _marcar();
        _renovacao = Timer.periodic(const Duration(minutes: 1), (_) => _marcar());
        return true;
      } on FileSystemException {
        if (!await _abandonada()) return false;
        try {
          await arquivo.delete();
        } on FileSystemException {
          // Outro isolate apagou antes; a próxima volta tenta criar.
        }
      }
    }
    return false;
  }

  Future<void> soltar() async {
    if (_usos == 0) return;
    if (--_usos > 0) return;
    _renovacao?.cancel();
    _renovacao = null;
    try {
      await arquivo.delete();
    } on FileSystemException {
      // Já não existia.
    }
  }

  Future<void> _marcar() async {
    try {
      await arquivo.writeAsString(
          '$_processo;${DateTime.now().millisecondsSinceEpoch}',
          flush: true);
    } on FileSystemException {
      // Sem a renovação a trava vence sozinha; o envio segue.
    }
  }

  Future<bool> _abandonada() async {
    try {
      final partes = (await arquivo.readAsString()).split(';');
      final dono = int.tryParse(partes.first);
      final marcadaEm = partes.length > 1 ? int.tryParse(partes[1]) : null;
      if (dono == null || marcadaEm == null) {
        // Outro isolate acabou de criar e ainda não escreveu.
        return DateTime.now().difference(await arquivo.lastModified()) > validade;
      }
      if (dono != _processo) return true;
      return DateTime.now().millisecondsSinceEpoch - marcadaEm >
          validade.inMilliseconds;
    } on FileSystemException {
      // Sumiu entre a tentativa e a leitura: pode tentar de novo.
      return true;
    }
  }
}
