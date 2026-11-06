import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../paralisacao/domain/entities/paralisacao.dart' show formatarDuracao;
import '../../../relatorio/foto_no_pdf.dart';
import '../../../relatorio/mapa_do_relatorio.dart';
import '../../../relatorio/texto_pdf.dart';
import '../../domain/entities/foto_consolidada.dart';
import '../../domain/entities/resumo_do_encarregado.dart';
import '../../domain/regras/atividades_do_dia.dart';

// Dados de um encarregado para o PDF (montados fora do isolate).
class BlocoEncarregado {
  final String nome;
  final String matricula;
  final List<String> efetivo; // "44 - Motorista Veic. Pesados"
  final int totalPessoas;
  final List<String> atividades;
  final List<FotoConsolidada> fotos;

  // "Manhã: Bom  Tarde: Chuvoso"; vazio quando o RDO não informou.
  final String clima;

  // Uma linha por paralisação (ver descreverParalisacao).
  final List<String> paralisacoes;

  // "2h30"; vazio sem paralisação encerrada.
  final String tempoParado;

  const BlocoEncarregado({
    required this.nome,
    required this.matricula,
    required this.efetivo,
    required this.totalPessoas,
    required this.atividades,
    this.fotos = const [],
    this.clima = '',
    this.paralisacoes = const [],
    this.tempoParado = '',
  });
}

// O bloco de um encarregado. Todo texto passa por textoParaPdf aqui: o que
// foi digitado no celular ou veio do SIMOVA pode ter caractere que a fonte do
// PDF não desenha (no app ele aparece normal).
BlocoEncarregado blocoDoEncarregado(
        ResumoDoEncarregado resumo, List<FotoConsolidada> fotos) =>
    BlocoEncarregado(
      nome: textoParaPdf(resumo.encarregado.nome),
      matricula: textoParaPdf(resumo.encarregado.matricula),
      efetivo: linhasParaPdf([for (final f in resumo.efetivo) f.linha]),
      totalPessoas: resumo.totalPessoas,
      atividades: linhasParaPdf(listarAtividades(resumo.registros)),
      fotos: [
        for (final f in fotos)
          FotoConsolidada(bytes: f.bytes, legenda: textoParaPdf(f.legenda)),
      ],
      clima: textoParaPdf(resumo.clima?.linha ?? ''),
      paralisacoes:
          linhasParaPdf([for (final p in resumo.paralisacoes) p.descricao]),
      tempoParado: resumo.totalParado > Duration.zero
          ? formatarDuracao(resumo.totalParado)
          : '',
    );

// PDF do dia da equipe: um bloco por encarregado (com as [fotos] de cada um,
// na mesma ordem) e o mapa das atividades, nas cores do mapa de avanço.
Future<Uint8List> gerarPdfDaEquipe({
  required List<ResumoDoEncarregado> resumos,
  required List<List<FotoConsolidada>> fotos,
  required String supervisor,
  required DateTime dia,
}) async {
  final mapa = await montarMapaDasAtividades([
    for (final resumo in resumos)
      for (final r in resumo.registros)
        (
          trecho: r.trecho,
          estacaInicial: r.estacaInicial,
          estacaFinal: r.estacaFinal,
          servico: r.servicoNotavel,
        ),
  ]);
  return gerarRelatorioConsolidado(
    blocos: [
      for (var i = 0; i < resumos.length; i++)
        blocoDoEncarregado(resumos[i], i < fotos.length ? fotos[i] : const []),
    ],
    supervisor: textoParaPdf(supervisor),
    dataFormatada: dia.dataCurta,
    mapa: mapa,
  );
}

// Monta o PDF num isolate: com as fotos, ele travaria a tela.
Future<Uint8List> gerarRelatorioConsolidado({
  required List<BlocoEncarregado> blocos,
  required String supervisor,
  required String dataFormatada,
  MapaNoPdf? mapa,
}) async {
  final logo = (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
  return compute(
    _montarEmIsolate,
    _ParametrosPdf(
      blocos: blocos,
      supervisor: supervisor,
      dataFormatada: dataFormatada,
      logoBytes: logo,
      mapa: mapa,
    ),
  );
}

class _ParametrosPdf {
  final List<BlocoEncarregado> blocos;
  final String supervisor;
  final String dataFormatada;
  final Uint8List logoBytes;
  final MapaNoPdf? mapa;

  const _ParametrosPdf({
    required this.blocos,
    required this.supervisor,
    required this.dataFormatada,
    required this.logoBytes,
    this.mapa,
  });
}

Future<Uint8List> _montarEmIsolate(_ParametrosPdf p) => _montar(p);

Future<Uint8List> _montar(_ParametrosPdf p) async {
  final doc = pw.Document();
  final logo = pw.MemoryImage(p.logoBytes);

  const margem = pw.EdgeInsets.all(12);
  final larguraConteudo = PdfPageFormat.a4.width - margem.left - margem.right;
  const espacamento = 12.0;
  final larguraFoto = (larguraConteudo - espacamento) / 2 - 1;

  final totalPessoas =
      p.blocos.fold<int>(0, (soma, b) => soma + b.totalPessoas);
  final comApontamento = p.blocos.where((b) => b.atividades.isNotEmpty).length;
  final comParalisacao = p.blocos.where((b) => b.paralisacoes.isNotEmpty).length;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: margem,
      // O padrão (20, só em debug) é pouco para as fotos de um encarregado.
      maxPages: 1000,
      header: (ctx) => ctx.pageNumber == 1
          ? pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: _cabecalho(logo, p.supervisor, p.dataFormatada),
            )
          : pw.SizedBox(),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9)),
      ),
      build: (ctx) => [
        _resumoGeral(p.blocos.length, comApontamento, totalPessoas, comParalisacao),
        pw.SizedBox(height: 14),
        if (p.mapa != null) ...[
          mapaNoPdf(p.mapa!,
              titulo: _barraTitulo('Mapa das atividades da equipe'),
              largura: larguraConteudo),
          pw.SizedBox(height: 18),
        ],
        for (final bloco in p.blocos) ...[
          _blocoDoEncarregado(bloco),
          if (bloco.fotos.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _fotosDoEncarregado(bloco.fotos, larguraFoto, espacamento),
          ],
          pw.SizedBox(height: 18),
        ],
      ],
    ),
  );

  return doc.save();
}

pw.Widget _resumoGeral(
    int encarregados, int comApontamento, int pessoas, int comParalisacao) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
    padding: const pw.EdgeInsets.all(10),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _numero('$encarregados', 'encarregados'),
        _numero('$comApontamento', 'com atividade'),
        _numero('$pessoas', 'pessoas no efetivo'),
        if (comParalisacao > 0) _numero('$comParalisacao', 'com paralisação'),
      ],
    ),
  );
}

pw.Widget _numero(String valor, String rotulo) => pw.Column(
      children: [
        pw.Text(valor,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(rotulo, style: const pw.TextStyle(fontSize: 10)),
      ],
    );

// Nome, efetivo e atividades. As fotos vêm em [_fotosDoEncarregado].
pw.Widget _blocoDoEncarregado(BlocoEncarregado bloco) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _barraTitulo('${bloco.nome}${bloco.matricula.isNotEmpty ? '  ·  '
          'Matrícula ${bloco.matricula}' : ''}'),
      if (bloco.clima.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Text('Clima: ${bloco.clima}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _lista(
                'Efetivo (${bloco.totalPessoas})',
                bloco.efetivo,
                vazio: 'Sem apontamento de efetivo',
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 2,
              child: _lista(
                'Atividades',
                bloco.atividades,
                vazio: 'Nenhuma atividade registrada no app',
              ),
            ),
          ],
        ),
      ),
      if (bloco.paralisacoes.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: _lista(
            bloco.tempoParado.isEmpty
                ? 'Paralisações'
                : 'Paralisações (${bloco.tempoParado} parado)',
            bloco.paralisacoes,
            vazio: '',
          ),
        ),
    ],
  );
}

// Fotos do encarregado, 2 por linha. Fica solto no MultiPage, nunca dentro de
// uma Column: a Column não consegue quebrar um filho maior que a página.
pw.Widget _fotosDoEncarregado(
    List<FotoConsolidada> fotos, double larguraFoto, double espacamento) {
  return pw.Wrap(
    spacing: espacamento,
    runSpacing: 10,
    children: [for (final foto in fotos) _foto(foto, larguraFoto)],
  );
}

pw.Widget _lista(String titulo, List<String> itens, {required String vazio}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(titulo,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      if (itens.isEmpty)
        pw.Text(vazio,
            style: pw.TextStyle(
                fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))
      else
        for (final item in itens)
          pw.Text('-  $item', style: const pw.TextStyle(fontSize: 10)),
    ],
  );
}

pw.Widget _foto(FotoConsolidada foto, double largura) {
  // Caixa na proporção da foto, para não cortar o carimbo (foto_no_pdf.dart).
  final imagem = pw.MemoryImage(foto.bytes);
  return pw.Container(
    width: largura,
    child: pw.Column(
      children: [
        pw.Image(imagem,
            width: largura,
            height: alturaDaFotoNoPdf(imagem, largura),
            fit: pw.BoxFit.contain),
        pw.SizedBox(height: 3),
        pw.Text(foto.legenda,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
}

pw.Widget _barraTitulo(String texto) => pw.Container(
      color: PdfColors.black,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(texto,
          style: pw.TextStyle(
              color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _cabecalho(pw.MemoryImage logo, String supervisor, String data) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Row(
            children: [
              pw.Container(
                color: PdfColors.black,
                padding: const pw.EdgeInsets.all(6),
                child: pw.Image(logo, height: 30),
              ),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text('Relatório Consolidado da Equipe',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ),
              ),
              pw.SizedBox(width: 54),
            ],
          ),
        ),
        pw.Container(
          decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.black))),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const pw.BoxDecoration(
                    border:
                        pw.Border(right: pw.BorderSide(color: PdfColors.black)),
                  ),
                  child: pw.Text('Usuario: $supervisor',
                      style: const pw.TextStyle(fontSize: 11)),
                ),
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child:
                    pw.Text('Data: $data', style: const pw.TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
