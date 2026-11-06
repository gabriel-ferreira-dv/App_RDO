import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/historico/domain/entities/item_do_historico.dart';

import 'fakes.dart';

void main() {
  final hoje = registro(1, DateTime(2026, 7, 15, 7, 31));
  final ontem = registro(2, DateTime(2026, 7, 14, 9, 12));
  final semana = registro(3, DateTime(2026, 7, 10, 16));
  final antigo = registro(4, DateTime(2026, 6, 1, 8));
  final grupos = [
    grupo([antigo, hoje]),
    grupo([semana, ontem]),
  ];

  List<int> ids(PeriodoDoHistorico periodo) => [
        for (final item in itensDoPeriodo(grupos, periodo, agoraDeTeste))
          item.registro.registroId,
      ];

  test('cada período pega os seus dias, do mais recente para o mais antigo',
      () {
    expect(ids(PeriodoDoHistorico.hoje), [1]);
    expect(ids(PeriodoDoHistorico.ontem), [2]);
    expect(ids(PeriodoDoHistorico.semana), [1, 2, 3]);
    expect(ids(PeriodoDoHistorico.tudo), [1, 2, 3, 4]);
  });

  test('registro ou foto ainda no aparelho fica "aguardando"', () {
    final itens = itensDoPeriodo([
      grupo([
        registro(1, agoraDeTeste),
        registro(2, agoraDeTeste, registroPendente: true),
        registro(3, agoraDeTeste, fotos: [foto(30), foto(31, pendente: true)]),
        registro(4, agoraDeTeste, corrigido: true),
        registro(5, agoraDeTeste, corrigido: true, registroPendente: true),
      ]),
    ], PeriodoDoHistorico.hoje, agoraDeTeste);
    final porId = {for (final i in itens) i.registro.registroId: i.situacao};
    expect(porId, {
      1: SituacaoDoRegistro.enviado,
      2: SituacaoDoRegistro.aguardando,
      3: SituacaoDoRegistro.aguardando,
      4: SituacaoDoRegistro.corrigido,
      // A correção ainda não subiu: o que importa é que falta enviar.
      5: SituacaoDoRegistro.aguardando,
    });
  });

  test('a linha de local e hora mostra a faixa de estacas ou o KM', () {
    final item =
        itensDoPeriodo(grupos, PeriodoDoHistorico.hoje, agoraDeTeste).single;
    expect(item.localEHora, 'C1 · est. 1115 – 1120 · 07:31');
    expect(item.detalhes, 'Aterro na saia · Via 02 Norte');

    final semEstaca = itensDoPeriodo([
      grupo([
        registro(9, DateTime(2026, 7, 15, 10, 5),
            estacaInicial: '', estacaFinal: '')
      ]),
    ], PeriodoDoHistorico.hoje, agoraDeTeste)
        .single;
    expect(semEstaca.localEHora, 'C1 · km 225 · 10:05');
  });

  test('cabeçalho do dia: hoje, ontem ou dia da semana com a data', () {
    expect(rotuloDoDia(DateTime(2026, 7, 15), agoraDeTeste), 'Hoje');
    expect(rotuloDoDia(DateTime(2026, 7, 14), agoraDeTeste), 'Ontem');
    expect(rotuloDoDia(DateTime(2026, 7, 10), agoraDeTeste), 'sex., 10/07');
  });

  test('os períodos de vários dias ganham cabeçalho; cada um tem o seu vazio',
      () {
    expect([for (final p in PeriodoDoHistorico.values) p.variosDias],
        [false, false, true, true]);
    expect(PeriodoDoHistorico.semana.semRegistros,
        'Nenhum registro nos últimos 7 dias');
  });
}
