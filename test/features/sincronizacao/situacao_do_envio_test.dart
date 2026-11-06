import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/sincronizacao/sincronizacao_service.dart';
import 'package:namer_app/features/sincronizacao/situacao_do_envio.dart';

final _agora = DateTime(2026, 10, 15, 9);

EstadoDoEnvio _estado({
  int registros = 0,
  int fotos = 0,
  int paralisacoes = 0,
  bool enviando = false,
  String? erro,
  bool erroDeRede = false,
  DateTime? ultimaRodada,
}) =>
    EstadoDoEnvio(
      enviando: enviando,
      pendentes: (
        registros: registros,
        fotos: fotos,
        paralisacoes: paralisacoes
      ),
      ultimoErro: erro,
      quandoErro: erro == null ? null : _agora,
      erroDeRede: erroDeRede,
      ultimaRodadaCompleta: ultimaRodada,
    );

void main() {
  test('nada na fila: tudo enviado, com a hora do último envio', () {
    final s = descreverEnvio(
        _estado(ultimaRodada: DateTime(2026, 10, 15, 7, 42)), _agora);
    expect(s.tipo, TipoDaSituacao.tudoEnviado);
    expect(s.titulo, 'Tudo enviado');
    expect(s.detalhe, 'Último envio hoje às 07:42');
  });

  test('sem sinal: o que está na fila, aguardando', () {
    final s = descreverEnvio(
      _estado(fotos: 3, registros: 1, erro: 'Sem conexão', erroDeRede: true),
      _agora,
    );
    expect(s.tipo, TipoDaSituacao.aguardando);
    expect(s.titulo, '3 fotos e 1 registro aguardando sinal');
  });

  test('servidor recusou: mostra o motivo, e não "aguardando sinal"', () {
    final s = descreverEnvio(
      _estado(fotos: 1, erro: '1 item(ns) recusado(s) pelo servidor: X'),
      _agora,
    );
    expect(s.tipo, TipoDaSituacao.recusado);
    expect(s.titulo, '1 foto sem enviar');
    expect(s.detalhe, contains('recusado'));
  });

  test('enviando e antes da primeira contagem', () {
    expect(descreverEnvio(_estado(fotos: 2, enviando: true), _agora).tipo,
        TipoDaSituacao.enviando);
    expect(descreverEnvio(const EstadoDoEnvio(), _agora).tipo,
        TipoDaSituacao.contando);
  });

  test('a fila em palavras', () {
    expect(oQueFaltaEnviar((registros: 0, fotos: 0, paralisacoes: 0)), '');
    expect(oQueFaltaEnviar((registros: 2, fotos: 0, paralisacoes: 0)),
        '2 registros');
    expect(oQueFaltaEnviar((registros: 1, fotos: 4, paralisacoes: 1)),
        '4 fotos, 1 registro e 1 parada');
  });

  test('quando foi: hoje, ontem ou a data', () {
    expect(quandoFoi(DateTime(2026, 10, 15, 7, 5), _agora), 'hoje às 07:05');
    expect(quandoFoi(DateTime(2026, 10, 14, 18, 10), _agora), 'ontem às 18:10');
    expect(quandoFoi(DateTime(2026, 10, 2, 8), _agora), '02/10 às 08:00');
  });
}
