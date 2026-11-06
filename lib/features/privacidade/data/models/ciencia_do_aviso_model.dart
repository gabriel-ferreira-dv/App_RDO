import '../../domain/entities/ciencia_do_aviso.dart';

// A confirmação de leitura é guardada no celular como "versão|data ISO".

// Valor estranho conta como não lido (null).
CienciaDoAviso? cienciaDoTexto(String? valor) {
  final partes = valor?.split('|');
  if (partes == null || partes.length != 2) return null;
  final versao = int.tryParse(partes[0]);
  final quando = DateTime.tryParse(partes[1]);
  if (versao == null || quando == null) return null;
  return CienciaDoAviso(versao, quando);
}

extension CienciaDoAvisoTexto on CienciaDoAviso {
  String paraTexto() => '$versao|${quando.toIso8601String()}';
}
