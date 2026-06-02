# revisar.ps1 — Analisa o que o agente fez na CÓPIA isolada de um projeto (/work/<projeto>).
# Não toca em nada: só mostra branch, commits novos, arquivos e o diff completo.
#
# Uso:
#   .\revisar.ps1 -Projeto userservice
#   .\revisar.ps1 -Projeto data-rudder-provider -Base master
param(
  [Parameter(Mandatory = $true)][string]$Projeto,
  [string]$Base = "master",
  [string]$Container = "paperclip"
)
$Copy = "/work/$Projeto"

# valida que a copia existe
docker exec $Container sh -c "test -d '$Copy'" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "Copia '$Copy' nao existe. Rode: .\espelhar.ps1 -Projeto $Projeto"; exit 1 }

Write-Host "== Revisando '$Projeto' em $Copy (base: $Base) ==" -ForegroundColor Cyan

Write-Host "`n-- Branch atual da copia --" -ForegroundColor Yellow
docker exec $Container sh -c "cd $Copy && git rev-parse --abbrev-ref HEAD"

Write-Host "`n-- Commits novos ($Base..HEAD) --" -ForegroundColor Yellow
docker exec $Container sh -c "cd $Copy && git --no-pager log --oneline $Base..HEAD"

Write-Host "`n-- Arquivos alterados (resumo) --" -ForegroundColor Yellow
docker exec $Container sh -c "cd $Copy && git --no-pager diff --stat $Base...HEAD"

Write-Host "`n-- Mudancas ainda nao commitadas (se houver) --" -ForegroundColor Yellow
docker exec $Container sh -c "cd $Copy && git status --short"

Write-Host "`n-- Diff completo ($Base...HEAD) --" -ForegroundColor Yellow
docker exec $Container sh -c "cd $Copy && git --no-pager diff $Base...HEAD"

Write-Host "`nPara trazer pro repo real: .\puxar.ps1 -Projeto $Projeto   |   Para descartar: .\descartar.ps1 -Projeto $Projeto" -ForegroundColor Cyan
