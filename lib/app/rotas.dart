import 'package:flutter/material.dart';

import '../features/paralisacao/domain/entities/paralisacao.dart';
import '../features/paralisacao/presentation/pages/paralisacao_form_page.dart';
import '../features/privacidade/domain/entities/aviso_de_privacidade.dart';
import '../features/privacidade/presentation/pages/privacidade_page.dart';

// Abertura das telas: só navega. Quem chama não precisa saber como a tela é
// montada. O builder de uma rota pode rodar de novo, então ele não cria
// ViewModel: cada tela cria o seu no State, uma vez só.
abstract final class Rotas {
  static Future<void> avisoDePrivacidade(
    BuildContext context, {
    String email = '',
    AvisoDePrivacidade? avisoPendente,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PrivacidadePage(email: email, avisoPendente: avisoPendente),
      ));

  // Nova paralisação no dia de trabalho ou edição. Devolve true quando salvou ou excluiu.
  static Future<bool?> formularioDeParalisacao(
    BuildContext context, {
    required int usuarioId,
    required DateTime dia,
    required bool noturno,
    Paralisacao? paralisacao,
  }) =>
      Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ParalisacaoFormPage(
          usuarioId: usuarioId,
          dia: dia,
          noturno: noturno,
          paralisacao: paralisacao,
        ),
      ));
}
