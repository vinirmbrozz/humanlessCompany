# espelhar.ps1 — Cria (ou atualiza) a CÓPIA de trabalho isolada de um projeto no container.
#
# A pasta real entra SOMENTE-LEITURA como /seed/<projeto> (mount no docker-compose);
# este script gera a cópia em /work/<projeto>, exclui node_modules, remove o remoto git
# e carimba a identidade do fundador. O agente trabalha na cópia; a pasta real nunca é tocada.
#
# Pré-requisitos (uma vez por projeto):
#   1) No docker-compose.yml, em volumes do serviço paperclip:
#        - "${DIR_PATH}/<projeto>:/seed/<projeto>:ro"
#   2) docker compose up -d   (pra o /seed/<projeto> aparecer no container)
#
# Uso (a partir da raiz do repo):
#   .\scripts\espelhar.ps1 -Projeto data-rudder-provider             # cria a cópia
#   .\scripts\espelhar.ps1 -Projeto data-rudder-provider -Atualizar  # refresh (refaz do zero)
param(
  [Parameter(Mandatory = $true)][string]$Projeto,
  [switch]$Atualizar,
  [string]$Container = "paperclip",
  [string]$GitName  = "Vinícius Rodrigues",
  [string]$GitEmail = "vinicius@truther.to"
)
$ErrorActionPreference = "Stop"
$seed = "/seed/$Projeto"
$work = "/work/$Projeto"

function Inv($cmd) { docker exec $Container sh -c $cmd; if ($LASTEXITCODE -ne 0) { throw "Falhou no container: $cmd" } }

# 1) o seed (pasta real montada :ro) existe?
docker exec $Container sh -c "test -d '$seed'" | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Seed '$seed' nao existe no container. Garanta o mount no docker-compose (DIR_PATH/$Projeto -> /seed/$Projeto:ro) e rode 'docker compose up -d' antes."
}

# 2) a copia ja existe?
docker exec $Container sh -c "test -d '$work'" | Out-Null
$existe = ($LASTEXITCODE -eq 0)
if ($existe -and -not $Atualizar) { throw "A copia '$work' ja existe. Use -Atualizar para refaze-la do zero." }
if ($existe) { Write-Host "Removendo copia antiga ($work)..." -ForegroundColor Yellow; Inv "rm -rf '$work'" }

Write-Host "Criando copia $work a partir de $seed (sem node_modules)..." -ForegroundColor Cyan
Inv "mkdir -p '$work' && tar -C '$seed' --exclude=node_modules -cf - . | tar -C '$work' -xf -"

# Se o projeto tem git: remove o remoto (zero push) e carimba identidade.
# Se NÃO tem git (ex.: protocol-buffer): inicializa um 'master' baseline na cópia,
# pra o fluxo de branch/PR (revisar/puxar) funcionar.
Write-Host "Ajustando git da cópia (remoto/identidade ou init baseline)..." -ForegroundColor Cyan
Inv "cd '$work' && if [ -d .git ]; then git remote remove origin 2>/dev/null; git config user.name '$GitName'; git config user.email '$GitEmail'; else git init -b master >/dev/null 2>&1; git config user.name '$GitName'; git config user.email '$GitEmail'; git add -A; git commit -q -m 'chore: baseline (snapshot via espelhar)'; fi; true"

$branch  = (docker exec $Container sh -c "cd '$work' && git rev-parse --abbrev-ref HEAD 2>/dev/null")
$remotes = (docker exec $Container sh -c "cd '$work' && git remote")
Write-Host "`n== Pronto ==" -ForegroundColor Green
Write-Host "  copia:   $work"
Write-Host "  branch:  $(($branch | Out-String).Trim())"
Write-Host "  remotos: $(if ($remotes) { ($remotes | Out-String).Trim() } else { '(nenhum)' })"
Write-Host "`nNo Paperclip, aponte o cwd do workspace deste projeto para: $work" -ForegroundColor Cyan
