# backup.ps1 — Dump do banco do Paperclip para um arquivo .sql em paperclip\backups\.
# Usa pg_dump via conexão local do container (não precisa de senha). Faz rotação.
#
# Uso (a partir da raiz do repo):
#   .\scripts\backup.ps1                 # dump + mantém os 20 mais recentes
#   .\scripts\backup.ps1 -Keep 50        # mantém os 50 mais recentes
#
# Restaurar (cuidado, sobrescreve dados):
#   Get-Content .\backups\paperclip-YYYYMMDD-HHmmss.sql | docker exec -i paperclip-db psql -U paperclip -d paperclip
param(
  [string]$Container = "paperclip-db",
  [string]$User = "paperclip",
  [string]$Db = "paperclip",
  [int]$Keep = 20,
  [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "backups")
)
$ErrorActionPreference = "Stop"

# banco está rodando?
$running = (docker inspect -f '{{.State.Running}}' $Container 2>$null)
if ($running -ne 'true') { Write-Warning "Container '$Container' nao esta rodando — backup PULADO."; return }

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$file  = Join-Path $OutDir "paperclip-$stamp.sql"

Write-Host "Gerando dump do banco '$Db'..." -ForegroundColor Cyan
docker exec $Container pg_dump -U $User -d $Db -f /tmp/pc_dump.sql
if ($LASTEXITCODE -ne 0) { throw "pg_dump falhou (exit $LASTEXITCODE)." }
docker cp "${Container}:/tmp/pc_dump.sql" $file | Out-Null
docker exec $Container rm -f /tmp/pc_dump.sql | Out-Null

$sizeKB = [math]::Round((Get-Item $file).Length / 1KB, 1)
Write-Host "Backup salvo: $file ($sizeKB KB)" -ForegroundColor Green

# rotação: mantém os $Keep mais recentes
$antigos = Get-ChildItem $OutDir -Filter "paperclip-*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep
if ($antigos) { $antigos | Remove-Item -Force; Write-Host "Rotacao: $($antigos.Count) backup(s) antigo(s) removido(s) (mantendo $Keep)." -ForegroundColor DarkGray }
