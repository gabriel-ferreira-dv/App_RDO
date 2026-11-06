import '../entities/sugestao_gps.dart';

// Onde a pessoa está na obra: a estaca do projeto mais perto do GPS.
abstract interface class LocalizacaoNaObra {
  // A sugestão de trecho, KM, estaca e via; ou o motivo de não ter (GPS
  // desligado, sem permissão, longe da obra).
  Future<ResultadoSugestaoGps> sugerir();
}
