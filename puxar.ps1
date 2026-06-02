# puxar.ps1 — Puxa o trabalho do agente (da CÓPIA) para o seu repo REAL, numa branch nova.
# Gera um patch dos commits da cópia (base..HEAD), copia pro host de forma byte-exata
# (docker cp, sem problema de encoding) e aplica com 'git am' numa branch isolada.
# Sua master e sua árvore de trabalho não são tocadas: tudo cai na branch nova.
#
# Uso:
#   .\puxar.ps1 -Projeto userservice
#   .\puxar.ps1 -Projeto data-rudder-provider -Base master -LocalBranch feat/x
#   .\puxar.ps1 -Projeto userservice -Force            # aplica mesmo com árvore suja
param(
  [Parameter(Mandatory = $true)][string]$Projeto,
  [string]$Base = "master",
  [string]$LocalBranch = "revisao-agente",
  [switch]$Force,
  [string]$Container = "paperclip"
)
$ErrorActionPreference = "Stop"

function Invoke-Git { & git @args; if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') falhou (exit $LASTEXITCODE)" } }

$Copy  = "/work/$Projeto"
$repo  = Join-Path (Split-Path $PSScriptRoot -Parent) $Projeto
$patch = Join-Path $PSScriptRoot "$Projeto-changes.patch"

if (-not (Test-Path $repo)) { throw "Repo real nao encontrado em: $repo" }
docker exec $Container sh -c "test -d '$Copy'" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Copia '$Copy' nao existe. Rode: .\espelhar.ps1 -Projeto $Projeto" }

Write-Host "== [$Projeto] Gerando patch da copia ($Base..HEAD) ==" -ForegroundColor Cyan
docker exec $Container sh -c "cd $Copy && git format-patch $Base --stdout > /tmp/uschanges.patch"
if ($LASTEXITCODE -ne 0) { throw "Falha ao gerar o patch dentro do container." }
docker cp "${Container}:/tmp/uschanges.patch" $patch | Out-Null

if (-not (Test-Path $patch) -or (Get-Item $patch).Length -eq 0) {
  Write-Warning "Patch vazio: nao ha commits novos sobre '$Base'. (O agente pode nao ter commitado — rode .\revisar.ps1 -Projeto $Projeto.)"
  return
}
Write-Host "Patch salvo: $patch ($((Get-Item $patch).Length) bytes)" -ForegroundColor Green

Push-Location $repo
try {
  $dirty = git status --porcelain
  if ($dirty -and -not $Force) {
    Write-Warning "Seu repo real '$Projeto' tem mudancas nao commitadas. Commite/stashe antes, ou rode com -Force."
    Write-Host $dirty
    return
  }

  git show-ref --verify --quiet "refs/heads/$LocalBranch"
  if ($LASTEXITCODE -eq 0) {
    throw "A branch '$LocalBranch' ja existe em '$Projeto'. Use outro nome (-LocalBranch) ou rode .\descartar.ps1 -Projeto $Projeto primeiro."
  }

  Write-Host "== Criando branch '$LocalBranch' e aplicando o patch ==" -ForegroundColor Cyan
  Invoke-Git checkout -b $LocalBranch
  Invoke-Git am $patch
  Write-Host "`nOK. Trabalho aplicado em '$repo' na branch '$LocalBranch'." -ForegroundColor Green
  Write-Host "Se APROVAR: git checkout master; git merge $LocalBranch" -ForegroundColor Cyan
  Write-Host "Se REJEITAR: .\descartar.ps1 -Projeto $Projeto -LocalBranch $LocalBranch" -ForegroundColor Cyan
}
finally { Pop-Location }
