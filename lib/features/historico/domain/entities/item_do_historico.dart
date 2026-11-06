import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../registro/domain/regras/local_e_hora.dart';
import '../../../registro/domain/entities/grupo_atividade.dart';
import '../../../registro/domain/regras/textos_do_registro.dart';

enum PeriodoDoHistorico {
  hoje('Hoje', 'Nenhum registro hoje'),
  ontem('Ontem', 'Nenhum registro ontem'),
  semana('7 dias', 'Nenhum registro nos últimos 7 dias'),
  tudo('Tudo', 'Nenhum registro ainda');

  const PeriodoDoHistorico(this.rotulo, this.semRegistros);
  final String rotulo;
  final String semRegistros;

  // Mais de um dia na tela: cada dia ganha um cabeçalho.
  bool get variosDias => this == semana || this == tudo;
}

enum SituacaoDoRegistro { enviado, aguardando, corrigido }

class ItemDoHistorico {
  final GrupoAtividade grupo;
  final RegistroAgrupado registro;
  final DateTime momento;

  const ItemDoHistorico(this.grupo, this.registro, this.momento);

  DateTime get dia => momento.soDia;

  SituacaoDoRegistro get situacao {
    if (registro.aguardandoEnvio) return SituacaoDoRegistro.aguardando;
    if (registro.corrigido) return SituacaoDoRegistro.corrigido;
    return SituacaoDoRegistro.enviado;
  }

  String get localEHora => localEHoraDoRegistro(
        trecho: grupo.trecho,
        estacaInicial: registro.estacaInicial,
        estacaFinal: registro.estacaFinal,
        km: grupo.km,
        momento: momento,
      );

  String get detalhes => [
        if (grupo.servicoNotavelDetalhe.isNotEmpty) grupo.servicoNotavelDetalhe,
        if (registro.via.trim().isNotEmpty) registro.via,
        if (textoDaMedicao(registro.quantidade, registro.unidade)
            case final medicao when medicao.isNotEmpty)
          medicao,
        if (registro.emNomeDeNome.isNotEmpty)
          'em nome de ${registro.emNomeDeNome}'
        else if (registro.registradoPorNome.isNotEmpty)
          'lançado por ${registro.registradoPorNome}',
      ].join(' · ');
}

// Registros do [periodo], do mais recente para o mais antigo.
List<ItemDoHistorico> itensDoPeriodo(
  List<GrupoAtividade> grupos,
  PeriodoDoHistorico periodo,
  DateTime agora,
) {
  final hoje = agora.soDia;
  final ontem = DateTime(hoje.year, hoje.month, hoje.day - 1);
  final inicioDaSemana = DateTime(hoje.year, hoje.month, hoje.day - 6);

  bool entra(DateTime dia) => switch (periodo) {
        PeriodoDoHistorico.hoje => dia == hoje,
        PeriodoDoHistorico.ontem => dia == ontem,
        PeriodoDoHistorico.semana => !dia.isBefore(inicioDaSemana),
        PeriodoDoHistorico.tudo => true,
      };

  final itens = <ItemDoHistorico>[
    for (final grupo in grupos)
      for (final registro in grupo.registros)
        if (DateTime.tryParse(registro.criadoEm)?.toLocal() case final momento?)
          if (entra(momento.soDia)) ItemDoHistorico(grupo, registro, momento),
  ];
  itens.sort((a, b) => b.momento.compareTo(a.momento));
  return itens;
}

// Cabeçalho do dia: "Hoje", "Ontem" ou "sex., 10/07".
String rotuloDoDia(DateTime dia, DateTime agora) {
  final hoje = agora.soDia;
  if (dia == hoje) return 'Hoje';
  if (dia == DateTime(hoje.year, hoje.month, hoje.day - 1)) return 'Ontem';
  const semana = ['seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.', 'dom.'];
  return '${semana[dia.weekday - 1]}, ${dia.diaEMes}';
}
