# MEMORY — Paperclip (empresa human-less)

> Documento de **memória/continuidade**: estado atual, decisões e a jornada de como chegamos aqui.
> Para detalhe técnico, ver [`AGENTS.md`](../AGENTS.md) (fonte única) e os docs ao lado
> (`arquitetura.md`, `operacao.md`, `paperclip-db.md`).
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
| Senior Platform Engineer (Contracts & Schema Registry) | engineer | claude_local | ✅ ativo — dono do truther-contracts (protobuf/buf/codegen + Confluent SR) |
| Senior Codex Engineer | engineer | codex_local | ⛔ offline (cota OpenAI) |
| Senior QA Engineer | qa | gemini_local | ⛔ offline (free tier Gemini, limite 5 req) |

CEO 2 / CEO 3 (duplicatas) foram **purgados** do banco.

## 3. Runtimes e billing
Claude/Codex/Gemini são **CLIs (cascas)** — a inteligência vem de um LLM **pago** por trás.
- **Claude** — ✅ ativo via assinatura (`CLAUDE_CODE_OAUTH_TOKEN`). Único 100% operacional.
- **Codex** (OpenAI) — instalado e auth ok, mas **bloqueado por cota** (key `sk-proj-...` sem crédito).
- **Gemini** (Google) — instalado e key válida, mas **free tier** (limite 5 req) inviável p/ agente.
Para destravar: habilitar **billing pago** no provedor (OpenAI / Google AI Studio) — a key não muda.

## 4. Arquitetura de trabalho (cópia isolada) — detalhe em arquitetura.md
- Pasta real do projeto: montada **somente-leitura** em `/seed/<projeto>` (o agente NUNCA edita).
- O agente trabalha numa **cópia** gravável em `/work/<projeto>` (volume Docker, fora do OneDrive),
  sem `node_modules`, **sem remoto git** (zero push).
- Fluxo de PR: agente trabalha em branch isolada → fundador revisa/puxa o diff → decide o merge.
- **Regra inegociável**: agentes nunca dão push, nunca commitam em branches do fundador.

**Projetos espelhados hoje** (mount `:ro` + cópia em `/work`, todos sob `${DIR_PATH}`):

| Projeto (`-Projeto`) | Stack | Base ref | Observação |
|---|---|---|---|
| `userservice` | Fastify + Prisma + Postgres (TS) | `master` | repo com git |
| `data-rudder-provider` | Go (chi, pgx/v5, sqlc) | `master` | repo com git |
| `truther-contracts` | protobuf/buf + Node/TS (contratos) | **`main`** | git + origin GitHub (cópia sem remoto); use `-Base main` nos scripts |

O `protocol-buffer` (multi-linguagem, em Truther) **existe mas NÃO está espelhado** (foi descartado
como alvo; o projeto de contratos é o `truther-contracts`).

## 5. Infra — detalhe em operacao.md
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
  (detalhe em paperclip-db.md). Confirmar na UI por ser `managed`.

## 8. Pendências
- **Trava física do CTO (camada 3)** — hoje "CTO não coda" é só instrução. Objetivo: workspace
  **read-only** ("vejo, não edito") via mount `:ro`, sem cegá-lo. Ver `## ⚠️ Pendências` no AGENTS.md.
- **Reativar Codex e Gemini** quando o fundador habilitar billing (remover os avisos OFFLINE no CTO).
- **✅ Harmonizar o layout dos serdes (truther-contracts) — CONCLUÍDA.** Objetivo era padrão único +
  **um pacote publicável por linguagem** (gen + serde juntos). Resultado na main (`a589613`): cada
  linguagem em `sdk/{go,node,python}` (serde + gen embutido via Strategy A), `gen/` como registro
  canônico. Pendente apenas: **público vs privado dos registries** (decidir antes de publicar) e a
  pendência nova do `gen/` stale (abaixo). Histórico de como chegamos:
  - **ROD-21**: padrão entregue em `docs/packaging.md` (branch `feat/rod-21-packaging-standard`):
    layout `sdk/{go,node,python}` = um pacote publicável por linguagem (gen + serde juntos), `gen/`
    fica como registro canônico. **Decisões assinadas pelo fundador (2026-06-05):** npm
    **`@truther/contracts`**, PyPI **`truther-contracts`**, embedding **Strategy A** (buf.gen.yaml
    gera em `gen/` E `sdk/`). Pendente: público vs privado dos registries (decidir antes de publicar).
  - **Conformance FEITA** (nas branches da cópia, não na main): ROD-22 Strategy A no buf.gen.yaml;
    ROD-23 Go→`sdk/go/`; ROD-24 Node→`sdk/node/`; ROD-25 Python→`sdk/python/truther_contracts/`.
  - **INTEGRAÇÃO na main — ✅ COMPLETA (main = `a589613`).** As 3 conformances + o padrão estão na
    main; `sdk/go` + `sdk/node` + `sdk/python` convivem com `gen/` (Strategy A).
    - ✅ Passo 1: `feat/rod-21-packaging-standard` (rod-21 doc + rod-22 Strategy A) — merge `c6f6e3d`.
    - ✅ Passo 2: `feat/rod-24-node-sdk-conformance` (Node → `sdk/node/`) — merge `90e861f`.
    - ✅ Passo 3: `feat/rod-15-go-serde` (Go, rod-15+rod-23 → `sdk/go/`) — merge `7db8364`. Aplicou
      limpo (não tocava buf afinal; o "conflito de buf" mapeado era ruído de shell).
    - ✅ Passo 4: `feat/rod-25-python-conformance-v2` (Python → `sdk/python/`) — merge `a589613`.
      A v1 (`rod-25`) foi feita na base antiga e batia conflito nos `transaction_pb2.py` gerados;
      o **Senior Python entregou a v2 sobre a main atual** (removeu o legado `gen/python/
      truther_contracts_sdk/`, serde só em `sdk/python/truther_contracts/`). Único ajuste meu: 1 linha
      de docstring. ⚠️ **Lição:** apontei uma "falha de layout" (o `proto/` aninhado) que era equívoco
      MEU — o `buf generate` gera o Python **aninhado em `proto/`** (verifiquei byte-a-byte). O agente
      estava certo; "achatar" teria QUEBRADO o Strategy A. Reforça o combinado de voltar pro agente.
    - 📌 **GOTCHA do puxar (registrado p/ próximas integrações):** quando uma branch entra na main via
      `git am` (hash novo), `main..<branch>` mostra os commits-pai duplicados. Ao puxar uma branch que
      descende de outra já mergeada, **basear o patch na branch-pai/tip do que já está na main** (não em
      `main`) — ex.: rod-24 com `-Base feat/rod-21-packaging-standard`; rod-25(v1) com `-Base 7d9d405`
      (tip do rod-14). Mecânica por passo: puxar → push → PR → CI verde → merge → `git pull` → próximo.

### Pendência nova: `gen/` está STALE (regerar tudo via buf)
Descoberto ao integrar a rod-25: o `buf generate` HOJE gera o Python em `gen/python/`**`proto/`**`/
transaction_pb2.py` (aninhado, com `json_name`), mas a main tem `gen/python/transaction_pb2.py`
(plano, sem `json_name`) — gerado de quando o proto estava na raiz, antes de ir pra `proto/`.
Provavelmente `gen/go` e `gen/node` também estão defasados. **Task pro Platform/Senior:** rodar
`buf generate` e commitar o `gen/` regenerado (e conferir se os `sdk/` continuam batendo). Separada
desta integração; não bloqueou os PRs porque o wire binário é idêntico (só muda JSON/descriptor-path).
- **✅ truther-contracts — ROD-14 (SPEC) + serdes 15/16/17 integrados.** Todas na main (`a589613`):
  ROD-14 (SPEC Confluent SR + §11 Security + `docs/visao-geral.md`, CI verde), ROD-15 (Go), ROD-16
  (Node), ROD-17 (Python) — estes três via as branches de conformance (sdk/), ver tracker acima.
  Fixes de CI que ficaram na rod-14 (referência): `buf format -w`, except `PACKAGE_DIRECTORY_MATCH`,
  `.gitattributes` (proto LF), interop Go rodando de `interop/go`, `git fetch origin main:main` no job
  de breaking.
- **Pós-integração — apontar `interop/` para `sdk/`** (Platform Engineer): o `interop/` ainda importa
  dos caminhos antigos; agora que as 3 conformances estão na main, é a hora de migrar pra `sdk/`
  (era pra ser **só depois** das conformances, per `packaging.md §9.1`).

## 9. IDs de referência
- company `207d7642-8a17-4ee7-8fbb-f63b9da66153`
- projeto user-service `7b13cef6-b2ee-4ae5-9844-412e192cbe88`
- CTO `002e59ca-a963-44ba-891e-cab9fee6d229`
- Senior Codex Engineer `e4d1d52c-4eeb-4d9a-9f98-cefadcb56b8d`
- Senior QA Engineer (Gemini) `22ab069f-9a26-4552-bb00-d7098785395c`

## 10. Como retomar a conversa
1. Leia este `MEMORY.md` (estado + decisões) e o `AGENTS.md` (fonte técnica única).
2. Estado em 1 frase: **empresa human-less montada e estável; só Claude operacional (Codex/Gemini
   esperando billing); truther-contracts com SPEC + serdes Go/Node/Python integrados na main
   (`a589613`, layout `sdk/`); próximas frentes: regerar `gen/` stale via buf, apontar `interop/`
   pra `sdk/`, e a trava read-only do CTO (camada 3).**
