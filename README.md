# RDO cbm

App que eu desenvolvi para os encarregados registrarem no celular o que foi feito na obra durante o dia (foto, local e serviço) e, no fim do dia, gerarem o RDO em PDF.

## Por que eu fiz

Antes do app, as fotos e os avisos de serviço chegavam pelo grupo do WhatsApp, cada um de um jeito. Muitas vezes não dava para saber em que KM ou estaca a foto tinha sido tirada, e montar o RDO, a medição e o avanço da obra virava um trabalho de garimpo.

A ideia é que o registro já saia padronizado do campo. O encarregado escolhe o trecho, o KM, a estaca e o serviço, tira as fotos, e cada foto sai carimbada com essas informações, data, hora, coordenada, o logo e um minimapa do local.

O app guarda também a foto sem carimbo e o minimapa separados. É deles que o carimbo é refeito quando um registro é corrigido, e é por isso que o painel consegue mostrar a foto sem carimbo. Toda correção fica registrada no Supabase, na tabela `registros_edicoes` (quem alterou, quando, o valor antigo e o novo).

## O que tem no app

O visual segue a cor do ícone do app: grafite nos cabeçalhos e o amarelo de sinalização de obra só na ação principal de cada tela, para achar fácil no sol. Na barra do topo, ao lado das iniciais do usuário, tem um botão que troca entre claro e escuro. A escolha fica guardada no celular, e enquanto ninguém escolhe o app segue o modo do aparelho. Embaixo fica uma barra com Início, Histórico, o botão do meio (Registrar), Mapa e Mais:

- **Início**: mostra se ainda tem alguma coisa esperando sinal para subir, o botão de novo registro, quantos registros e paradas teve no dia e o atalho para o RDO.
- **Registrar** (o botão amarelo do meio): o registro em etapas. Na primeira vem o local: trecho, KM, via e estacas, ou o botão "Usar minha localização", que pega a estaca mais perto pelo GPS. Na segunda vem o serviço: a atividade (em botões), o serviço, o passo, a medição e a descrição, que pode ser ditada. A terceira etapa é a câmera.
- **Histórico**: os registros do mais recente para o mais antigo, filtrados por hoje, ontem, 7 dias ou tudo. Cada um mostra se já foi enviado, se está aguardando sinal ou se foi corrigido. Dá para corrigir um registro depois (trecho, KM, estacas, serviço, medição, descrição), e o carimbo das fotos é refeito com os dados novos. Data, hora, coordenada e minimapa não mudam.
- **Mapa**: satélite com o desenho do projeto por cima e a posição atual. Cada usuário vê os mapas do grupo dele (CBM ou subcontratada).
- **Mais**:
  - **Paradas**: registro de paralisação, com motivo, hora de início e fim e fotos. Quando o serviço está parado, o "Mais" fica com um ponto vermelho.
  - **Relatório do dia**: gera o RDO em PDF, com os registros, as fotos, as paralisações, o clima, o efetivo que vem do SIMOVA e um mapa das atividades.
  - **Equipe** (só para supervisor): o supervisor monta a equipe dele, acompanha os registros dos encarregados, gera o relatório consolidado e o mapa de avanço. Também consegue lançar um registro em nome de um encarregado e corrigir os registros da equipe.
  - **Registros dos usuários** (só para o admin do painel): os registros de todos num dia, com busca pelo nome ou pela matrícula. O admin corrige qualquer registro, inclusive a descrição, e a correção chega no celular do dono, que refaz o carimbo da foto. O servidor precisa do `supabase_consultas/admin_corrige_registros.sql`.
  - **Atualizações** e **Como usar o app**.
  - **Privacidade**: o aviso de privacidade (LGPD) da filial da pessoa. O texto fica na tabela `aviso_privacidade` do Supabase, um por filial, e eu edito lá mesmo, sem lançar versão nova do app. Na primeira vez que a pessoa entra, e sempre que eu subo a versão do aviso, o app abre o aviso e só libera depois do "Li e entendi". A tela de login também tem o link para ler.

Além disso, o app avisa às 16:30, de segunda a sábado, para ninguém esquecer de registrar, e mostra as mensagens que o gestor manda pelo Supabase.

Para quem trabalha à noite (quem está na tabela `turno_noturno`), o dia de trabalho vai do meio-dia até as 11:59 do dia seguinte. Assim o que foi feito de madrugada entra no RDO da noite em que o serviço começou.

## Como funciona por dentro

O mais importante: **o app funciona sem internet**. Tudo é gravado primeiro no celular, num banco SQLite, e quando tem sinal ele envia sozinho para o Supabase. Se a internet cai no meio do envio, o que faltou fica pendente e sobe na próxima vez. Para não duplicar nada no servidor, cada linha é identificada pelo aparelho e pelo id que ela tem no celular (`dispositivo_id` + `id_local`).

O envio não depende do app estar aberto. Quando sobra alguma coisa pendente, eu deixo uma tarefa agendada no WorkManager do Android (pacote `workmanager`). Assim que o celular pega internet, o Android acorda o app, mesmo fechado, e sobe o que faltou. Se a rede cair no meio, ele tenta de novo depois. Além disso tem uma rodada de reserva a cada 15 minutos. Com o app aberto, quem envia é o próprio app, e a tarefa só pede e espera. Isso fica em `lib/features/sincronizacao/envio_em_segundo_plano.dart`.

No Supabase eu uso:

- **Auth** para o login com e-mail e senha. Sem internet, o app aceita a última senha que funcionou online. Para isso ele guarda no celular uma cópia protegida com PBKDF2 (SHA-256, sal aleatório e 120 mil rodadas), nunca a senha em si. As cópias antigas, do tempo em que era SHA-256 sem sal, são convertidas sozinhas.
- **Postgres com RLS**: o encarregado só vê o que é dele, o supervisor vê também a equipe dele e o gestor do painel vê tudo. Quem é supervisor fica na tabela `perfis_app`, que o app não consegue alterar.
- **Filiais**: cada obra é uma filial. A filial de cada pessoa fica em `perfis_app`, e a tabela `filiais` guarda a configuração de cada obra.
- **Storage**: o bucket `fotos` (privado), com uma pasta por filial e, dentro dela, uma por encarregado, e o bucket `dados` (público), onde ficam os CSVs, os mapas e o APK novo.
- **Edge Function** que puxa o relatório "Equipe Apontada" do SIMOVA, para o RDO já sair com o efetivo do dia.

Os CSVs do projeto (`KMxEst.csv`, `estacas_coords.csv` e `SevNotaveis.csv`) vêm junto com o APK, mas cada filial tem os seus no Supabase. A tabela `dados_da_obra` diz qual é a versão de cada arquivo em cada filial, e quando sai uma versão nova o app baixa sozinho os da filial da pessoa, sem precisar lançar outro APK. Os mapas funcionam do mesmo jeito, só que não vêm no APK: são sempre baixados do Supabase. Se a pessoa muda de filial, o app apaga o que tinha baixado da obra anterior.

O resto do que muda de uma obra para outra (fuso UTM, vias, trechos sem via ou sem estaca, se a obra usa KM, os mapas e a explicação de cada atividade) fica na coluna `config` da tabela `filiais`. Sem ela, vale a configuração da obra atual, que está no código (`configPadrao`, em `lib/core/obra/config_da_obra.dart`).

As coordenadas das estacas estão em UTM, igual ao CAD do projeto. Na obra atual é SIRGAS 2000, fuso 24S, e cada obra diz o seu fuso na configuração. O app converte para latitude e longitude com o `proj4dart` para comparar com o GPS e encaixar os mapas.

O painel web que os gestores usam fica em outro repositório (`painel`) e lê o mesmo Supabase.

## Organização do código

Separei por funcionalidade, uma pasta para cada em `lib/features/`. Estou passando o código para um padrão só, em camadas, uma funcionalidade por vez. As que já foram passadas têm três partes:

- `domain/`: as regras, em Dart puro. As entidades, as interfaces dos repositórios e os casos de uso, quando tem regra de verdade (validar, combinar, calcular). Operação simples o ViewModel pede direto para o repositório.
- `data/`: o acesso aos dados (SQLite, Supabase, CSVs) e as implementações dos repositórios.
- `presentation/`: as páginas (`pages/`), os pedaços de tela (`widgets/`) e os ViewModels (`viewmodels/`).

Para o estado das telas eu uso MVVM com o que o próprio Flutter já tem, sem pacote a mais. O ViewModel é um `ChangeNotifier` com o estado e as ações da tela, e a página só desenha o que ele tem, com um `ListenableBuilder`. Os widgets não têm regra.

Quem liga tudo é `lib/app/dependencias.dart`: lá eu monto os repositórios, os serviços e os ViewModels, passando cada coisa pelo construtor. É isso que deixa testar cada ViewModel com um repositório falso, sem banco e sem Supabase.

Dois cuidados:

- A tela cria o ViewModel uma vez só, no `State` (`late final _vm = widget.viewModel ?? Dependencias.x()`), nunca no builder de uma rota, folha ou diálogo. Esses builders rodam de novo, num arrasto por exemplo, e trocavam o ViewModel no meio do uso. Por isso `lib/app/rotas.dart` só navega.
- ViewModel que espera resposta do banco ou da rede usa o mixin `DescarteSeguro` (`lib/core/estado/`). Ele ignora a resposta que chega depois de a tela fechar, em vez de dar erro.

Já estão nesse padrão: privacidade, paralisação, histórico, admin, registro e mapa. Câmera, supervisor, relatório, sincronização e o resto ainda estão do jeito antigo, com a tela chamando um `*_service.dart` direto.

As cores e o tema ficam em `lib/core/theme/`, e as extensões de data e texto em `lib/core/extensions/`.

```
lib/
  main.dart
  app/             abertura do app, rotas e Dependencias (onde tudo é montado)
  core/            banco local, tema, extensões, configuração da obra e do Supabase, widgets comuns
  features/
    inicio/        casca do app (barras de cima e de baixo), Início e resumo do dia
    auth/          login, sessão e a cópia da senha para entrar sem internet
    registro/      formulário, CSVs, estacas e sugestão pelo GPS
    camera/        câmera e carimbo da foto
    paralisacao/   aba Paradas
    historico/
    admin/         registros de todos, para o admin do painel
    privacidade/   aviso de privacidade por filial
    mapa/          mapa, tiles do projeto e permissão por grupo
    obra/          configuração da obra que vem do Supabase
    relatorio/     RDO em PDF, clima, efetivo do SIMOVA e turno da noite
    sincronizacao/ envio para o Supabase (também em segundo plano) e atualização dos dados e do app
    supervisor/    equipe, registros da equipe, consolidado e mapa de avanço
    notificacoes/  lembrete diário, mensagens do gestor e avisos de atualização
    tutorial/
supabase/          config e migrations do banco
supabase_consultas/  scripts antigos que eu rodava no SQL Editor (fora do git)
tool/              scripts de apoio: fontes do carimbo, ícone, preparação dos mapas e mudança das fotos para a pasta da filial
scripts/           pull_db.ps1 (banco de um celular pro PC) e copiar_estrutura_do_banco.ps1 (estrutura do Supabase)
test/
```

## Banco no celular

O SQLite fica no arquivo `registro_diario.db`, na pasta de dados do app (não fica dentro do projeto). As tabelas são criadas e atualizadas em `lib/core/database/db_helper.dart`, e hoje o banco está na versão 16. Quando eu acrescento um campo, coloco a migração no `onUpgrade`, assim quem atualiza o app não perde nada.

As tabelas são `usuarios`, `registros`, `fotos`, `paralisacoes`, `fotos_paralisacao`, `relatorio_diario_info` (os dados do RDO de cada dia) e `avisos`. As que sobem para o Supabase têm a coluna `sincronizado`: 0 enquanto falta enviar, 1 depois que o servidor confirmou.

Para olhar o banco de um celular conectado no PC, eu rodo `.\scripts\pull_db.ps1`.

## Banco do Supabase

Mudança no banco agora vai por migration, na pasta `supabase/`. Crio o arquivo com `npx supabase migration new nome`, escrevo o SQL e abro um PR. O Supabase cria um banco de teste pra esse PR e roda as migrations nele, e quando eu dou merge no `main` ele aplica na produção.

A primeira migration (`estrutura_inicial`) é a estrutura que já estava em produção em 26/10/2026. Na produção ela foi marcada como aplicada, então só roda nos bancos de teste. Pra copiar a estrutura de novo tem o `scripts/copiar_estrutura_do_banco.ps1`.

Antes disso eu rodava os scripts da pasta `supabase_consultas/` à mão no SQL Editor. Ela continua no meu computador, fora do git. O cron `registro-diario-horario` ainda está só na produção, não entrou nas migrations.

Um cuidado: quando o app passa a mandar uma coluna nova, a migration que cria essa coluna tem que entrar no `main` **antes** de eu lançar a versão. Senão o servidor recusa os registros que chegam com a coluna desconhecida.

## Como rodar

```bash
flutter pub get
flutter run
```

Os testes:

```bash
flutter test
```

Para ver os widgets sem abrir o app inteiro, uso o Widget Preview (os exemplos estão em `lib/core/widgets/previews.dart`):

```bash
flutter widget-preview start
```

A URL e a chave pública do Supabase ficam em `lib/core/supabase_config.dart`. Essa chave é pública mesmo, porque vai dentro do APK. Quem protege os dados são as regras de RLS.

Para gerar o APK e instalar nos celulares, escrevi o passo a passo no [README-build.md](README-build.md).

## Testes

Os testes ficam em `test/`, separados do mesmo jeito que as features. Nas partes que já estão em camadas, cada ViewModel tem teste do fluxo (carregar, escolher, salvar, dar erro) com um repositório falso, que fica em `test/features/<feature>/fakes.dart`, e as telas principais têm teste de widget. No resto, os testes cobrem principalmente a lógica: o carimbo da foto, as estacas e o KM final, a sugestão pelo GPS, a leitura dos CSVs, o texto e as fotos do PDF, o clima e o efetivo do RDO, a sincronização, o relatório consolidado e o mapa de avanço.

O que depende de câmera, GPS ou do Supabase de verdade eu testo no celular ou no emulador.

## O que ainda falta

- O `applicationId` ainda é `com.example.flutter_application_1`. Trocar exige que todo mundo desinstale e instale de novo, então faz sentido trocar junto com a assinatura.
- Os APKs ainda são assinados com a chave de debug do meu computador. O README-build.md explica o porquê e o que fazer na hora de trocar.
- Passar câmera, supervisor, relatório e sincronização para o padrão em camadas. A sincronização fica por último.
