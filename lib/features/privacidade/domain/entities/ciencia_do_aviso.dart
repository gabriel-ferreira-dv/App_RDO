// Confirmação de leitura ("Li e entendi") de uma versão do aviso.
class CienciaDoAviso {
  final int versao;
  final DateTime quando;

  const CienciaDoAviso(this.versao, this.quando);

  // Vale para a versão do aviso (ou uma mais antiga).
  bool cobre(int versaoDoAviso) => versao >= versaoDoAviso;
}
