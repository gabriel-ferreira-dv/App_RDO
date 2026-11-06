import 'dart:async';

import 'package:namer_app/features/privacidade/data/datasources/aviso_local_datasource.dart';
import 'package:namer_app/features/privacidade/data/datasources/aviso_remoto_datasource.dart';
import 'package:namer_app/features/privacidade/domain/entities/aviso_de_privacidade.dart';
import 'package:namer_app/features/privacidade/domain/entities/ciencia_do_aviso.dart';
import 'package:namer_app/features/privacidade/domain/repositories/aviso_de_privacidade_repository.dart';

const textoDeExemplo = '''
Como o RDO cbm usa os seus dados.

# Em resumo
- Usa só o necessário.


# Seus direitos
Você pode pedir acesso e correção.
''';

AvisoDePrivacidade avisoDe(String filial, int versao,
        {String texto = textoDeExemplo, DateTime? atualizadoEm}) =>
    AvisoDePrivacidade(
      filial: filial,
      versao: versao,
      texto: texto,
      atualizadoEm: atualizadoEm,
    );

// Repositório em memória para os casos de uso e o ViewModel.
class RepositorioFalso implements AvisoDePrivacidadeRepository {
  final avisos = <String, AvisoDePrivacidade>{};
  final ciencias = <String, CienciaDoAviso>{};
  int buscas = 0;

  // Enquanto não completar, a busca fica "carregando".
  Completer<void>? segurarBusca;

  @override
  Future<AvisoDePrivacidade?> buscar(String filial) async {
    buscas++;
    await segurarBusca?.future;
    return avisos[filial];
  }

  @override
  Future<CienciaDoAviso?> ciencia(String email, String filial) async =>
      ciencias['$filial|$email'];

  @override
  Future<void> guardarCiencia(
          String email, String filial, CienciaDoAviso ciencia) async =>
      ciencias['$filial|$email'] = ciencia;
}

// Supabase falso: devolve [linha] ou lança [erro] (sem internet).
class RemotoFalso implements AvisoRemotoDataSource {
  Map<String, dynamic>? linha;
  Object? erro;

  @override
  Future<Map<String, dynamic>?> buscar(String filial) async {
    if (erro != null) throw erro!;
    return linha;
  }
}

// Celular falso: um mapa em memória.
class LocalFalso implements AvisoLocalDataSource {
  final dados = <String, String>{};

  @override
  Future<String?> copia(String filial) async => dados['copia:$filial'];

  @override
  Future<void> guardarCopia(String filial, String json) async =>
      dados['copia:$filial'] = json;

  @override
  Future<String?> ciencia(String email, String filial) async =>
      dados['ciencia:$filial|$email'];

  @override
  Future<void> guardarCiencia(
          String email, String filial, String valor) async =>
      dados['ciencia:$filial|$email'] = valor;
}
