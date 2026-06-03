# Paperclip — empresa human-less (CEO → CTO → Sêniores)

Runtime de orquestração para gerir os portfólios **Truther** (fintech/cripto, KYC/AML)
e **PSA** (integração ERP Sienge). Regra organizacional: **CEO e CTO só delegam, nunca
escrevem código**; a execução técnica cai em agentes sêniores. Tudo sob tutela do fundador.

## ⚠️ Pendências

### 1. Trava física do CTO (camada 3) — workspace READ-ONLY ("vejo, não edito")
Hoje o "CTO só delega, nunca escreve código" é só **instrução** (no `AGENTS.md` do CTO) — não
há barreira real: o adapter é `claude_local` com acesso total a arquivos/git, e `permissions`
só tem `canAssignTasks`/`canCreateAgents`. Já aconteceu de o CTO **executar** uma task (criou e
commitou SQL) ao receber "faça a correção" — corrigido por instrução (cláusula anti-override),
mas a regra ainda depende do modelo "se comportar".
- **Objetivo**: tornar IMPOSSÍVEL o CTO editar código — **sem** torná-lo cego. O CTO precisa
  continuar VENDO o código real (pra revisar arquitetura, diffs/PRs dos sêniores, escrever DoD
  preciso). O modelo é **read-only**: "entendo, vejo, mas não edito". NÃO é "remover o workspace"
  (isso o deixaria decidindo no escuro, menos técnico).
- **Caminho a investigar**: apontar o workspace do CTO para um mount **`:ro`** (mesmo mecanismo
  do `/seed/<projeto>`) — leitura total, `write`/`commit` bloqueados pelo SO. Sêniores seguem com
  a cópia gravável em `/work`. Avaliar como o Paperclip escopa workspace por agente
  (`projects.env` / `execution_workspace_policy`, e o cwd que o adapter recebe).
- **Ressalva a validar**: o Paperclip pode tentar escrever no `cwd` (worktree, logs, temp) e
  engasgar num diretório read-only — garantir que ele só LÊ ali e grava estado em outro lugar.

## Decisão: projeto fica no OneDrive (risco aceito)
O projeto vive em `OneDrive\Documentos\DIR_PATH\paperclip`. O `.env` (token do Claude + senha
do banco) e a pasta `backups\` **sincronizam pra nuvem** — risco **aceito pelo fundador**: a
estrutura está montada e NÃO deve ser movida. Não sugerir mover o projeto/`.env` pra fora do
OneDrive. (Se um dia quiser endurecer: rotacionar o token com `claude setup-token` + trocar a
senha do banco — mas é escolha do fundador, não pendência.)


## Workspace do projeto (decidido)
- **Escopo**: NÃO montar a pasta inteira. Apenas `<projeto>`.
- **Modelo (decidido): CÓPIA isolada — a pasta real NUNCA é tocada.**
  - Pasta real montada SOMENTE-LEITURA: `C:/.../DIR_PATH/<projeto>` → `/seed/<projeto>:ro`
    (escrita do agente é bloqueada pelo SO — verificado).
  - Cópia de trabalho num volume Docker (fora do OneDrive): `/work/<projeto>` (volume `paperclip_work`).
    O agente trabalha AQUI, in-place na cópia.
  - `node_modules` é excluído da cópia (o do host é Windows; quebra no Linux — o agente reinstala).
  - O remoto `origin` foi REMOVIDO da cópia → zero destino de push.
- **Paperclip**: projeto renomeado para `<projeto>`; apontar o cwd do workspace para
  **`/work/<projeto>`** (a cópia), NÃO para `/seed`.
- **Refresh da cópia** (quando o repo real mudar), rodar:
  `docker exec paperclip sh -c 'rm -rf /work/<projeto> && mkdir -p /work/<projeto> && tar -C /seed/<projeto> --exclude=node_modules -cf - . | tar -C /work/<projeto> -xf - && cd /work/<projeto> && git remote remove origin 2>/dev/null; true'`
- **Regra inegociável**: agentes **nunca fazem push** e só commitam na branch isolada da task.
  Cláusula no `/work/<projeto>/AGENTS.md` (tempo de execução) reforça.
- **Alerta**: a cópia inclui `.env` com segredos. Revisar/remover de `/work/<projeto>/.env`
  antes de soltar um sênior, se não quiser expor credenciais ao agente.

## Adicionar um projeto novo (espelho) — 3 passos
Todo projeto novo segue o mesmo modelo de CÓPIA isolada do userservice. Paths e senhas
vêm do `.env` (`${DIR_PATH}` para a pasta base).

1. **Mount `:ro` no `docker-compose.yml`** (serviço paperclip, em volumes):
   `- "${DIR_PATH}/<projeto>:/seed/<projeto>:ro"` e depois `docker compose up -d`.
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
- **Imagem própria (Dockerfile)**: `git` + Claude Code CLI + identidade git são instalados em
  BUILD-TIME (imagem `paperclip-runtime:latest`), não mais no `command` a cada restart. O
  serviço `paperclip` usa `build: .` no compose; o `command` virou só `npx -y paperclipai onboard`.
  Rebuild quando mudar o Dockerfile: `docker compose up -d --build paperclip`. (Atualizar o
  Claude Code = rebuild; o `RUN claude --version` no fim do Dockerfile falha o build se quebrar.)
- **Identidade git dos agentes**: `Vinícius Rodrigues <vinicius@truther.to>`, baked no Dockerfile
  via `git config --global` (sobrevive a recriação E ao refresh da cópia, que cai no global).
  Sem isso, commits saíam com a identidade herdada do `.git` copiado (ex.: o dev "FelpFreitas").
  Corrigir um commit já feito: `GIT_COMMITTER_NAME/EMAIL=... git commit --amend --author="..." --no-edit`.
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

## Backup e persistência
- **Dados moram em volumes Docker**, não na imagem/container: `paperclip_db` (Postgres),
  `paperclip_home` (`/root/.paperclip` + backups automáticos), `paperclip_work` (cópias).
  Rebuild/recriar container NÃO apaga nada. **Só `docker compose down -v` ou `docker volume rm`
  destroem.** Não trocar a versão MAIOR do Postgres (16→17) — o volume não abre em outro major.
- **Backup manual** (rodar antes de mexidas ousadas): `.\backup.ps1` → gera
  `backups\paperclip-<timestamp>.sql` (dump byte-exato via `pg_dump` no container + `docker cp`),
  com rotação (`-Keep N`, default 20). Não há wrapper automático no `up` — é manual, por escolha.
- **Restaurar**: `Get-Content .\backups\<arquivo>.sql | docker exec -i paperclip-db psql -U paperclip -d paperclip`.
- O Paperclip também faz backup automático interno (60min) em `/root/.paperclip/.../data/backups`,
  mas isso vive no mesmo volume — o `backup.ps1` tira a cópia pra FORA do Docker.

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
