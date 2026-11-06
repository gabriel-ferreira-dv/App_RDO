// Regras de estaqueamento por via, lidas da configuração da obra (nomes das
// vias, onde começa a segunda série, trechos sem via ou sem estaca). Nesta
// obra, no C1 a Via 02 Norte é a série 1000 e a Via 01 Sul a 2000 (a 2115
// fica ao lado da 1115); no D2 há uma série só e a via é escolhida pelo
// usuário.

import '../../../../core/obra/config_da_obra.dart';
import '../../../../core/extensions/texto_extensions.dart';

// Via da segunda série e via da numeração principal ('' em obra sem via).
String get viaSul => obraAtual.vias?.segundaSerie ?? '';
String get viaNorte => obraAtual.vias?.primeiraSerie ?? '';

// Só os dígitos ("EST. 57" → "57"): os CSVs escrevem a estaca diferente.
String numeroDaEstaca(String texto) => texto.replaceAll(RegExp(r'[^0-9]'), '');

// Primeira estaca da série sul; null quando a numeração não separa as vias.
int? get inicioSerieSul => obraAtual.vias?.inicioSegundaSerie;

// Distância entre as duas numerações: a estaca 1115 vira 2115 na outra pista.
int get deslocamentoEntreSeries => obraAtual.vias?.deslocamento ?? 0;

bool estacaDaSerieSul(int numero) {
  final inicio = inicioSerieSul;
  return inicio != null && numero >= inicio;
}

// Estaca equivalente na via sul (1115 → 2115).
int gemeaNaSerieSul(int numero) => numero + deslocamentoEntreSeries;

// Estaca equivalente na via norte (2115 → 1115), ou null se já é do norte.
int? gemeaNaSerieNorte(int numero) =>
    estacaDaSerieSul(numero) ? numero - deslocamentoEntreSeries : null;

// Via pela numeração; null em pista simples.
String? viaDaEstaca(int numero, {required bool pistaDupla}) {
  if (!pistaDupla) return null;
  return estacaDaSerieSul(numero) ? viaSul : viaNorte;
}

// KM para exibir: "231", ou "231 a 232" quando o serviço atravessa o KM.
String faixaDeKm(String km, String kmFinal) {
  final fim = kmFinal.trim();
  if (km.trim().isEmpty) return fim;
  return fim.isEmpty || fim == km.trim() ? km : '$km a $fim';
}

// "KM 231 a 232", ou '' em registro sem KM (obra que não usa KM).
String textoDoKm(String km, String kmFinal, {String prefixo = 'KM'}) {
  final faixa = faixaDeKm(km, kmFinal).trim();
  return faixa.isEmpty ? '' : '$prefixo $faixa';
}

// Trechos sem via (pista simples e áreas de apoio): o formulário não
// pergunta. Lista na configuração da obra, porque o dado não distingue (o D2
// tem uma série só e tem via). Nomes normalizados por [chaveDoTrecho].
Set<String> get trechosSemVia =>
    {for (final t in obraAtual.trechosSemVia) chaveDoTrecho(t)};

// Áreas de apoio sem estaqueamento de projeto: o formulário não pede estaca
// (no KMxEst elas só têm a estaca 0, de marcador).
Set<String> get trechosSemEstaca =>
    {for (final t in obraAtual.trechosSemEstaca) chaveDoTrecho(t)};

// Trechos sem KM numa obra que usa KM.
Set<String> get trechosSemKm =>
    {for (final t in obraAtual.trechosSemKm) chaveDoTrecho(t)};

// Nome do trecho comparável: caixa alta, sem acento nem espaço repetido.
String chaveDoTrecho(String trecho) =>
    trecho.toUpperCase().semAcento.replaceAll(RegExp(r'\s+'), ' ').trim();

// Se o trecho pede a via. Trecho não escolhido conta como pedindo; obra sem
// via nunca pede.
bool trechoTemVia(String? trecho) =>
    obraAtual.vias != null &&
    (trecho == null || !trechosSemVia.contains(chaveDoTrecho(trecho)));

// Se o trecho pede estaca. Trecho não escolhido conta como pedindo.
bool trechoTemEstaca(String? trecho) =>
    trecho == null || !trechosSemEstaca.contains(chaveDoTrecho(trecho));

// Se o trecho pede o KM. Obra sem KM nunca pede; trecho não escolhido conta
// como pedindo nas obras com KM.
bool trechoTemKm(String? trecho) =>
    obraAtual.usaKm &&
    (trecho == null || !trechosSemKm.contains(chaveDoTrecho(trecho)));
