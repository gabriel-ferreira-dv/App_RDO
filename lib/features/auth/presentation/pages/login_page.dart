import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/rotas.dart';
import '../../auth_service.dart';
import '../../models/usuario.dart';
import '../widgets/cabecalho_do_login.dart';

class LoginPage extends StatefulWidget {
  final void Function(Usuario usuario) aoLogar;

  const LoginPage({super.key, required this.aoLogar});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _modoCadastro = false;
  bool _carregando = false;
  bool _senhaVisivel = false;
  String? _erro;

  final _nomeController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _matriculaController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Preencha e-mail e senha');
      return;
    }
    if (_modoCadastro && _nomeController.text.trim().isEmpty) {
      setState(() => _erro = 'Preencha o nome');
      return;
    }
    if (_modoCadastro && _matriculaController.text.trim().isEmpty) {
      setState(() => _erro = 'Preencha a matrícula');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    final erro = _modoCadastro
        ? await AuthService.instancia.cadastrar(
            _nomeController.text.trim(),
            email,
            senha,
            matricula: _matriculaController.text.trim(),
          )
        : await AuthService.instancia.login(email, senha);

    if (!mounted) return;
    setState(() => _carregando = false);

    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }

    widget.aoLogar(AuthService.instancia.usuarioLogado!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ícones claros na barra de status, sobre o cabeçalho grafite.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              CabecalhoDoLogin(
                subtitulo: _modoCadastro
                    ? 'Crie sua conta para começar'
                    : 'Entre para continuar',
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    // Sobe sobre o cabeçalho.
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
                                children: [
                                  if (_modoCadastro) ...[
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: TextField(
                                        controller: _nomeController,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Nome',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                      ),
                                    ),
                                    // Matrícula do sistema corporativo: é por ela que o
                                    // relatório encontra a equipe do encarregado no
                                    // apontamento (campo "051395::NOME").
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: TextField(
                                        controller: _matriculaController,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Matrícula',
                                          hintText: 'ex.: 051395',
                                          helperText:
                                              'Matrícula CBM, a mesma que está no crachá',
                                          prefixIcon:
                                              Icon(Icons.badge_outlined),
                                        ),
                                      ),
                                    ),
                                  ],
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'E-mail',
                                        prefixIcon: Icon(Icons.mail_outline),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextField(
                                      controller: _senhaController,
                                      obscureText: !_senhaVisivel,
                                      onSubmitted: (_) => _enviar(),
                                      decoration: InputDecoration(
                                        labelText: 'Senha',
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
                                  // A informação vem antes da coleta (LGPD,
                                  // art. 9º).
                                  if (_modoCadastro)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        'Ao se cadastrar, seus dados são '
                                        'usados como explica o aviso de '
                                        'privacidade (link abaixo).',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _carregando ? null : _enviar,
                                      child: _carregando
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(_modoCadastro
                                              ? 'Cadastrar'
                                              : 'Entrar'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _carregando
                                ? null
                                : () => setState(() {
                                      _modoCadastro = !_modoCadastro;
                                      _erro = null;
                                    }),
                            child: Text(
                              _modoCadastro
                                  ? 'Já tenho conta — Entrar'
                                  : 'Não tenho conta — Cadastrar',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Rotas.avisoDePrivacidade(context),
                            icon: const Icon(Icons.privacy_tip_outlined,
                                size: 18),
                            label: const Text('Aviso de privacidade'),
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
