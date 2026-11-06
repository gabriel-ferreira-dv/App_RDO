<#
Copia a estrutura do banco de produção do Supabase (sem dados) para
supabase\.temp\estrutura. Foi daí que saiu a migration inicial. Só lê o banco.

Antes, uma vez:
  npx supabase login
  npx supabase link --project-ref lsrjjyybcvszuxksruqm

Uso:
  .\scripts\copiar_estrutura_do_banco.ps1
#>
param(
    [string]$PastaDoPostgres = "C:\Program Files\PostgreSQL\17\bin"
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path $PSScriptRoot -Parent
$saida = Join-Path $raiz "supabase\.temp\estrutura"
$arquivoDoPooler = Join-Path $raiz "supabase\.temp\pooler-url"
$consultas = Join-Path $PSScriptRoot "estrutura_do_banco.sql"

foreach ($exe in @("pg_dump.exe", "psql.exe")) {
    if (-not (Test-Path (Join-Path $PastaDoPostgres $exe))) {
        throw "Não achei $exe em $PastaDoPostgres."
    }
}
if (-not (Test-Path $arquivoDoPooler)) {
    throw "Falta $arquivoDoPooler. Rode antes: npx supabase link --project-ref lsrjjyybcvszuxksruqm"
}

# o link grava o endereço do pooler sem a senha
$url = (Get-Content $arquivoDoPooler -Raw).Trim()
if ($url -notmatch '^postgres(ql)?://([^@:/]+)(:[^@]*)?@([^:/]+):(\d+)/([\w-]+)') {
    throw "Endereço inesperado em $arquivoDoPooler."
}
$usuario = $Matches[2]
$servidor = $Matches[4]
$porta = $Matches[5]
$banco = $Matches[6]
$conexao = @("-h", $servidor, "-p", $porta, "-U", $usuario, "-d", $banco)

# esquemas que o próprio Supabase cria
$esquemasDoSupabase = @(
    "auth", "storage", "extensions", "graphql", "graphql_public", "realtime",
    "_realtime", "_analytics", "_supavisor", "supabase_functions",
    "supabase_migrations", "pgbouncer", "pgsodium", "pgsodium_masks", "vault",
    "net", "cron", "pgtle", "dbdev", "tiger", "tiger_data", "topology",
    "information_schema", "pg_*"
)
$foraDoDump = $esquemasDoSupabase | ForEach-Object { "--exclude-schema=$_" }

$senhaSegura = Read-Host "Senha do banco ($usuario em $servidor)" -AsSecureString
$ponteiro = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senhaSegura)
try {
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ponteiro)
    $env:PGSSLMODE = "require"
    $env:PGCLIENTENCODING = "UTF8"
    New-Item -ItemType Directory -Force $saida | Out-Null

    Write-Host "Copiando a estrutura..."
    & (Join-Path $PastaDoPostgres "pg_dump.exe") @conexao --schema-only --no-owner `
        --quote-all-identifiers @foraDoDump -f (Join-Path $saida "esquema.sql")
    if ($LASTEXITCODE -ne 0) { throw "O pg_dump falhou (código $LASTEXITCODE)." }

    Write-Host "Copiando policies do storage, trigger do auth e buckets..."
    & (Join-Path $PastaDoPostgres "psql.exe") @conexao -X -q -A -t `
        -v ON_ERROR_STOP=1 -f $consultas -o (Join-Path $saida "extra.sql")
    if ($LASTEXITCODE -ne 0) { throw "O psql falhou (código $LASTEXITCODE)." }

    Write-Host "Pronto, ficou em $saida"
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ponteiro)
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:PGSSLMODE -ErrorAction SilentlyContinue
    Remove-Item Env:PGCLIENTENCODING -ErrorAction SilentlyContinue
}
