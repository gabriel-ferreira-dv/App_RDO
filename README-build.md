# Gerar e instalar o APK

O passo a passo que eu sigo para gerar o APK, instalar nos celulares e publicar uma atualização pelo próprio app.

## 1. Gerar o APK

```powershell
flutter build apk --release
```

O arquivo sai em:

```
build\app\outputs\flutter-apk\app-release.apk
```

Esse APK já instala em qualquer Android. Enquanto não existir a chave de assinatura (passo 2), ele sai assinado com a chave de debug deste computador. Funciona, mas tem um porém, que eu explico logo abaixo.

## 2. Chave de assinatura

**Como está hoje:** todos os APKs que eu distribuí até agora foram assinados com a chave de debug deste computador (`C:\Users\064925\.android\debug.keystore`). O Android só aceita uma atualização assinada com a mesma chave da versão que está instalada. Então, enquanto eu não trocar:

- gero os APKs sempre neste computador;
- mantenho um backup desse arquivo. Se eu perder, ninguém consegue mais atualizar por cima, e todo mundo tem que desinstalar e instalar de novo.

Quando eu criar a chave própria, isso vai acontecer uma vez: os celulares vão recusar a primeira atualização assinada com a chave nova, e cada um vai ter que desinstalar e instalar de novo. Por isso faz sentido trocar junto com o `applicationId` (que ainda é `com.example.flutter_application_1`), que também obriga a instalar de novo.

Para criar a chave (uma vez só), no PowerShell, dentro da pasta do projeto:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v `
  -keystore android\app\upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias rdocbm
```

Ele pede uma senha, que eu tenho que guardar bem, e alguns dados (nome, organização, cidade). Nada disso aparece para quem usa o app.

Depois eu crio o arquivo `android\key.properties`, trocando `SUA_SENHA` pela senha que digitei:

```properties
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=rdocbm
storeFile=upload-keystore.jks
```

A partir daí, o `flutter build apk --release` usa a chave nova sozinho. Quem procura o `key.properties` é o `android/app/build.gradle.kts`.

O `key.properties` e o `.jks` estão no `.gitignore`, então não vão para o repositório. Eu guardo uma cópia dos dois fora do computador: perder o `.jks` é perder para sempre a chance de atualizar o app que já está nos celulares.

## 3. Instalar em outro celular

1. Mando o `app-release.apk` para o celular por cabo USB, Google Drive, OneDrive ou pen drive. Por e-mail não vai, o arquivo é grande demais.
2. No celular, abro o arquivo pelo gerenciador de arquivos.
3. O Android avisa que a instalação vem de "fonte desconhecida". Toco em **Configurações**, permito a instalação para aquele app (o gerenciador de arquivos ou o navegador), volto e confirmo.
4. Na primeira abertura, o app pede câmera, localização, microfone e notificações. Todas são necessárias para o registro.

Pelo cabo, com o celular em modo desenvolvedor, é mais rápido:

```powershell
flutter install --release
```

Quem já tem a versão 1.0.0+2 ou mais nova recebe as próximas pelo próprio app (passo 6).

## 4. Testar no emulador

O emulador do meu PC tem pouco espaço, e o APK de debug não cabe nele. Para conferir uma mudança, eu gero um APK menor, só para a arquitetura do emulador, e instalo por cima:

```powershell
flutter build apk --profile --target-platform android-x64
adb install -r build\app\outputs\flutter-apk\app-profile.apk
```

Esse APK não mexe no `app-release.apk`. Não desinstalo o app do emulador para liberar espaço, porque isso apaga o banco dele, junto com a sessão e os dados de teste. E um cuidado: o que eu registro no emulador sobe para o Supabase de verdade.

## 5. Tamanho do APK

Desde a versão 1.0.0+2 os mapas **não vão no APK** (eram uns 200 dos 254 MB). Cada celular baixa os mapas da filial dele pela tela de Atualizações, do bucket `dados` do Supabase. Então todo mapa que está na configuração da obra (coluna `config` da tabela `filiais`) precisa estar no bucket, com a linha dele em `dados_da_obra`. Sem isso, o mapa mostra só o satélite. Quem sobe os arquivos é o painel, na página "Dados da obra".

Antes disso, o APK chegou a ter 791 MB: os tiles dos mapas eram PNG (uns 725 MB) e eu converti para **WebP** (uns 130 MB), sem diferença que dê para ver. Os tiles são fotos aéreas com transparência. PNG é ótimo para desenho e ruim para foto, JPEG não tem transparência, e o WebP resolve os dois lados e o Flutter lê direto.

### Se os tiles forem refeitos

Depois de gerar tiles novos em PNG (`tool/split_overlay.dart`), eu converto:

```powershell
npm install sharp             # uma vez só
node tool\converter_tiles_webp.js --mover
```

Os PNGs originais vão para `_tiles_png_backup/`, fora dos assets e fora do git. O app procura **`.webp`**: PNG solto nas pastas dos mapas só ocupa espaço.

### Mapa novo pelo Supabase

O `.zip` de cada mapa que vai para o bucket `dados` tem que ter os arquivos **`.webp`**. Se tiver PNG, o app baixa mas não acha os tiles. O nome do mapa precisa bater na configuração da obra, na pasta que o app baixa e na coluna `nome` de `dados_da_obra`, e o `.zip` não pode ter acento nem espaço no nome.

## 6. Publicar uma atualização pelo próprio app

O passo a passo completo está no começo de `supabase_consultas/versao_app.sql`. Resumindo:

1. No `pubspec.yaml`, aumento o número depois do `+` em `version:` (por exemplo, de `1.0.0+3` para `1.0.0+4`). É esse número que o app compara. O que vem antes do `+` é só o nome que aparece no aviso.
2. Gero o APK **neste computador** (passo 1), por causa da chave.
3. Subo o APK no bucket `dados` com o número no nome (por exemplo, `RDO-cbm-4.apk`). Sempre um nome novo, sem sobrescrever o anterior: o Storage guarda cópia em cache, e um arquivo sobrescrito pode chegar velho no celular.
4. Na tabela `versao_app`, linha `android`, preencho `versao_codigo` com o número depois do `+`, `versao_nome` com o que vem antes, `arquivo` com o nome do APK e, se quiser, um texto curto em `novidades`. Deixo `versao_minima` em 0. Só aumento quando uma versão antiga precisa sair de uso de vez, porque quem estiver abaixo dela não consegue fechar o aviso sem atualizar.
5. Na próxima vez que abrir o app, cada celular vê o aviso, baixa o APK e abre o instalador. Quem confirma a instalação é o encarregado. O aviso também fica na tela de Atualizações.

Só chega a quem já tem a 1.0.0+2 ou mais nova. Quem tem uma versão anterior ainda recebe o APK pelo grupo.

## 7. iPhone

O build do iOS está configurado no `codemagic.yaml`: o Codemagic compila num Mac na nuvem e manda para o TestFlight, de onde os encarregados instalam. Ainda não está pronto: o `APP_ID` no arquivo continua zerado, e ele depende da conta Apple Developer. O que fazer antes do primeiro build está nos comentários do começo do `codemagic.yaml`.
