import '../entities/campos_do_registro.dart';
import '../entities/estaca_do_projeto.dart';
import 'vias_estaqueamento.dart';

const List<String> unidadesDeMedicao = ['m³', 'm²', 'm', 'un', 'kg', 't', 'vb'];

// Valida o que foi escolhido na correção e monta os campos corrigidos, com as
// mesmas regras do formulário de registro. Devolve o erro para mostrar, ou os
// campos.
({CamposDoRegistro? campos, String? erro}) montarCamposCorrigidos({
  required String? trecho,
  required String? km,
  required String? via,
  required EstacaDoProjeto? estacaInicial,
  required EstacaDoProjeto? estacaFinal,
  required String? atividade,
  required String? servico,
  required String? passo,
  required bool pedePasso,
  required String textoQuantidade,
  required String? unidade,
  required String descricao,
}) {
  ({CamposDoRegistro? campos, String? erro}) erro(String texto) =>
      (campos: null, erro: texto);

  if (trecho == null) return erro('Selecione o trecho');
  final pedeKm = trechoTemKm(trecho);
  if (pedeKm && km == null) return erro('Selecione o KM');
  final pedeVia = trechoTemVia(trecho);
  final pedeEstaca = trechoTemEstaca(trecho);
  if (pedeVia && via == null) return erro('Selecione o sentido da via');
  if (pedeEstaca && (estacaInicial == null || estacaFinal == null)) {
    return erro('Selecione a estaca inicial e final');
  }
  if (atividade == null) return erro('Selecione a atividade');
  if (servico == null) return erro('Selecione o serviço');
  if (pedePasso && passo == null) return erro('Selecione o passo do serviço');

  final texto = textoQuantidade.trim().replaceAll(',', '.');
  final quantidade = texto.isEmpty ? null : double.tryParse(texto);
  if (texto.isNotEmpty && quantidade == null) {
    return erro('Quantidade inválida — use só números (ex.: 120,5)');
  }
  if (quantidade != null && unidade == null) {
    return erro('Escolha a unidade da quantidade');
  }
  if (quantidade == null && unidade != null) {
    return erro('Informe a quantidade da medição');
  }

  // O KM de cada ponta sai da estaca escolhida; sem KM, fica em branco.
  final kmInicio = pedeKm ? (pedeEstaca ? estacaInicial?.km : null) ?? km! : '';
  final kmFim = pedeKm ? (pedeEstaca ? estacaFinal?.km : null) ?? kmInicio : '';
  return (
    campos: CamposDoRegistro(
      trecho: trecho,
      km: kmInicio,
      kmFinal: kmFim == kmInicio ? '' : kmFim,
      via: pedeVia ? via! : '',
      atividade: atividade,
      estacaInicial: pedeEstaca ? estacaInicial!.rotulo : '',
      estacaFinal: pedeEstaca ? estacaFinal!.rotulo : '',
      servicoNotavel: servico,
      servicoNotavelDetalhe: passo ?? '',
      quantidade: quantidade,
      unidade: unidade ?? '',
      descricao: descricao.trim(),
    ),
    erro: null,
  );
}
