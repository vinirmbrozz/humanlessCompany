# Operação — setup, banco, backup e scripts

## Subir / rebuild

- Subida normal (rápida, imagem já construída): `docker compose up -d`
- Rebuild da imagem (mudou o `Dockerfile` ou atualizar o Claude Code): `docker compose up -d --build paperclip`
- App em http://localhost:3100

## Notas de setup já aplicadas

- **DB externo**: serviço `postgres:16` via `DATABASE_URL`, em vez do Postgres embutido
  (o embutido recusa rodar como root no container).
- **Segredos no `.env` (não no compose)**: o `docker-compose.yml` usa `${POSTGRES_USER}`,
  `${POSTGRES_PASSWORD}`, `${POSTGRES_DB}` e `${DIR_PATH}` (interpolação que o `docker compose`
  lê do `.env`). A senha vive só no `.env`; o `DATABASE_URL` é montado a partir das vars.
  Verificar com `docker compose config`.
  ⚠️ **Trocar `POSTGRES_PASSWORD` no `.env` NÃO muda a senha de um banco já existente**
  (só vale na 1ª init de volume vazio) — é preciso aplicar no banco vivo:
  `docker exec -i paperclip-db psql -U paperclip -d paperclip -c "ALTER USER paperclip PASSWORD '<nova>';"`
  e depois `docker compose up -d` pra recriar o paperclip com o novo `DATABASE_URL`.
- **Imagem própria (Dockerfile)**: `git` + Claude Code CLI (`claude`) + Codex CLI (`codex`) +
  identidade git são instalados em BUILD-TIME (imagem `paperclip-runtime:latest`), não mais no
  `command` a cada restart. O serviço `paperclip` usa `build: .`; o `command` virou só
  `npx -y paperclipai onboard`. O `RUN claude --version && codex --version` no fim do Dockerfile
  falha o build se algum CLI quebrar.
- **Runtimes de agente** (escolhidos por agente no campo `adapter_type`):
  - `claude_local` — Claude Code. Auth: `CLAUDE_CODE_OAUTH_TOKEN` (assinatura) ou `ANTHROPIC_API_KEY`.
    Bypass de root via `IS_SANDBOX=1`.
  - `codex_local` — Codex CLI (OpenAI). Auth: `OPENAI_API_KEY` (sk-proj-…, billing por token).
    Bypass de root via `CODEX_LOCAL_BYPASS_APPROVALS_AND_SANDBOX=1`. ⛔ hoje OFFLINE (cota OpenAI).
  - `gemini_local` — Gemini CLI (Google, `@google/gemini-cli`). Auth: `GEMINI_API_KEY` (env direto,
    sem login). Precisa de `GEMINI_CLI_TRUST_WORKSPACE=true` (senão o CLI pede trust em headless).
    ✅ testado e funcionando.
  - (a imagem tb traz adapters para grok/cursor — não configurados.)
  Para usar Codex: criar/editar o agente na UI escolhendo o adapter **Codex** (`codex_local`).
  ⚠️ No 1º run o adapter faz um "hello probe" de auth — se a key for inválida/sem crédito, falha aí.
- **Identidade git dos agentes**: `Vinícius Rodrigues <vinicius@truther.to>`, baked no Dockerfile
  via `git config --global` (sobrevive a recriação E ao refresh da cópia, que cai no global).
  Sem isso, commits saíam com a identidade herdada do `.git` copiado (ex.: o dev "FelpFreitas").
  Corrigir um commit já feito: `GIT_COMMITTER_NAME/EMAIL=... git commit --amend --author="..." --no-edit`.
- **Root + sandbox**: container roda como root; `IS_SANDBOX=1` permite que o adapter
  `claude_local` use `--dangerously-skip-permissions` como root.
- **Acesso a repos**: os agentes NÃO têm acesso ao filesystem do fundador. Projetos são
  registrados sob critério do fundador (protocolo: o CTO pede, o fundador concede).

## Acesso ao Postgres (DBeaver)

- Serviço `db` (container `paperclip-db`, image `postgres:16`) é o banco do Paperclip.
- Porta publicada no host: `127.0.0.1:5433:5432`. Conexão DBeaver:
  Host `localhost` · Port `5433` · Database `paperclip` · User/Password = valores do `.env`.
- O Paperclip usa internamente `db:5432` (rede docker) — expor a 5433 não afeta isso.
- CLI rápido: `docker exec -i paperclip-db psql -U paperclip -d paperclip`
  (use SEMPRE `-i` ao mandar SQL via heredoc — sem ele o stdin não chega no psql).
- ⚠️ É o banco VIVO do Paperclip — editar dados direto pode confundir o estado dele.

## Backup e persistência

- **Dados moram em volumes Docker**, não na imagem/container: `paperclip_db` (Postgres),
  `paperclip_home` (`/root/.paperclip` + backups automáticos), `paperclip_work` (cópias).
  Rebuild/recriar container NÃO apaga nada. **Só `docker compose down -v` ou `docker volume rm`
  destroem.** Não trocar a versão MAIOR do Postgres (16→17) — o volume não abre em outro major.
- **Backup manual**: `.\scripts\backup.ps1` → gera `backups\paperclip-<timestamp>.sql`
  (dump byte-exato via `pg_dump` + `docker cp`), com rotação (`-Keep N`, default 20).
- **Restaurar**:
  `Get-Content .\backups\<arquivo>.sql | docker exec -i paperclip-db psql -U paperclip -d paperclip`.
- O Paperclip também faz backup automático interno (60min) dentro do volume `paperclip_home`;
  o `backup.ps1` tira a cópia pra FORA do Docker.

## Scripts (todos em `scripts\`, exigem `-Projeto <nome>` exceto backup)

| Script | Função |
|---|---|
| `espelhar.ps1 -Projeto <p>` | cria/atualiza (`-Atualizar`) a cópia isolada em `/work/<p>` |
| `revisar.ps1 -Projeto <p>` | mostra o diff do que o agente fez (read-only) |
| `puxar.ps1 -Projeto <p>` | traz o trabalho pra uma branch nova do repo real (via patch) |
| `descartar.ps1 -Projeto <p>` | apaga a branch (`-AlsoCopy` limpa a cópia também) |
| `backup.ps1` | dump do banco pra `backups\` |
