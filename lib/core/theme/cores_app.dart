import 'package:flutter/material.dart';

const Color grafite = Color(0xFF1F2933);

const Color amareloObra = Color(0xFFF5B301);

@immutable
class CoresDaObra extends ThemeExtension<CoresDaObra> {
  const CoresDaObra({
    required this.destaque,
    required this.naDestaque,
    required this.cabecalho,
    required this.noCabecalho,
    required this.noCabecalhoSuave,
    required this.enviado,
    required this.fundoEnviado,
    required this.pendente,
    required this.fundoPendente,
    required this.parada,
    required this.fundoParada,
    required this.neutro,
    required this.fundoNeutro,
  });

  // Ação principal (Novo registro, Tirar fotos) e o texto sobre ela. O
  // amarelo é o mesmo nos dois modos; no escuro o texto é branco.
  final Color destaque;
  final Color naDestaque;

  // Barra do topo e blocos escuros (resumo do local) e o texto sobre eles.
  final Color cabecalho;
  final Color noCabecalho;
  final Color noCabecalhoSuave;

  // Já está no servidor.
  final Color enviado;
  final Color fundoEnviado;

  // Esperando sinal para subir.
  final Color pendente;
  final Color fundoPendente;

  // Serviço parado e falhas.
  final Color parada;
  final Color fundoParada;

  // Informação sem urgência (registro corrigido, botões secundários).
  final Color neutro;
  final Color fundoNeutro;

  static const claro = CoresDaObra(
    destaque: amareloObra,
    naDestaque: grafite,
    cabecalho: grafite,
    noCabecalho: Colors.white,
    noCabecalhoSuave: Color(0xFFAEB7C0),
    enviado: Color(0xFF14653F),
    fundoEnviado: Color(0xFFE3F4EA),
    pendente: Color(0xFF8A4A12),
    fundoPendente: Color(0xFFFDEEDC),
    parada: Color(0xFFA52A21),
    fundoParada: Color(0xFFFBE7E5),
    neutro: grafite,
    fundoNeutro: Color(0xFFE7EBEF),
  );

  static const escuro = CoresDaObra(
    destaque: Color.fromARGB(255, 216, 159, 0),
    naDestaque: Colors.white,
    cabecalho: Color(0xFF1A222A),
    noCabecalho: Colors.white,
    noCabecalhoSuave: Color(0xFF9AA5B0),
    enviado: Color(0xFF8FD9B0),
    fundoEnviado: Color(0xFF123D2A),
    pendente: Color(0xFFF2B880),
    fundoPendente: Color(0xFF4A2C0E),
    parada: Color(0xFFF4A79F),
    fundoParada: Color(0xFF4D1A16),
    neutro: Color(0xFFC9D3DC),
    fundoNeutro: Color(0xFF2A343E),
  );

  static CoresDaObra de(BuildContext context) =>
      Theme.of(context).extension<CoresDaObra>() ??
      (Theme.of(context).brightness == Brightness.dark ? escuro : claro);

  @override
  CoresDaObra copyWith({
    Color? destaque,
    Color? naDestaque,
    Color? cabecalho,
    Color? noCabecalho,
    Color? noCabecalhoSuave,
    Color? enviado,
    Color? fundoEnviado,
    Color? pendente,
    Color? fundoPendente,
    Color? parada,
    Color? fundoParada,
    Color? neutro,
    Color? fundoNeutro,
  }) =>
      CoresDaObra(
        destaque: destaque ?? this.destaque,
        naDestaque: naDestaque ?? this.naDestaque,
        cabecalho: cabecalho ?? this.cabecalho,
        noCabecalho: noCabecalho ?? this.noCabecalho,
        noCabecalhoSuave: noCabecalhoSuave ?? this.noCabecalhoSuave,
        enviado: enviado ?? this.enviado,
        fundoEnviado: fundoEnviado ?? this.fundoEnviado,
        pendente: pendente ?? this.pendente,
        fundoPendente: fundoPendente ?? this.fundoPendente,
        parada: parada ?? this.parada,
        fundoParada: fundoParada ?? this.fundoParada,
        neutro: neutro ?? this.neutro,
        fundoNeutro: fundoNeutro ?? this.fundoNeutro,
      );

  @override
  CoresDaObra lerp(CoresDaObra? other, double t) {
    if (other == null) return this;
    Color misturar(Color a, Color b) => Color.lerp(a, b, t)!;
    return CoresDaObra(
      destaque: misturar(destaque, other.destaque),
      naDestaque: misturar(naDestaque, other.naDestaque),
      cabecalho: misturar(cabecalho, other.cabecalho),
      noCabecalho: misturar(noCabecalho, other.noCabecalho),
      noCabecalhoSuave: misturar(noCabecalhoSuave, other.noCabecalhoSuave),
      enviado: misturar(enviado, other.enviado),
      fundoEnviado: misturar(fundoEnviado, other.fundoEnviado),
      pendente: misturar(pendente, other.pendente),
      fundoPendente: misturar(fundoPendente, other.fundoPendente),
      parada: misturar(parada, other.parada),
      fundoParada: misturar(fundoParada, other.fundoParada),
      neutro: misturar(neutro, other.neutro),
      fundoNeutro: misturar(fundoNeutro, other.fundoNeutro),
    );
  }
}
