import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// Cópia da senha guardada no celular para o login sem internet.
//
// Formato: "pbkdf2_sha256$<rodadas>$<sal>$<resultado>", com sal e resultado
// em base64. O sal é aleatório para cada cópia; as rodadas deixam cada
// tentativa de adivinhar a senha lenta para quem copiar o banco do celular.
//
// A entrada do PBKDF2 é o SHA-256 da senha (em hexadecimal), que era a cópia
// do formato antigo. Assim uma cópia antiga vira o formato novo sem a senha
// (ver [atualizarCopiaAntiga]), e ninguém precisa digitar a senha de novo.

// Rodadas das cópias novas. Subir este número faz as cópias antigas serem
// refeitas no próximo login sem internet (ver [copiaPrecisaRefazer]).
const rodadasDaSenha = 120000;

const _prefixo = 'pbkdf2_sha256';
const _bytesDoSal = 16;
final _copiaAntiga = RegExp(r'^[0-9a-f]{64}$');

// Cópia nova da [senha]; [sal] e [rodadas] só mudam nos testes.
String copiaDaSenha(String senha,
        {int rodadas = rodadasDaSenha, List<int>? sal}) =>
    _proteger(_sha256Hex(senha), rodadas, sal ?? _salNovo());

// A [senha] digitada bate com a [copia] guardada (formato novo ou antigo)?
bool senhaConfere(String senha, String copia) {
  if (_copiaAntiga.hasMatch(copia)) {
    return _iguais(utf8.encode(_sha256Hex(senha)), utf8.encode(copia));
  }
  final partes = copia.split(r'$');
  if (partes.length != 4 || partes[0] != _prefixo) return false;
  final rodadas = int.tryParse(partes[1]);
  if (rodadas == null || rodadas < 1) return false;
  try {
    final sal = base64.decode(partes[2]);
    final esperado = base64.decode(partes[3]);
    if (esperado.isEmpty) return false;
    final calculado = pbkdf2Sha256(
        utf8.encode(_sha256Hex(senha)), sal, rodadas, esperado.length);
    return _iguais(calculado, esperado);
  } on FormatException {
    return false;
  }
}

// A cópia é do formato antigo, ou tem menos rodadas que as atuais: refazer
// quando a senha for digitada.
bool copiaPrecisaRefazer(String copia) {
  if (_copiaAntiga.hasMatch(copia)) return true;
  final partes = copia.split(r'$');
  final rodadas = partes.length == 4 ? int.tryParse(partes[1]) : null;
  return rodadas == null || rodadas < rodadasDaSenha;
}

// Cópia antiga (SHA-256 puro) no formato novo, sem precisar da senha; null se
// a [copia] não é do formato antigo.
String? atualizarCopiaAntiga(String copia) => _copiaAntiga.hasMatch(copia)
    ? _proteger(copia, rodadasDaSenha, _salNovo())
    : null;

// As mesmas contas, fora da linha da tela: cada uma leva uns décimos de
// segundo de propósito, e a tela não pode travar enquanto isso.
Future<String> copiaDaSenhaEmSegundoPlano(String senha) =>
    Isolate.run(() => copiaDaSenha(senha));

Future<bool> senhaConfereEmSegundoPlano(String senha, String copia) =>
    Isolate.run(() => senhaConfere(senha, copia));

// Cópia que já é nova volta null na hora, sem abrir o segundo plano.
Future<String?> atualizarCopiaAntigaEmSegundoPlano(String copia) async =>
    _copiaAntiga.hasMatch(copia)
        ? Isolate.run(() => atualizarCopiaAntiga(copia))
        : null;

// ── Contas ───────────────────────────────────────────────────────────────────

String _proteger(String sha256Hex, int rodadas, List<int> sal) {
  final resultado = pbkdf2Sha256(utf8.encode(sha256Hex), sal, rodadas, 32);
  return '$_prefixo\$$rodadas\$${base64.encode(sal)}\$${base64.encode(resultado)}';
}

String _sha256Hex(String senha) =>
    sha256.convert(utf8.encode(senha)).toString();

List<int> _salNovo() {
  final aleatorio = Random.secure();
  return List<int>.generate(_bytesDoSal, (_) => aleatorio.nextInt(256));
}

// Compara sem parar no primeiro byte diferente (o tempo não entrega quantos
// bytes bateram).
bool _iguais(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diferenca = 0;
  for (var i = 0; i < a.length; i++) {
    diferenca |= a[i] ^ b[i];
  }
  return diferenca == 0;
}

// PBKDF2 com HMAC-SHA256 (RFC 8018, seção 5.2).
Uint8List pbkdf2Sha256(
    List<int> senha, List<int> sal, int rodadas, int tamanho) {
  final hmac = Hmac(sha256, senha);
  final saida = Uint8List(tamanho);
  var feito = 0;
  for (var bloco = 1; feito < tamanho; bloco++) {
    var u = hmac.convert([
      ...sal,
      (bloco >> 24) & 0xff,
      (bloco >> 16) & 0xff,
      (bloco >> 8) & 0xff,
      bloco & 0xff,
    ]).bytes;
    final t = Uint8List.fromList(u);
    for (var r = 1; r < rodadas; r++) {
      u = hmac.convert(u).bytes;
      for (var i = 0; i < t.length; i++) {
        t[i] ^= u[i];
      }
    }
    final parte = min(t.length, tamanho - feito);
    saida.setRange(feito, feito + parte, t);
    feito += parte;
  }
  return saida;
}
