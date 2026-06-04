# Paperclip — empresa human-less (CEO → CTO → Sêniores)

> **Fonte única de instruções deste repositório.** Lida nativamente pelo Codex e por outros
> agentes; o Claude Code chega aqui via `CLAUDE.md` (que só importa este arquivo com `@AGENTS.md`).
> Mantenha a verdade AQUI — não duplique em outro doc.

Runtime de orquestração de agentes de IA para os portfólios **Truther** (fintech/cripto, KYC/AML)
e **PSA** (integração ERP Sienge). Modela uma empresa *human-less*: **CEO → CTO → Engenheiros
Sêniores**, onde CEO e CTO **só delegam** — a execução técnica fica com os sêniores, sob tutela
do fundador.

## Regras críticas (valem para qualquer agente)

- **CEO e CTO só delegam, nunca escrevem código.** Pedido de implementação vira child issue
  para o sênior — mesmo que a ordem direta diga "faça/corrija/implemente".
- **Agentes nunca fazem push** e só commitam na branch isolada da task. O fundador decide o merge.
- **A pasta real do projeto nunca é editada.** O agente trabalha numa CÓPIA (`/work/<projeto>`);
  a pasta real entra somente-leitura (`/seed/<projeto>`). Ver [docs/arquitetura.md](docs/arquitetura.md).
- **Runtime real = Claude Code** (`@anthropic-ai/claude-code`, `CLAUDE_CODE_OAUTH_TOKEN`,
  adapter `claude_local`). Docs devem descrever isso; se algum texto disser "Codex" como se fosse
  a infra, é engano de conversão — corrigir para Claude.

## Mapa do repositório

| Caminho | O que é |
|---|---|
| [README.md](README.md) | Onboarding humano (pré-requisitos, início rápido, diagrama) |
| `AGENTS.md` (este) | Fonte única de instruções de agente + índice |
| `CLAUDE.md` | Ponteiro `@AGENTS.md` (pro Claude Code carregar isto) |
| [docs/arquitetura.md](docs/arquitetura.md) | Modelo de cópia isolada, adicionar projeto, fluxo de PR |
| [docs/operacao.md](docs/operacao.md) | Subir/rebuild, setup, Postgres/DBeaver, backup, scripts |
| [docs/paperclip-db.md](docs/paperclip-db.md) | Regras do banco, editar AGENTS.md de um agente, IDs |
| `scripts/` | `espelhar` · `revisar` · `puxar` · `descartar` · `backup` (PowerShell) |
| `docker-compose.yml` · `Dockerfile` · `.env` | Infra (segredos no `.env`, imagem própria) |

## ⚠️ Pendências

### 1. Trava física do CTO (camada 3) — workspace READ-ONLY ("vejo, não edito")
Hoje o "CTO só delega, nunca escreve código" é só **instrução** — não há barreira real: o adapter
`claude_local` tem acesso total a arquivos/git e `permissions` só tem `canAssignTasks`/`canCreateAgents`.
Já aconteceu de o CTO **executar** (criou e commitou SQL) ao receber "faça a correção" — corrigido
por instrução (cláusula anti-override), mas ainda depende do modelo "se comportar".
- **Objetivo**: tornar IMPOSSÍVEL o CTO editar código — **sem** torná-lo cego. Ele precisa
  continuar VENDO o código real (revisar arquitetura, diffs/PRs, escrever DoD). Modelo **read-only**:
  "entendo, vejo, mas não edito". NÃO é "remover o workspace" (isso o deixaria decidindo no escuro).
- **Caminho**: apontar o workspace do CTO para um mount **`:ro`** (mesmo mecanismo do `/seed`) —
  leitura total, `write`/`commit` bloqueados pelo SO; sêniores seguem com `/work` gravável.
  Avaliar como o Paperclip escopa workspace por agente (`projects.env` / `execution_workspace_policy`).
- **Ressalva**: o Paperclip pode tentar escrever no `cwd` (worktree/logs/temp) e engasgar num
  diretório read-only — garantir que ele só LÊ ali e grava estado em outro lugar.

## Decisão: projeto fica no OneDrive (risco aceito)
O projeto vive em `OneDrive\Documentos\DIR_PATH\paperclip`. O `.env` (token do Claude + senha do
banco) e a pasta `backups\` **sincronizam pra nuvem** — risco **aceito pelo fundador**: a estrutura
está montada e NÃO deve ser movida. Não sugerir mover o projeto/`.env` pra fora do OneDrive. (Se um
dia quiser endurecer: rotacionar o token com `claude setup-token` + trocar a senha do banco — mas é
escolha do fundador, não pendência.)

## Múltiplos agentes neste repo
Tanto o **Claude Code** quanto o **Codex** se conectam aqui. Por isso a fonte única é o `AGENTS.md`
(padrão cross-agent) e o `CLAUDE.md` é só um ponteiro — evita os dois divergirem (foi o que gerou a
duplicata com "Codex" trocado por engano).
