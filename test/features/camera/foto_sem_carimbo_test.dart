import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:namer_app/core/utils/arquivos_da_foto.dart';
import 'package:namer_app/features/camera/data/datasources/carimbo_service.dart';

// Pixels quase brancos (texto do carimbo) no quarto inferior direito.
int _pixelsBrancosEmbaixoADireita(img.Image foto) {
  var brancos = 0;
  for (var y = foto.height ~/ 2; y < foto.height; y++) {
    for (var x = foto.width ~/ 2; x < foto.width; x++) {
      final px = foto.getPixel(x, y);
      if (px.r > 200 && px.g > 200 && px.b > 200) brancos++;
    }
  }
  return brancos;
}

void main() {
  late Directory pasta;

  setUp(() => pasta = Directory.systemTemp.createTempSync('foto_sem_carimbo'));
  tearDown(() => pasta.deleteSync(recursive: true));

  test('com destino, a carimbada vai para outro arquivo e a original fica intacta',
      () {
    final lisa = img.Image(width: 640, height: 360);
    img.fill(lisa, color: img.ColorRgb8(90, 120, 90));
    final original = File('${pasta.path}/foto.jpg')
      ..writeAsBytesSync(img.encodeJpg(lisa));
    final bytesDaOriginal = original.readAsBytesSync();
    final destino = '${pasta.path}/carimbada.jpg';

    editarImagemParaTeste(EditarParams(
      original.path,
      File('assets/logo.png').readAsBytesSync(),
      File('assets/fonts/custom_pt_14.zip').readAsBytesSync(),
      -19.9, -40.4,
      'C1', '225', '1115', '1120', 'Via 02 Norte', 'aterro na saia',
      'COMPACTAÇÃO DE ATERRO', '', '24/09/2026 13:10', 14,
      destino: destino,
    ));

    expect(original.readAsBytesSync(), bytesDaOriginal);
    final carimbada = img.decodeJpg(File(destino).readAsBytesSync())!;
    expect([carimbada.width, carimbada.height], [640, 360]);
    expect(_pixelsBrancosEmbaixoADireita(img.decodeJpg(bytesDaOriginal)!), 0);
    expect(_pixelsBrancosEmbaixoADireita(carimbada), greaterThan(0));
  });

  test('a fonte do carimbo acompanha a resolução da foto', () {
    expect(fonteParaFoto([1920, 1080]), 40);
    expect(fonteParaFoto([1080, 1920]), 40);
    expect(fonteParaFoto([1280, 720]), 28);
    expect(fonteParaFoto([640, 360]), 14);
    expect(fonteParaFoto([200, 100]), 10);
    for (final t in tamanhosDaFonte) {
      expect(File('assets/fonts/custom_pt_$t.zip').existsSync(), isTrue,
          reason: 'falta a fonte de $t px');
    }
  });

  test('a hora do carimbo sai no formato de sempre', () {
    expect(dataHoraDoCarimbo(DateTime(2026, 9, 4, 7, 5)), '04/09/2026 07:05');
  });

  test('a original e o minimapa ficam em pastas próprias, com o mesmo nome', () {
    final arquivos = ArquivosDaFoto.dentroDe(pasta.path, 'CAP123.jpg');
    expect(arquivos.carimbada, endsWith('CAP123.jpg'));
    expect(arquivos.original, contains('originais'));
    expect(arquivos.minimapa, endsWith('CAP123.png'));
    expect(Directory('${pasta.path}/originais').existsSync(), isTrue);
    expect(Directory('${pasta.path}/minimapas').existsSync(), isTrue);
  });

  test('foto antiga, sem a original guardada, não tem versão sem carimbo', () {
    final arquivos = ArquivosDaFoto.dentroDe(pasta.path, 'CAP123.jpg');
    File(arquivos.carimbada).writeAsBytesSync([1]);
    expect(originalDaFoto(arquivos.carimbada), isNull);

    File(arquivos.original).writeAsBytesSync([1]);
    expect(originalDaFoto(arquivos.carimbada), arquivos.original);
  });
}
