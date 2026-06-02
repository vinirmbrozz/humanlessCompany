# Paperclip — empresa human-less (CEO → CTO → Sêniores)

Runtime de orquestração para gerir os portfólios **Truther** (fintech/cripto, KYC/AML)
e **PSA** (integração ERP Sienge). Regra organizacional: **CEO e CTO só delegam, nunca
escrevem código**; a execução técnica cai em agentes sêniores. Tudo sob tutela do fundador.

## ⚠️ Pendências importantes (resolver depois)

### 1. Segredo no OneDrive
O arquivo `.env` contém o `CLAUDE_CODE_OAUTH_TOKEN` e está dentro de
`OneDrive\Documentos\Truther\paperclip`, ou seja, **o token sincroniza pra nuvem**.
- Ação recomendada: mover o projeto `paperclip/` para fora do OneDrive (ex.: `C:\paperclip`)
  e/ou usar um gerenciador de segredos.
- O token atual já foi exposto em texto plano → **rotacionar** quando for endereçar isso
  (gerar novo com `claude setup-token` e substituir no `.env`).

### 2. Bootstrap pesado a cada restart
Hoje o `docker-compose.yml` instala `git` + `@anthropic-ai/claude-code` via `apt-get`/`npm`
no `command`, então **roda a cada restart do container** (lento).
- Ação recomendada: trocar por um **Dockerfile** próprio que instala `git` e o Claude Code
  em build-time (sobe rápido, reproduzível).

## Workspace do projeto userservice (decidido)
- **Escopo**: NÃO montar a pasta Truther inteira. Apenas `userservice`.
- **Modelo (decidido): CÓPIA isolada — a pasta real NUNCA é tocada.**
  - Pasta real montada SOMENTE-LEITURA: `C:/.../Truther/userservice` → `/seed/userservice:ro`
    (escrita do agente é bloqueada pelo SO — verificado).
  - Cópia de trabalho num volume Docker (fora do OneDrive): `/work/userservice` (volume `paperclip_work`).
    O agente trabalha AQUI, in-place na cópia.
  - `node_modules` é excluído da cópia (o do host é Windows; quebra no Linux — o agente reinstala).
  - O remoto `origin` foi REMOVIDO da cópia → zero destino de push.
- **Paperclip**: projeto renomeado para `user-service`; apontar o cwd do workspace para
  **`/work/userservice`** (a cópia), NÃO para `/seed`.
- **Refresh da cópia** (quando o repo real mudar), rodar:
  `docker exec paperclip sh -c 'rm -rf /work/userservice && mkdir -p /work/userservice && tar -C /seed/userservice --exclude=node_modules -cf - . | tar -C /work/userservice -xf - && cd /work/userservice && git remote remove origin 2>/dev/null; true'`
- **Regra inegociável**: agentes **nunca fazem push** e só commitam na branch isolada da task.
  Cláusula no `/work/userservice/AGENTS.md` (tempo de execução) reforça.
- **Alerta**: a cópia inclui `.env` com segredos. Revisar/remover de `/work/userservice/.env`
  antes de soltar um sênior, se não quiser expor credenciais ao agente.

## Adicionar um projeto novo (espelho) — 3 passos
Todo projeto novo segue o mesmo modelo de CÓPIA isolada do userservice. Paths e senhas
vêm do `.env` (`${TRUTHER_DIR}` para a pasta base).

1. **Mount `:ro` no `docker-compose.yml`** (serviço paperclip, em volumes):
   `- "${TRUTHER_DIR}/<projeto>:/seed/<projeto>:ro"` e depois `docker compose up -d`.
2. **Criar a cópia de trabalho** em `/work/<projeto>` (passo fácil de esquecer — sem ele a
   criação de issue dá 422 porque o cwd não existe):
   `.\espelhar.ps1 -Projeto <projeto>`   (refresh: `.\espelhar.ps1 -Projeto <projeto> -Atualizar`)
   O script copia (sem `node_modules`), remove o remoto git e carimba a identidade do fundador.
3. **No Paperclip**: criar/configurar o projeto e apontar o **cwd do workspace** para
   `/work/<projeto>` (NÃO `/seed`).

Revisão/integração do trabalho do agente (todos exigem `-Projeto <nome>`):
`.\revisar.ps1 -Projeto <p>` (ver o diff), `.\puxar.ps1 -Projeto <p>` (trazer pra branch nova
do repo real), `.\descartar.ps1 -Projeto <p>` (apagar a branch; `-AlsoCopy` limpa a cópia).

## Notas de setup já aplicadas
- **DB externo**: usa serviço `postgres:16` via `DATABASE_URL` em vez do Postgres embutido
  (o embutido recusa rodar como root no container).
- **Segredos no `.env` (não no compose)**: o `docker-compose.yml` usa `${POSTGRES_USER}`,
  `${POSTGRES_PASSWORD}`, `${POSTGRES_DB}` (interpolação que o `docker compose` lê do `.env`).
  A senha vive só no `.env`; o `DATABASE_URL` é montado a partir das vars. Verificar com
  `docker compose config`. ⚠️ **Trocar `POSTGRES_PASSWORD` no `.env` NÃO muda a senha de um
  banco já existente** (só vale na 1ª init de volume vazio) — é preciso aplicar no banco vivo:
  `docker exec -i paperclip-db psql -U paperclip -d paperclip -c "ALTER USER paperclip PASSWORD '<nova>';"`
  e depois `docker compose up -d` pra recriar o paperclip com o novo DATABASE_URL.
- **Auth do Claude**: assinatura via `CLAUDE_CODE_OAUTH_TOKEN` (headless), no `.env`.
- **Identidade git dos agentes**: setada como `Vinícius Rodrigues <vinicius@truther.to>`
  via `git config --global` dentro do container (sobrevive ao refresh da cópia) E no bootstrap
  do `docker-compose.yml` (sobrevive à recriação do container). Sem isso, commits saíam com a
  identidade herdada do `.git` copiado (ex.: o dev original "FelpFreitas"). Para corrigir um
  commit já feito: `GIT_COMMITTER_NAME/EMAIL=... git commit --amend --author="..." --no-edit`.
- **Root + sandbox**: container roda como root; `IS_SANDBOX=1` permite que o adapter
  `claude-local` use `--dangerously-skip-permissions` como root.
- **Acesso a repos**: os agentes NÃO têm acesso ao filesystem do fundador. Projetos das
  pastas serão registrados no Paperclip sob critério do fundador (protocolo: o CTO pede,
  o fundador concede).

## Acesso ao Postgres (DBeaver)
- O serviço `db` (container `paperclip-db`, image `postgres:16`) é o banco do Paperclip.
- Porta publicada no host pelo `docker-compose.yml`: `5433:5432`. Conexão no DBeaver:
  Host `localhost` · Port `5433` · Database `paperclip` · User `paperclip` · Password `paperclip`.
- O Paperclip usa internamente `db:5432` (rede docker) — expor a 5433 não afeta isso.
- Aplicar mudança na porta: `docker compose up -d db`. Verificar: `docker port paperclip-db`.
- Endurecer (só loopback): trocar o mapeamento para `127.0.0.1:5433:5432`.
- Acesso rápido por CLI (sem DBeaver): `docker exec -i paperclip-db psql -U paperclip -d paperclip`
  (use SEMPRE `-i` quando mandar SQL via heredoc — sem ele o stdin não chega no psql).
- ⚠️ É o banco VIVO do Paperclip — editar dados direto pode confundir o estado dele.

## Como alterar as instruções (AGENTS.md) de um agente
- As instruções de cada agente são um ARQUIVO no volume do container (não no host):
  `/root/.paperclip/instances/default/companies/<COMPANY_ID>/agents/<AGENT_ID>/instructions/AGENTS.md`
  (alguns agentes têm bundle maior: + `SOUL.md`, `HEARTBEAT.md`, `TOOLS.md` — caso do CEO).
- O caminho exato fica em `adapterConfig.instructionsFilePath`; o modo é
  `instructionsBundleMode: managed` (Paperclip é "dono" do bundle — por isso a UI não deixa editar livre).
- O texto completo das instruções mora SÓ no arquivo: no banco há apenas o path + um
  `capabilities` curto. Logo, **editar o arquivo muda o agente de verdade** e deve refletir na web.
- Achar o arquivo de um agente:
  `docker exec paperclip sh -c 'find /root/.paperclip -ipath "*agents/<AGENT_ID>*" -name AGENTS.md'`
- Editar com backup (escrever o novo conteúdo num arquivo no host e copiar pro container):
  ```
  docker exec paperclip sh -c "cp '<path>/AGENTS.md' '<path>/AGENTS.md.bak'"
  docker cp novo_AGENTS.md paperclip:'<path>/AGENTS.md'
  ```
- Vale no PRÓXIMO heartbeat do agente (o adapter relê o arquivo). Não precisa reiniciar nada.
- ⚠️ Por ser `managed`, há risco (baixo) de uma re-sync sobrescrever. Conferir na web depois;
  se reverter, restaurar do `.bak`.

## Regras de negócio do banco do Paperclip (descobertas)
- **Org chart = tabela `agents`**: `role` (ceo/cto/engineer), `reports_to` (hierarquia),
  `status` (idle/terminated/…), `permissions` jsonb (`canAssignTasks`, `canCreateAgents`),
  `adapter_type` (`claude_local`), `capabilities` (texto curto). NÃO existe `archived_at` —
  "remover" agente é `status=terminated` (soft) ou `DELETE` (hard).
- **Trabalho = tabela `issues`**: hierarquia por `parent_id` (child issue = delegação),
  `assignee_agent_id`, `created_by_agent_id`, `status`, `identifier` (ROD-N). Comentários em
  `issue_comments` (`author_agent_id`; comentário feito por humano vem com autor nulo).
- **Código do projeto = `project_workspaces`** (1 projeto → N workspaces): `source_type`
  (default `local_path`), `cwd`, `repo_url`/`repo_ref`, `is_primary`, `setup_command`.
  Execuções concretas em `execution_workspaces`: `cwd`, `strategy_type`, `branch_name`,
  `base_ref`, `provider_type` (`local_fs`).
  - **Estratégia padrão observada**: `mode=shared_workspace`, `strategy_type=project_primary`,
    **sem branch isolada** → o agente edita IN-PLACE no `cwd`. (Por isso usamos a cópia
    `/work/userservice` em vez de apontar o cwd pra pasta real.)
- **Execução/heartbeat**: `heartbeat_runs`, `heartbeat_run_events`, `agent_wakeup_requests`,
  `agent_runtime_state`. `runtime_config.heartbeat.enabled=false` + `wakeOnDemand=true`
  = agente acorda sob demanda (sem timer).
- **DELETE de agente é trabalhoso** (sem cascade geral): ~47 colunas FK apontam pra `agents`.
  Para um agente novo (só rastro de runtime/log), a ordem segura numa transação é:
  `activity_log` (por `agent_id` E por `run_id` dos runs dele) → `heartbeat_run_events` →
  `heartbeat_runs` → `agent_wakeup_requests` → `agent_runtime_state` → `agents`.
  Atenção à dependência circular `heartbeat_runs.wakeup_request_id → agent_wakeup_requests`
  (apagar os runs ANTES dos wakeups). **Preferir deletar pela UI quando possível.**
- **IDs de referência**: company `207d7642-8a17-4ee7-8fbb-f63b9da66153`;
  projeto user-service `7b13cef6-b2ee-4ae5-9844-412e192cbe88`;
  CTO `002e59ca-a963-44ba-891e-cab9fee6d229`.
