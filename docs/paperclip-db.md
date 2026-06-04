# Paperclip por dentro — banco e instruções dos agentes

> Conhecimento descoberto inspecionando o Postgres do Paperclip. Útil pra operar/depurar,
> mas mexer direto no banco vivo pode confundir o estado dele — preferir a UI quando der.

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
- Editar com backup (escrever no host e copiar pro container):
  ```
  docker exec paperclip sh -c "cp '<path>/AGENTS.md' '<path>/AGENTS.md.bak'"
  docker cp novo_AGENTS.md paperclip:'<path>/AGENTS.md'
  ```
- Vale no PRÓXIMO heartbeat do agente (o adapter relê o arquivo). Não precisa reiniciar.
- ⚠️ Por ser `managed`, há risco (baixo) de uma re-sync sobrescrever. Conferir na web; se
  reverter, restaurar do `.bak`.

## Regras de negócio do banco (descobertas)

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
  - Estratégia padrão: `mode=shared_workspace`, `strategy_type=project_primary`, **sem branch
    isolada** → o agente edita IN-PLACE no `cwd` (por isso a cópia `/work`, não a pasta real).
- **Execução/heartbeat**: `heartbeat_runs`, `heartbeat_run_events`, `agent_wakeup_requests`,
  `agent_runtime_state`. `runtime_config.heartbeat.enabled=false` + `wakeOnDemand=true`
  = agente acorda sob demanda (sem timer).
- **DELETE de agente é trabalhoso** (sem cascade geral): ~47 colunas FK apontam pra `agents`.
  Para um agente novo (só rastro de runtime/log), a ordem segura numa transação é:
  `activity_log` (por `agent_id` E por `run_id` dos runs dele) → `heartbeat_run_events` →
  `heartbeat_runs` → `agent_wakeup_requests` → `agent_runtime_state` → `agents`.
  Atenção à dependência circular `heartbeat_runs.wakeup_request_id → agent_wakeup_requests`
  (apagar os runs ANTES dos wakeups). **Preferir deletar pela UI quando possível.**

## IDs de referência

- company `207d7642-8a17-4ee7-8fbb-f63b9da66153`
- projeto user-service `7b13cef6-b2ee-4ae5-9844-412e192cbe88`
- CTO `002e59ca-a963-44ba-891e-cab9fee6d229`
