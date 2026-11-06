import '../../../../core/obra/config_da_obra.dart';

// Explicação de cada atividade (resumo no campo e guia completo), da
// configuração da obra. As chaves precisam bater com a coluna Atividade do
// SevNotaveis.csv (há teste para a obra atual).
Map<String, String> get descricoesAtividades => obraAtual.descricoesAtividades;

// Descrição da atividade, ou null se ainda não houver texto para ela.
String? descricaoDaAtividade(String? atividade) =>
    atividade == null ? null : descricoesAtividades[atividade];
