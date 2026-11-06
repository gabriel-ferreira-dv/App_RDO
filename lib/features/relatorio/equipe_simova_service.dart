import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/extensions/data_hora_extensions.dart';
import '../../core/extensions/texto_extensions.dart';
import 'domain/entities/funcao_equipe.dart';

export 'domain/entities/funcao_equipe.dart';

// Uma linha do apontamento de equipe (só as colunas que interessam).
class LinhaApontamento {
  final String encarregado;
  final String funcionario;
  final String funcao;

  const LinhaApontamento({
    required this.encarregado,
    required this.funcionario,
    required this.funcao,
  });

  // Uma linha da view equipe_apontamento.
  factory LinhaApontamento.fromMap(Map<String, dynamic> l) => LinhaApontamento(
        encarregado: (l['encarregado'] as String?) ?? '',
        funcionario: (l['funcionario'] as String?) ?? '',
        funcao: (l['funcao'] as String?) ?? '',
      );
}

// Nome de um campo "matrícula::NOME" (sem "::", o texto inteiro).
String nomeDoCampo(String valor) {
  final v = valor.trim();
  final i = v.indexOf('::');
  return i < 0 ? v : v.substring(i + 2).trim();
}

// Matrícula de um campo "matrícula::NOME" (vazio sem "::").
String matriculaDoCampo(String valor) {
  final v = valor.trim();
  final i = v.indexOf('::');
  return i < 0 ? '' : v.substring(0, i).trim();
}

// Nome comparável: ignora caixa, acento e espaço repetido.
String normalizarNome(String valor) => nomeDoCampo(valor)
    .toLowerCase()
    .semAcento
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// "MOTORISTA VEIC. PESADOS" → "Motorista Veic. Pesados". Romanos (II, III)
// e siglas de uma letra ficam em caixa alta.
String formatarFuncao(String bruta) {
  final palavras = nomeDoCampo(bruta).trim().split(RegExp(r'\s+'));
  return palavras.map((p) {
    if (p.isEmpty) return p;
    final semPonto = p.replaceAll('.', '');
    if (RegExp(r'^[IVX]+$').hasMatch(semPonto)) return p.toUpperCase();
    if (semPonto.length <= 1) return p.toUpperCase();
    if (RegExp(r'^\d+$').hasMatch(semPonto)) return p;
    return p[0].toUpperCase() + p.substring(1).toLowerCase();
  }).join(' ');
}

// Pessoas por função, contando cada matrícula uma vez só (a mesma pessoa
// aparece em várias linhas no dia). Sem função ("-") fica de fora.
List<FuncaoEquipe> resumirEquipe(List<LinhaApontamento> linhas) {
  final funcaoPorPessoa = <String, String>{};
  for (final l in linhas) {
    // Sem matrícula, o nome serve de chave.
    final chave = matriculaDoCampo(l.funcionario).isNotEmpty
        ? matriculaDoCampo(l.funcionario)
        : normalizarNome(l.funcionario);
    if (chave.isEmpty) continue;
    final funcao = formatarFuncao(l.funcao);
    if (funcao.isEmpty || funcao == '-') continue;
    funcaoPorPessoa.putIfAbsent(chave, () => funcao);
  }

  final contagem = <String, int>{};
  for (final funcao in funcaoPorPessoa.values) {
    contagem[funcao] = (contagem[funcao] ?? 0) + 1;
  }

  final resultado = contagem.entries
      .map((e) => FuncaoEquipe(funcao: e.key, quantidade: e.value))
      .toList();
  // Maiores primeiro; empate pelo nome, para a ordem ser estável.
  resultado.sort((a, b) {
    final porQtd = b.quantidade.compareTo(a.quantidade);
    return porQtd != 0 ? porQtd : a.funcao.compareTo(b.funcao);
  });
  return resultado;
}

// data_inicial vem como "22/07/2026 07:07" (dia.dataCurta) ou em ISO,
// "2026-07-22T07:07:00+00:00" (dia.dataIso).

// Se `data_inicial` é do mesmo dia. Aceita o formato brasileiro e o ISO.
bool mesmoDia(String valor, DateTime dia) {
  final v = valor.trim();
  return v.startsWith(dia.dataCurta) || v.startsWith(dia.dataIso);
}

// Dia de `data_inicial` como "dd/MM/yyyy"; vazio se o formato é outro.
String diaDoValor(String valor) {
  final v = valor.trim();
  if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(v)) return v.substring(0, 10);
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(v)) {
    return '${v.substring(8, 10)}/${v.substring(5, 7)}/${v.substring(0, 4)}';
  }
  return '';
}

// A equipe achada, ou um erro com pistas para o usuário.
class ResultadoEquipe {
  final List<FuncaoEquipe>? equipe;
  final String? erro;

  // Encarregados do dia, mostrados quando a matrícula não casou.
  final List<String> encarregadosDoDia;

  // Dias com apontamento do usuário, mostrados quando o dia pedido não tem.
  final List<String> diasComApontamento;

  const ResultadoEquipe.ok(List<FuncaoEquipe> this.equipe)
      : erro = null,
        encarregadosDoDia = const [],
        diasComApontamento = const [];
  const ResultadoEquipe.falha(String this.erro,
      {this.encarregadosDoDia = const [], this.diasComApontamento = const []})
      : equipe = null;
}

// Equipe do dia no apontamento do SIMOVA, pelo encarregado.
class EquipeSimovaService {
  EquipeSimovaService._interno();
  static final EquipeSimovaService instancia = EquipeSimovaService._interno();

  // View só com as colunas que o app usa (supabase/add_equipe_apontada.sql).
  static const String tabela = 'equipe_apontamento';

  // Equipe do encarregado no [dia], só pela [matricula] — por nome dava
  // errado (homônimo, abreviação).
  Future<ResultadoEquipe> buscar({
    required String matricula,
    required DateTime dia,
  }) async {
    final matriculaAlvo = matricula.trim();
    if (matriculaAlvo.isEmpty) {
      return const ResultadoEquipe.falha(
          'Seu usuário está sem matrícula. Cadastre a matrícula no Supabase '
          '(campo "matricula") e entre no app novamente');
    }
    try {
      var linhas = await _linhasDoDia(dia);
      var jaFiltradoPorDia = true;

      // Nada achado: busca tudo da matrícula e filtra o dia aqui (serve
      // também para listar os dias que têm apontamento).
      if (linhas.isEmpty) {
        linhas = await _paginar(
            (q) => q.like('encarregado', '$matriculaAlvo::%'));
        jaFiltradoPorDia = false;
      }

      if (linhas.isEmpty) {
        return ResultadoEquipe.falha(
            'Nenhum apontamento encontrado para a matrícula $matriculaAlvo');
      }

      final doEncarregado = <LinhaApontamento>[];
      final todosEncarregados = <String>{};
      final diasDisponiveis = <String>{};
      for (final l in linhas) {
        final campoData = (l['data_inicial'] as String?) ?? '';
        final campoEnc = (l['encarregado'] as String?) ?? '';
        final mat = matriculaDoCampo(campoEnc);

        final doUsuario = mat == matriculaAlvo;

        if (doUsuario) {
          final d = diaDoValor(campoData);
          if (d.isNotEmpty) diasDisponiveis.add(d);
        }
        if (!jaFiltradoPorDia && !mesmoDia(campoData, dia)) continue;
        if (jaFiltradoPorDia) {
          todosEncarregados.add(mat.isEmpty
              ? nomeDoCampo(campoEnc)
              : '$mat - ${nomeDoCampo(campoEnc)}');
        }
        if (!doUsuario) continue;

        doEncarregado.add(LinhaApontamento.fromMap(l));
      }

      if (doEncarregado.isEmpty) {
        final lista = todosEncarregados.where((e) => e.isNotEmpty).toList()
          ..sort();
        return ResultadoEquipe.falha(
          'Nenhum apontamento para a matrícula $matriculaAlvo em ${dia.dataCurta}',
          encarregadosDoDia: lista,
          diasComApontamento: _ordenarDias(diasDisponiveis),
        );
      }

      final equipe = resumirEquipe(doEncarregado);
      if (equipe.isEmpty) {
        return const ResultadoEquipe.falha(
            'Apontamentos encontrados, mas sem função preenchida');
      }
      return ResultadoEquipe.ok(equipe);
    } catch (e) {
      debugPrint('Busca de equipe no $tabela falhou: $e');
      return const ResultadoEquipe.falha(
          'Não foi possível buscar a equipe — verifique a conexão');
    }
  }

  // Efetivo de cada encarregado no [dia] (matrícula → funções), lendo o
  // apontamento do dia uma vez só. Antes o painel do supervisor chamava
  // [buscar] para cada encarregado, e cada chamada baixava o dia inteiro.
  // Vazio se a busca falhar.
  Future<Map<String, List<FuncaoEquipe>>> equipesDoDia(DateTime dia) async {
    try {
      final porEncarregado = <String, List<LinhaApontamento>>{};
      for (final l in await _linhasDoDia(dia)) {
        final linha = LinhaApontamento.fromMap(l);
        final matricula = matriculaDoCampo(linha.encarregado);
        if (matricula.isEmpty) continue;
        porEncarregado.putIfAbsent(matricula, () => []).add(linha);
      }
      return {
        for (final e in porEncarregado.entries) e.key: resumirEquipe(e.value),
      };
    } catch (e) {
      debugPrint('Busca do efetivo do dia no $tabela falhou: $e');
      return {};
    }
  }

  // Encarregados dos últimos [dias] dias, para o supervisor montar a equipe.
  Future<List<({String matricula, String nome})>> listarEncarregados({
    int dias = 2,
  }) async {
    final encontrados = <String, String>{}; // matrícula → nome
    try {
      final hoje = DateTime.now();
      for (var i = 0; i < dias; i++) {
        final dia = hoje.subtract(Duration(days: i));
        for (final l in await _linhasDoDia(dia)) {
          final campo = (l['encarregado'] as String?) ?? '';
          final mat = matriculaDoCampo(campo);
          if (mat.isEmpty) continue;
          encontrados.putIfAbsent(mat, () => nomeDoCampo(campo));
        }
      }
    } catch (e) {
      debugPrint('Listagem de encarregados falhou: $e');
    }
    final lista = [
      for (final e in encontrados.entries) (matricula: e.key, nome: e.value),
    ]..sort((a, b) => a.nome.compareTo(b.nome));
    return lista;
  }

  // Linhas por página do PostgREST (padrão do Supabase).
  static const int _tamanhoPagina = 1000;

  // Teto contra laço infinito (60 mil linhas). Era 1: num dia com mais de
  // 1.000 linhas de apontamento na obra, quem ficava de fora da primeira
  // página saía sem efetivo no RDO e no painel do supervisor.
  static const int _maxPaginas = 60;

  // Apontamento do [dia]. A data é texto em ISO (atual) ou no formato
  // brasileiro (antigo): tenta os dois.
  Future<List<Map<String, dynamic>>> _linhasDoDia(DateTime dia) async {
    final iso = await _paginar((q) => q.like('data_inicial', '${dia.dataIso}%'));
    if (iso.isNotEmpty) return iso;
    return _paginar((q) => q.like('data_inicial', '${dia.dataCurta}%'));
  }

  // Pagina a consulta: sem isso ela vinha cortada em 1.000 linhas. A ordem
  // fixa é o que garante que uma página não repete nem pula linha da outra.
  Future<List<Map<String, dynamic>>> _paginar(
    PostgrestFilterBuilder<PostgrestList> Function(
            PostgrestFilterBuilder<PostgrestList>)
        filtro,
  ) async {
    final todas = <Map<String, dynamic>>[];
    for (var pagina = 0; pagina < _maxPaginas; pagina++) {
      final inicio = pagina * _tamanhoPagina;
      final lote = await filtro(
        Supabase.instance.client
            .from(tabela)
            .select('encarregado, funcionario, funcao, data_inicial'),
      )
          .order('data_inicial', ascending: true)
          .order('encarregado', ascending: true)
          .order('funcionario', ascending: true)
          .order('funcao', ascending: true)
          .range(inicio, inicio + _tamanhoPagina - 1);

      todas.addAll(lote.cast<Map<String, dynamic>>());
      if (lote.length < _tamanhoPagina) break;
    }
    return todas;
  }

  // Dias "dd/MM/yyyy" do mais recente ao mais antigo (por data, não texto).
  List<String> _ordenarDias(Set<String> dias) {
    String chave(String d) =>
        '${d.substring(6, 10)}${d.substring(3, 5)}${d.substring(0, 2)}';
    return dias.toList()..sort((a, b) => chave(b).compareTo(chave(a)));
  }
}
