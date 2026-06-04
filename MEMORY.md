# MEMORY — Paperclip (empresa human-less)

> Documento de **memória/continuidade**: estado atual, decisões e a jornada de como chegamos aqui.
> Para detalhe técnico, ver [`AGENTS.md`](AGENTS.md) (fonte única) e [`docs/`](docs/).
> Para conversar "do zero" a qualquer momento, leia este arquivo + o `AGENTS.md`.

## 1. O que é
Runtime de orquestração (Paperclip) que modela uma **empresa human-less** para gerir os
portfólios de software do fundador:
- **Truther** — fintech/cripto, KYC/AML (Go + Node/TS, event-driven).
- **PSA** — integração ERP Sienge (Python, ETL/BI).

Hierarquia: **CEO → CTO → Engenheiros Sêniores**. **CEO e CTO só delegam, nunca escrevem código.**
Tudo sob tutela do fundador (**Vinícius Rodrigues <vinicius@truther.to>**).

## 2. Organização atual (agents)
| Agente | Papel | Runtime | Status |
|---|---|---|---|
| CEO | ceo | claude_local | ✅ ativo (só delega) |
| CTO | cto | claude_local | ✅ ativo (só delega; blindado anti-override) |
| Senior Go Backend | engineer | claude_local | ✅ ativo |
| Senior Node TypeScript | engineer | claude_local | ✅ ativo |
| Senior Python | engineer | claude_local | ✅ ativo |
| Senior Codex Engineer | engineer | codex_local | ⛔ offline (cota OpenAI) |
| Senior QA Engineer | qa | gemini_local | ⛔ offline (free tier Gemini, limite 5 req) |

CEO 2 / CEO 3 (duplicatas) foram **purgados** do banco.

## 3. Runtimes e billing
Claude/Codex/Gemini são **CLIs (cascas)** — a inteligência vem de um LLM **pago** por trás.
- **Claude** — ✅ ativo via assinatura (`CLAUDE_CODE_OAUTH_TOKEN`). Único 100% operacional.
- **Codex** (OpenAI) — instalado e auth ok, mas **bloqueado por cota** (key `sk-proj-...` sem crédito).
- **Gemini** (Google) — instalado e key válida, mas **free tier** (limite 5 req) inviável p/ agente.
Para destravar: habilitar **billing pago** no provedor (OpenAI / Google AI Studio) — a key não muda.

## 4. Arquitetura de trabalho (cópia isolada) — detalhe em docs/arquitetura.md
- Pasta real do projeto: montada **somente-leitura** em `/seed/<projeto>` (o agente NUNCA edita).
- O agente trabalha numa **cópia** gravável em `/work/<projeto>` (volume Docker, fora do OneDrive),
  sem `node_modules`, **sem remoto git** (zero push).
- Fluxo de PR: agente trabalha em branch isolada → fundador revisa/puxa o diff → decide o merge.
- **Regra inegociável**: agentes nunca dão push, nunca commitam em branches do fundador.

## 5. Infra — detalhe em docs/operacao.md
- **Docker Compose**: serviço `paperclip` (imagem própria `paperclip-runtime:latest`, via Dockerfile)
  + `db` (Postgres 16 externo, porta host `127.0.0.1:5433`).
- **Dockerfile** instala em build-time: `git`, e os CLIs `claude` + `codex` + `gemini`, + identidade git.
- **Segredos no `.env`** (interpolados no compose): `CLAUDE_CODE_OAUTH_TOKEN`, `OPENAI_API_KEY`,
  `GEMINI_API_KEY`, `POSTGRES_*`, `DIR_PATH`. `.env.example` versionado.
- **Backup**: `.\scripts\backup.ps1` (dump pra `backups\`, rotação `-Keep` default 20).

## 6. Scripts (em `scripts\`)
| Script | Função |
|---|---|
| `espelhar.ps1 -Projeto <p>` | cria/atualiza (`-Atualizar`) a cópia isolada em `/work/<p>` |
| `revisar.ps1 -Projeto <p>` | mostra o diff do que o agente fez (read-only) |
| `puxar.ps1 -Projeto <p>` | traz o trabalho pra branch nova do repo real (via patch) |
| `descartar.ps1 -Projeto <p>` | apaga a branch (`-AlsoCopy` limpa a cópia) |
| `backup.ps1` | dump do banco |
Rodar `.ps1`: num terminal PowerShell, ou `powershell -ExecutionPolicy Bypass -File .\scripts\<x>.ps1`.

## 7. Decisões-chave (e o porquê)
- **CEO/CTO só delegam.** O CTO já executou uma vez (commitou SQL ao receber "faça a correção");
  por isso seu AGENTS.md ganhou cláusula **anti-override** (ordem direta de "implemente" vira child issue).
- **Codex/Gemini marcados OFFLINE no CTO** até billing (senão o CTO delega e toma falha).
- **Projeto fica no OneDrive** — risco de segredo sincronizar aceito pelo fundador; não sugerir mover.
- **Identidade git** baked na imagem (commits saem como Vinícius, não do dev herdado "FelpFreitas").
- **AGENTS.md é a fonte única**; `CLAUDE.md` é só ponteiro `@AGENTS.md` (Claude + Codex leem o repo).
- **Editar instruções de um agente**: arquivo `managed` no volume; editar com backup + `docker cp`
  (detalhe em docs/paperclip-db.md). Confirmar na UI por ser `managed`.

## 8. Pendências
- **Trava física do CTO (camada 3)** — hoje "CTO não coda" é só instrução. Objetivo: workspace
  **read-only** ("vejo, não edito") via mount `:ro`, sem cegá-lo. Ver `## ⚠️ Pendências` no AGENTS.md.
- **Reativar Codex e Gemini** quando o fundador habilitar billing (remover os avisos OFFLINE no CTO).

## 9. IDs de referência
- company `207d7642-8a17-4ee7-8fbb-f63b9da66153`
- projeto user-service `7b13cef6-b2ee-4ae5-9844-412e192cbe88`
- CTO `002e59ca-a963-44ba-891e-cab9fee6d229`
- Senior Codex Engineer `e4d1d52c-4eeb-4d9a-9f98-cefadcb56b8d`
- Senior QA Engineer (Gemini) `22ab069f-9a26-4552-bb00-d7098785395c`

## 10. Como retomar a conversa
1. Leia este `MEMORY.md` (estado + decisões) e o `AGENTS.md` (fonte técnica única).
2. Estado em 1 frase: **empresa human-less montada e estável; só Claude operacional; Codex e Gemini
   esperando billing; próxima fronteira é a trava read-only do CTO (camada 3).**
