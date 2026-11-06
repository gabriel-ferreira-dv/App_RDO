import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/cores_app.dart';
import '../../auth_service.dart';
import '../widgets/cabecalho_do_login.dart';

// Aberta no lugar da Home quando a conta entrou com uma senha provisória
// (perfis_app.trocar_senha). Some sozinha quando a troca é concluída.
class TrocaDeSenhaPage extends StatefulWidget {
  final String nome;
  final VoidCallback aoSair;

  const TrocaDeSenhaPage({super.key, required this.nome, required this.aoSair});

  @override
  State<TrocaDeSenhaPage> createState() => _TrocaDeSenhaPageState();
}

class _TrocaDeSenhaPageState extends State<TrocaDeSenhaPage> {
  bool _carregando = false;
  bool _senhaVisivel = false;
  String? _erro;

  final _novaController = TextEditingController();
  final _confirmacaoController = TextEditingController();

  // As mesmas regras da troca de senha do painel.
  bool get _temTamanho => _novaController.text.length >= 8;
  bool get _temLetra => RegExp(r'\p{L}', unicode: true)
      .hasMatch(_novaController.text);
  bool get _temNumero => RegExp(r'\d').hasMatch(_novaController.text);
  bool get _confere =>
      _novaController.text.isNotEmpty &&
      _novaController.text == _confirmacaoController.text;
  bool get _valida => _temTamanho && _temLetra && _temNumero && _confere;

  @override
  void dispose() {
    _novaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_valida) {
      setState(() => _erro = 'A nova senha ainda não atende às regras abaixo');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    final erro =
        await AuthService.instancia.trocarSenha(_novaController.text);

    if (!mounted) return;
    setState(() {
      _carregando = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const CabecalhoDoLogin(subtitulo: 'Defina sua nova senha'),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Transform.translate(
                      offset: const Offset(0, -36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(
                                      'Olá, ${widget.nome}. Por segurança, troque '
                                      'a senha provisória que você recebeu.',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextField(
                                      controller: _novaController,
                                      obscureText: !_senhaVisivel,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: 'Nova senha',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          tooltip: _senhaVisivel
                                              ? 'Ocultar senha'
                                              : 'Mostrar senha',
                                          icon: Icon(
                                            _senhaVisivel
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                          onPressed: () => setState(
                                            () =>
                                                _senhaVisivel = !_senhaVisivel,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextField(
                                      controller: _confirmacaoController,
                                      obscureText: !_senhaVisivel,
                                      onChanged: (_) => setState(() {}),
                                      onSubmitted: (_) => _salvar(),
                                      decoration: const InputDecoration(
                                        labelText: 'Confirme a nova senha',
                                        prefixIcon: Icon(Icons.lock_outline),
                                      ),
                                    ),
                                  ),
                                  _Regra(
                                      texto: 'Pelo menos 8 caracteres',
                                      ok: _temTamanho),
                                  _Regra(
                                      texto: 'Pelo menos uma letra',
                                      ok: _temLetra),
                                  _Regra(
                                      texto: 'Pelo menos um número',
                                      ok: _temNumero),
                                  _Regra(
                                      texto: 'As duas senhas iguais',
                                      ok: _confere),
                                  const SizedBox(height: 12),
                                  if (_erro != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 18,
                                            color: theme.colorScheme.error,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _erro!,
                                              style: TextStyle(
                                                color: theme.colorScheme.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _carregando ? null : _salvar,
                                      child: _carregando
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Salvar e entrar'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _carregando ? null : widget.aoSair,
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Regra extends StatelessWidget {
  final String texto;
  final bool ok;

  const _Regra({required this.texto, required this.ok});

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    final cor = ok ? cores.enviado : cores.neutro;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: cor,
          ),
          const SizedBox(width: 8),
          Text(texto, style: TextStyle(color: cor)),
        ],
      ),
    );
  }
}
