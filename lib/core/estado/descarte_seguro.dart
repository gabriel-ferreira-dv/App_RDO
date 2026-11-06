import 'package:flutter/foundation.dart';

// Para ViewModels com buscas assíncronas: uma resposta que chega depois de a
// tela fechar (ViewModel já descartado) é ignorada, em vez de dar o erro
// "used after being disposed".
mixin DescarteSeguro on ChangeNotifier {
  bool _descartado = false;

  bool get descartado => _descartado;

  // Aplica a mudança e avisa a tela; depois do descarte, não faz nada.
  @protected
  void mudar(VoidCallback mudanca) {
    if (_descartado) return;
    mudanca();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_descartado) super.notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
