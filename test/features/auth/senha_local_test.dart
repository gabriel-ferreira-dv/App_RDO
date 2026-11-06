import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/auth/senha_local.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// Cópia do formato antigo: SHA-256 puro da senha.
String _copiaAntiga(String senha) =>
    sha256.convert(utf8.encode(senha)).toString();

void main() {
  group('PBKDF2-SHA256', () {
    // Valores oficiais (RFC 7914, seção 11), conferidos com o hashlib do Python.
    test('1 rodada', () {
      expect(
        _hex(pbkdf2Sha256(utf8.encode('passwd'), utf8.encode('salt'), 1, 64)),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    test('80 mil rodadas', () {
      expect(
        _hex(pbkdf2Sha256(
            utf8.encode('Password'), utf8.encode('NaCl'), 80000, 64)),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
        'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
      );
    });
  });

  group('Cópia da senha', () {
    test('formato igual ao calculado pelo Python', () {
      expect(
        copiaDaSenha('Obra@2026',
            rodadas: 1000, sal: List<int>.generate(16, (i) => i)),
        r'pbkdf2_sha256$1000$AAECAwQFBgcICQoLDA0ODw==$'
        'zDhSIdbllhDhmYhRqP4YuzdNQReCApd8VtygRPENMCk=',
      );
    });

    test('confere a senha certa e recusa a errada', () {
      final copia = copiaDaSenha('Obra@2026', rodadas: 1000);
      expect(senhaConfere('Obra@2026', copia), isTrue);
      expect(senhaConfere('obra@2026', copia), isFalse);
      expect(senhaConfere('', copia), isFalse);
    });

    test('cada cópia tem o seu sal: a mesma senha não gera a mesma cópia', () {
      final a = copiaDaSenha('123456', rodadas: 1000);
      final b = copiaDaSenha('123456', rodadas: 1000);
      expect(a, isNot(b));
      expect(senhaConfere('123456', a), isTrue);
      expect(senhaConfere('123456', b), isTrue);
    });

    test('a cópia nova usa as rodadas atuais e não precisa refazer', () {
      final copia = copiaDaSenha('Obra@2026');
      expect(copia, startsWith('pbkdf2_sha256\$$rodadasDaSenha\$'));
      expect(copia, isNot(contains(_copiaAntiga('Obra@2026'))));
      expect(copiaPrecisaRefazer(copia), isFalse);
    });

    test('cópia estragada nunca confere', () {
      for (final copia in [
        '',
        'abc',
        r'pbkdf2_sha256$0$AAAA$AAAA',
        r'pbkdf2_sha256$1000$%%%$AAAA',
        r'pbkdf2_sha256$1000$AAAA$',
        r'md5$1000$AAAA$AAAA',
      ]) {
        expect(senhaConfere('Obra@2026', copia), isFalse, reason: copia);
      }
    });
  });

  group('Cópias antigas (SHA-256 sem sal)', () {
    final antiga = _copiaAntiga('Obra@2026');

    test('ainda conferem e pedem para refazer', () {
      expect(senhaConfere('Obra@2026', antiga), isTrue);
      expect(senhaConfere('errada', antiga), isFalse);
      expect(copiaPrecisaRefazer(antiga), isTrue);
    });

    test('viram o formato novo sem a senha, e a senha continua valendo', () {
      final nova = atualizarCopiaAntiga(antiga)!;
      expect(nova, startsWith('pbkdf2_sha256\$$rodadasDaSenha\$'));
      expect(nova, isNot(contains(antiga)));
      expect(senhaConfere('Obra@2026', nova), isTrue);
      expect(senhaConfere('errada', nova), isFalse);
      expect(copiaPrecisaRefazer(nova), isFalse);
    });

    test('cópia que já é nova não é mexida', () {
      expect(atualizarCopiaAntiga(copiaDaSenha('x', rodadas: 1000)), isNull);
    });

    test('cópia com menos rodadas que as atuais pede para refazer', () {
      expect(copiaPrecisaRefazer(copiaDaSenha('x', rodadas: 1000)), isTrue);
    });
  });

  test('as versões em segundo plano dão o mesmo resultado', () async {
    final copia = await copiaDaSenhaEmSegundoPlano('Obra@2026');
    expect(await senhaConfereEmSegundoPlano('Obra@2026', copia), isTrue);
    expect(await senhaConfereEmSegundoPlano('errada', copia), isFalse);
    final nova =
        await atualizarCopiaAntigaEmSegundoPlano(_copiaAntiga('Obra@2026'));
    expect(senhaConfere('Obra@2026', nova!), isTrue);
  });
}
