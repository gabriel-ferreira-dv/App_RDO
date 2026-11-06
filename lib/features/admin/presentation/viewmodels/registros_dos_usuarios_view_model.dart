import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../../core/extensions/texto_extensions.dart';
import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../supervisor/domain/entities/registro_da_equipe.dart';
import '../../domain/entities/registros_do_usuario.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/carregar_registros_dos_usuarios.dart';

enum SituacaoDaLista { carregando, falhou, vazia, pronta }

// Só para o admin do painel: os registros de todos num dia, com a busca pelo
// nome ou matrícula e a correção.
class RegistrosDosUsuariosViewModel extends ChangeNotifier with DescarteSeguro {
  RegistrosDosUsuariosViewModel({
    required CarregarRegistrosDosUsuarios carregarDoDia,
    required AdminRepository repositorio,
    DateTime Function() agora = DateTime.now,
  })  : _carregarDoDia = carregarDoDia,
        _repositorio = repositorio,
        _dia = agora().soDia;

  final CarregarRegistrosDosUsuarios _carregarDoDia;
  final AdminRepository _repositorio;

  DateTime _dia;
  String _busca = '';
  bool _carregando = true;
  List<RegistroDaEquipe>? _registros;
  Map<String, List<String>> _fotos = const {};

  DateTime get dia => _dia;
  String get busca => _busca;

  // Agrupar, filtrar e ordenar até 1000 registros custa: a conta é feita uma
  // vez por mudança nos registros ou na busca, e não a cada leitura (a tela
  // lê grupos, situação e resumo a cada desenho).
  List<RegistrosDoUsuario>? _grupos;

  List<RegistrosDoUsuario> get grupos => _grupos ??= _registros == null
      ? const []
      : agruparPorUsuario(_registros!, busca: _busca);

  SituacaoDaLista get situacao {
    if (_carregando) return SituacaoDaLista.carregando;
    if (_registros == null) return SituacaoDaLista.falhou;
    return grupos.isEmpty ? SituacaoDaLista.vazia : SituacaoDaLista.pronta;
  }

  // "12 registros de 3 usuários" (só de quem aparece com a busca).
  String get resumo {
    final grupos = this.grupos;
    final registros =
        grupos.fold<int>(0, (soma, g) => soma + g.registros.length);
    return '${registros.plural('registro', 'registros')} de '
        '${grupos.length.plural('usuário', 'usuários')}';
  }

  String get detalheDaListaVazia =>
      _busca.isEmpty ? '' : 'Ninguém com esse nome ou matrícula.';

  List<String> fotosDe(RegistroDaEquipe registro) =>
      _fotos[registro.chave] ?? const [];

  String nomeDe(RegistrosDoUsuario g) => g.nome.isEmpty ? 'Sem nome' : g.nome;

  // "051395 · 3 registros"
  String resumoDe(RegistrosDoUsuario g) => [
        if (g.matricula.isNotEmpty) g.matricula,
        g.registros.length.plural('registro', 'registros'),
      ].join(' · ');

  Future<void> carregar() async {
    final dia = _dia;
    mudar(() => _carregando = true);
    final resultado = await _carregarDoDia(dia);
    // Trocou de dia enquanto buscava: fica a busca mais nova.
    if (dia != _dia) return;
    mudar(() {
      _registros = resultado.registros;
      _grupos = null;
      _fotos = resultado.fotos;
      _carregando = false;
    });
  }

  void mudarDia(DateTime dia) {
    _dia = dia.soDia;
    carregar();
  }

  void definirBusca(String texto) {
    if (texto == _busca) return;
    mudar(() {
      _busca = texto;
      _grupos = null;
    });
  }

  String subtituloDaCorrecao(RegistroDaEquipe r) =>
      'De ${r.usuarioNome}, ${r.criadoEm.toLocal().horaCurta}';

  // Grava no servidor; devolve a mensagem para o usuário. Deu certo:
  // recarrega a lista.
  Future<String> corrigir(
      RegistroDaEquipe registro, CamposDoRegistro campos) async {
    final erro = await _repositorio.corrigir(registro, campos);
    if (erro != null) return erro;
    carregar();
    return 'Registro corrigido. A foto ganha o carimbo novo quando o celular '
        'de ${registro.usuarioNome} sincronizar.';
  }
}
