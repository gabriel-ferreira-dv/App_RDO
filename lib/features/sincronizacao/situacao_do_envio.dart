import 'sincronizacao_service.dart';
import '../../core/extensions/data_hora_extensions.dart';
import '../../core/extensions/texto_extensions.dart';

// Como o envio está, em palavras, para o cartão do Início.
enum TipoDaSituacao { contando, enviando, tudoEnviado, aguardando, recusado }

class SituacaoDoEnvio {
  final TipoDaSituacao tipo;
  final String titulo;
  final String detalhe;

  const SituacaoDoEnvio(this.tipo, this.titulo, this.detalhe);
}

SituacaoDoEnvio descreverEnvio(EstadoDoEnvio estado, DateTime agora) {
  final p = estado.pendentes;
  if (p == null) {
    return const SituacaoDoEnvio(TipoDaSituacao.contando, 'Conferindo o envio',
        'Contando o que falta subir');
  }
  final fila = oQueFaltaEnviar(p);

  if (estado.enviando) {
    return SituacaoDoEnvio(TipoDaSituacao.enviando, 'Enviando para o servidor',
        fila.isEmpty ? 'Conferindo novidades' : '$fila na fila');
  }
  if (fila.isEmpty) {
    final quando = estado.ultimaRodadaCompleta;
    return SituacaoDoEnvio(
      TipoDaSituacao.tudoEnviado,
      'Tudo enviado',
      quando == null
          ? 'Nada esperando no aparelho'
          : 'Último envio ${quandoFoi(quando, agora)}',
    );
  }
  // O servidor recusou algo: não é questão de esperar o sinal.
  if (estado.ultimoErro != null && !estado.erroDeRede) {
    return SituacaoDoEnvio(
        TipoDaSituacao.recusado, '$fila sem enviar', estado.ultimoErro!);
  }
  return SituacaoDoEnvio(
    TipoDaSituacao.aguardando,
    '$fila aguardando sinal',
    'Sobem sozinhos quando houver internet',
  );
}

// "3 fotos e 1 registro"; vazio quando não há nada.
String oQueFaltaEnviar(({int registros, int fotos, int paralisacoes}) p) {
  final partes = [
    if (p.fotos > 0) plural(p.fotos, 'foto', 'fotos'),
    if (p.registros > 0) plural(p.registros, 'registro', 'registros'),
    if (p.paralisacoes > 0) plural(p.paralisacoes, 'parada', 'paradas'),
  ];
  if (partes.length <= 1) return partes.join();
  return '${partes.sublist(0, partes.length - 1).join(', ')} e ${partes.last}';
}

String plural(int n, String singular, String varios) =>
    n.plural(singular, varios);

// "hoje às 07:42", "ontem às 18:10" ou "12/10 às 07:42".
String quandoFoi(DateTime momento, DateTime agora) {
  final hora = momento.horaCurta;
  final dia = DateTime(momento.year, momento.month, momento.day);
  final hoje = DateTime(agora.year, agora.month, agora.day);
  if (dia == hoje) return 'hoje às $hora';
  final ontem = DateTime(hoje.year, hoje.month, hoje.day - 1);
  if (dia == ontem) return 'ontem às $hora';
  return '${momento.diaEMes} às $hora';
}
