# =============================================================================
# BACKUP DO SUPABASE (banco + fotos) PARA UMA PASTA DE REDE
# =============================================================================
#
# O que este script faz, em ordem:
#   1. Confere se as ferramentas estao instaladas (pg_dump e rclone).
#   2. Faz o backup do BANCO com o pg_dump: tabelas do app, contas de login e
#      a lista de arquivos do Storage. Sai um arquivo .dump por dia.
#   3. Confere se o arquivo do banco saiu inteiro (abre e conta as tabelas).
#   4. Copia as FOTOS do bucket "fotos" com o rclone. So traz o que e novo;
#      nunca apaga nada do backup.
#   5. Apaga os backups do banco e os logs mais velhos que N dias.
#   6. Grava tudo o que aconteceu num arquivo de log, na pasta "logs".
#
# Antes de usar (uma vez so):
#   - PostgreSQL "Command Line Tools" instalado (traz o pg_dump).
#   - rclone baixado e configurado com o nome "supabase" (rclone config).
#   - Senha do banco no arquivo %APPDATA%\postgresql\pgpass.conf, uma linha:
#       HOST:5432:postgres:USUARIO:SENHA
#     (o mesmo HOST e USUARIO da configuracao abaixo). A senha NAO fica aqui.
#
# Rodar na mao (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\scripts\backup_supabase.ps1
#
# Rodar todo dia as 2h (Agendador de Tarefas, pelo CMD, uma vez):
#   schtasks /Create /TN "Backup RDO Supabase" /SC DAILY /ST 02:00 /TR "powershell -ExecutionPolicy Bypass -File C:\caminho\backup_supabase.ps1"
#   A tarefa roda com o seu usuario do Windows: o pgpass.conf e a configuracao
#   do rclone precisam ser desse mesmo usuario.
# =============================================================================


# -----------------------------------------------------------------------------
# CONFIGURACAO: o que muda de um computador ou projeto para outro.
# -----------------------------------------------------------------------------

# Pasta de rede onde os backups ficam. Dentro dela o script cria "banco",
# "fotos" e "logs".
$destino = '\\SERVIDOR\Backups\RDO'

# Servidor e usuario do banco: copie do Supabase em Connect -> Session pooler.
# O usuario e "postgres." + o codigo do projeto (o pedaco da URL antes de
# ".supabase.co"). O projeto do app hoje e o nrwdoubegllzjdumqurd.
$hostDoBanco    = 'aws-0-sa-east-1.pooler.supabase.com'
$usuarioDoBanco = 'postgres.nrwdoubegllzjdumqurd'

# Onde esta o pg_dump (pasta "bin" do PostgreSQL instalado).
$pastaDoPostgres = 'C:\Program Files\PostgreSQL\18\bin'

# Onde esta o rclone.exe e o nome da configuracao criada no "rclone config".
$rclone       = 'C:\rclone\rclone.exe'
$remotoRclone = 'supabase'
$bucketFotos  = 'fotos'

# Quantos dias de backups do banco (e de logs) guardar. As fotos nao entram:
# o backup delas e uma pasta so, que vai crescendo.
$diasParaGuardar = 30


# -----------------------------------------------------------------------------
# PREPARACAO: pastas, nome dos arquivos de hoje e o log.
# -----------------------------------------------------------------------------

# Data e hora no nome dos arquivos: rdo_2026-10-17_0200.dump
$agora = Get-Date -Format 'yyyy-MM-dd_HHmm'

$pastaBanco = Join-Path $destino 'banco'
$pastaFotos = Join-Path $destino 'fotos'
$pastaLogs  = Join-Path $destino 'logs'

# Cria as pastas se ainda nao existem (se ja existem, nao faz nada).
foreach ($pasta in @($pastaBanco, $pastaFotos, $pastaLogs)) {
    New-Item -ItemType Directory -Force -Path $pasta | Out-Null
}

# Tudo o que aparecer na tela daqui para frente vai tambem para o log.
$arquivoDeLog = Join-Path $pastaLogs "backup_$agora.log"
Start-Transcript -Path $arquivoDeLog | Out-Null

# Se alguma etapa falhar, isto vira $true e o script termina com erro (o
# Agendador de Tarefas mostra "falhou" no historico).
$falhou = $false

Write-Host "Backup do Supabase - $agora"
Write-Host "Destino: $destino"


# -----------------------------------------------------------------------------
# 1. FERRAMENTAS: sem elas nao da para seguir.
# -----------------------------------------------------------------------------

$pgDump    = Join-Path $pastaDoPostgres 'pg_dump.exe'
$pgRestore = Join-Path $pastaDoPostgres 'pg_restore.exe'

if (-not (Test-Path $pgDump)) {
    Write-Host "ERRO: nao achei o pg_dump em $pastaDoPostgres. Instale o PostgreSQL (Command Line Tools) ou corrija o caminho."
    Stop-Transcript | Out-Null
    exit 1
}
if (-not (Test-Path $rclone)) {
    Write-Host "ERRO: nao achei o rclone em $rclone. Baixe em rclone.org ou corrija o caminho."
    Stop-Transcript | Out-Null
    exit 1
}


# -----------------------------------------------------------------------------
# 2. BANCO: pg_dump dos schemas que sao do app.
# -----------------------------------------------------------------------------
#   -Fc          formato "custom": compactado, e na hora de restaurar da para
#                escolher so uma tabela ou so um schema.
#   -n public    as tabelas do app (registros_app, fotos_app, perfis_app...),
#                com funcoes, gatilhos e politicas de RLS.
#   -n auth      as contas de login. Sem isso ninguem entraria depois de uma
#                restauracao.
#   -n storage   a lista de arquivos do bucket (os arquivos vem no passo 4).
#   -w           nunca pergunta a senha: le do pgpass.conf. Se ela nao estiver
#                la, falha em vez de ficar parado esperando alguem digitar.
#   sslmode=require   conexao criptografada (o Supabase exige).
# Os outros schemas sao internos do Supabase e dariam erro de permissao.

$arquivoDoBanco = Join-Path $pastaBanco "rdo_$agora.dump"
$enderecoDoBanco = "postgresql://$usuarioDoBanco@${hostDoBanco}:5432/postgres?sslmode=require"

Write-Host ""
Write-Host "[1/3] Banco -> $arquivoDoBanco"
& $pgDump $enderecoDoBanco -w -Fc -n public -n auth -n storage -f $arquivoDoBanco

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: o pg_dump falhou (codigo $LASTEXITCODE). Veja a mensagem acima."
    $falhou = $true
}


# -----------------------------------------------------------------------------
# 3. CONFERENCIA DO BANCO: o arquivo abre e tem os dados das tabelas?
# -----------------------------------------------------------------------------
# O pg_restore --list le o arquivo sem restaurar nada. Cada tabela com dados
# aparece como uma linha "TABLE DATA". Se o arquivo estiver vazio ou cortado,
# nao aparece nenhuma.

if (-not $falhou) {
    $tamanhoKb = [math]::Round((Get-Item $arquivoDoBanco).Length / 1KB)
    $tabelas = (& $pgRestore --list $arquivoDoBanco | Select-String 'TABLE DATA').Count

    if ($tabelas -gt 0) {
        Write-Host "Banco ok: $tabelas tabelas com dados, $tamanhoKb KB."
    } else {
        Write-Host "ERRO: o arquivo do banco saiu sem dados ($tamanhoKb KB)."
        $falhou = $true
    }
}


# -----------------------------------------------------------------------------
# 4. FOTOS: copia o bucket para a pasta de rede.
# -----------------------------------------------------------------------------
#   copy         so traz o que e novo ou mudou e NUNCA apaga do backup. (O
#                "sync" apagaria do backup uma foto apagada no Supabase, e ai
#                nao daria para recupera-la.)
#   --transfers 8   baixa 8 fotos ao mesmo tempo.
#   --log-file      o detalhe de cada arquivo vai para um log separado.
# A primeira vez demora (traz todas); depois so vem as fotos novas.

$logDoRclone = Join-Path $pastaLogs "fotos_$agora.log"

Write-Host ""
Write-Host "[2/3] Fotos -> $pastaFotos"
& $rclone copy "${remotoRclone}:$bucketFotos" $pastaFotos --transfers 8 --log-file $logDoRclone --log-level INFO --stats-one-line --stats 0

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: o rclone falhou (codigo $LASTEXITCODE). Detalhes em $logDoRclone"
    $falhou = $true
} else {
    Write-Host "Fotos ok."
}


# -----------------------------------------------------------------------------
# 5. LIMPEZA: apaga os backups do banco e os logs mais velhos que N dias.
# -----------------------------------------------------------------------------
# So roda quando o backup de hoje deu certo: assim um problema que dure varios
# dias nunca apaga os ultimos backups bons.

Write-Host ""
Write-Host "[3/3] Limpeza (mais velhos que $diasParaGuardar dias)"
if (-not $falhou) {
    $limite = (Get-Date).AddDays(-$diasParaGuardar)
    $velhos = @(Get-ChildItem $pastaBanco -Filter '*.dump' | Where-Object LastWriteTime -lt $limite) +
              @(Get-ChildItem $pastaLogs -Filter '*.log' | Where-Object LastWriteTime -lt $limite)
    foreach ($arquivo in $velhos) {
        Remove-Item $arquivo.FullName
        Write-Host "Apagado: $($arquivo.Name)"
    }
    Write-Host "Limpeza ok ($($velhos.Count) arquivo(s))."
} else {
    Write-Host "Pulada: o backup de hoje teve erro, os antigos ficam."
}


# -----------------------------------------------------------------------------
# FIM: resumo e codigo de saida (0 = deu certo, 1 = algo falhou).
# -----------------------------------------------------------------------------

Write-Host ""
if ($falhou) {
    Write-Host "BACKUP COM ERRO. Log: $arquivoDeLog"
    Stop-Transcript | Out-Null
    exit 1
}
Write-Host "BACKUP CONCLUIDO. Log: $arquivoDeLog"
Stop-Transcript | Out-Null
exit 0
