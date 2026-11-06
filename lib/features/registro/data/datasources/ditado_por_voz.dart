import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/repositories/ditado.dart';

// Ditado pelo reconhecimento de voz do celular (speech_to_text), em pt_BR.
class DitadoPorVoz implements Ditado {
  final SpeechToText _fala = SpeechToText();
  bool _pronto = false;

  @override
  Future<bool> iniciar() async {
    if (_pronto) return true;
    _pronto = await _fala.initialize(
      onError: (erro) => debugPrint('Ditado: ${erro.errorMsg}'),
    );
    return _pronto;
  }

  @override
  Future<void> ouvir({
    required void Function(String texto) aoReconhecer,
    void Function()? aoTerminar,
  }) async {
    await _fala.listen(
      onResult: (resultado) {
        aoReconhecer(resultado.recognizedWords);
        if (resultado.finalResult) aoTerminar?.call();
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        localeId: 'pt_BR',
      ),
    );
  }

  @override
  Future<void> parar() => _fala.stop();

  @override
  void cancelar() => _fala.cancel();
}
