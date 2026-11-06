import 'paralisacao.dart';

// As paralisações de um dia de trabalho, com quantas fotos cada uma tem.
class ResumoDasParalisacoes {
  final List<Paralisacao> lista;
  final Map<int, int> _fotos;

  const ResumoDasParalisacoes(this.lista, [this._fotos = const {}]);

  static const nenhuma = ResumoDasParalisacoes([]);

  bool get semParalisacoes => lista.isEmpty;

  List<Paralisacao> get emAndamento => [
        for (final p in lista)
          if (p.emAndamento) p
      ];

  List<Paralisacao> get encerradas => [
        for (final p in lista)
          if (!p.emAndamento) p
      ];

  // Soma só as encerradas.
  Duration get totalParado => _somar(lista);

  int fotosDe(Paralisacao p) => _fotos[p.id] ?? 0;
}

Duration _somar(List<Paralisacao> lista) =>
    tempoParado([for (final p in lista) (inicio: p.inicio, fim: p.fim)]);
