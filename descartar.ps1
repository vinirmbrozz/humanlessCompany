# descartar.ps1 — Rejeita o trabalho do agente: apaga a branch local que voce puxou.
# Sua master e sua pasta ficam intactas. Se um 'git am' tiver ficado pela metade, aborta ele.
# Com -AlsoCopy, tambem reseta a CÓPIA no container de volta para a base.
#
# Uso:
#   .\descartar.ps1 -Projeto userservice
#   .\descartar.ps1 -Projeto data-rudder-provider -LocalBranch feat/x
#   .\descartar.ps1 -Projeto userservice -AlsoCopy        # tambem limpa a copia (/work)
param(
  [Parameter(Mandatory = $true)][string]$Projeto,
  [string]$LocalBranch = "revisao-agente",
  [switch]$AlsoCopy,
  [string]$Base = "master",
  [string]$Container = "paperclip"
)
$ErrorActionPreference = "Stop"

$repo = Join-Path (Split-Path $PSScriptRoot -Parent) $Projeto
$Copy = "/work/$Projeto"
if (-not (Test-Path $repo)) { throw "Repo real nao encontrado em: $repo" }

Push-Location $repo
try {
  if (Test-Path ".git/rebase-apply") {
    Write-Host "Abortando 'git am' inacabado..." -ForegroundColor Yellow
    git am --abort 2>$null
  }

  $cur = (git rev-parse --abbrev-ref HEAD).Trim()
  if ($cur -eq $LocalBranch) {
    Write-Host "Saindo de '$LocalBranch' -> '$Base'" -ForegroundColor Yellow
    git checkout $Base
    if ($LASTEXITCODE -ne 0) { throw "Nao consegui sair para '$Base'. Resolva a arvore antes." }
  }

  git show-ref --verify --quiet "refs/heads/$LocalBranch"
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "A branch '$LocalBranch' nao existe em '$Projeto'. Nada a apagar aqui."
  } else {
    git branch -D $LocalBranch
    Write-Host "Branch '$LocalBranch' apagada de '$Projeto'. Master e pasta intactos." -ForegroundColor Green
  }
}
finally { Pop-Location }

# limpa o patch gerado pelo puxar.ps1, se existir
$patch = Join-Path $PSScriptRoot "$Projeto-changes.patch"
if (Test-Path $patch) { Remove-Item $patch; Write-Host "Patch temporario removido." -ForegroundColor DarkGray }

if ($AlsoCopy) {
  Write-Host "== Limpando a copia $Copy de volta para '$Base' ==" -ForegroundColor Cyan
  docker exec $Container sh -c "cd $Copy && git checkout -- . 2>/dev/null; git checkout $Base && git reset --hard $Base"
  if ($LASTEXITCODE -ne 0) { Write-Warning "Nao consegui resetar a copia automaticamente (branch checada fora de $Base?)." }
  else { Write-Host "Copia resetada para '$Base'. Trabalho do agente descartado tambem na copia." -ForegroundColor Green }
}
