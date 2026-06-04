# Paperclip

Runtime de orquestração de agentes IA para os portfólios **Fintech** (fintech/cripto, KYC/AML) e **Data Integration** (integração ERP Sienge).

O modelo organizacional simula uma empresa *human-less*: **CEO → CTO → Engenheiros Sêniores**, onde CEO e CTO apenas delegam — a execução técnica fica com os agentes sêniores, sob supervisão do fundador.

## Pré-requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e rodando
- Credencial do Claude (uma das duas):
  - `ANTHROPIC_API_KEY` — cobrança por token via API Anthropic
  - `CLAUDE_CODE_OAUTH_TOKEN` — usa sua assinatura Claude (gere com `claude setup-token`)

## Início rápido

1. **Configure o `.env`** a partir do exemplo:

   ```bash
   cp .env.example .env
   # Preencha as variáveis (veja a seção abaixo)
   ```

2. **Suba os containers:**

   ```bash
   docker compose up -d
   ```

3. **Acesse o Paperclip** em [http://localhost:3100](http://localhost:3100).

## Variáveis de ambiente

| Variável | Descrição |
|---|---|
| `POSTGRES_USER` | Usuário do banco PostgreSQL |
| `POSTGRES_PASSWORD` | Senha do banco PostgreSQL |
| `POSTGRES_DB` | Nome do banco |
| `DIR_PATH` | Caminho local da pasta com todos os projetos |
| `ANTHROPIC_API_KEY` | Chave da API Anthropic *(preencha esta **ou** a de baixo)* |
| `CLAUDE_CODE_OAUTH_TOKEN` | Token OAuth do Claude *(alternativa à chave API)* |

## Arquitetura

```
┌─────────────────────────────────────────────────┐
│  Host (Windows)                                 │
│                                                 │
│  DIR_PATH/<projeto>/  ──(read-only)──►  /seed/  │
│                                                 │
│  ┌────────────────────────────────────────────┐ │
│  │  Docker                                    │ │
│  │                                            │ │
│  │  paperclip (Node 20)     paperclip-db      │ │
│  │  ├─ /seed/<projeto> :ro  (PostgreSQL 16)   │ │
│  │  ├─ /work/<projeto>      porta 5433        │ │
│  │  └─ porta 3100                             │ │
│  └────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

- **`/seed`** — pastas reais dos projetos, montadas **somente-leitura**. Nunca são modificadas.
- **`/work`** — cópias de trabalho isoladas em volume Docker. Os agentes trabalham aqui.

## Gerenciando projetos

### Adicionar um projeto novo

1. Adicione o mount no `docker-compose.yml` (seção `volumes` do serviço `paperclip`):

   ```yaml
   - "${DIR_PATH}/<projeto>:/seed/<projeto>:ro"
   ```

2. Recrie o container e espelhe a cópia de trabalho:

   ```powershell
   docker compose up -d
   .\scripts\espelhar.ps1 -Projeto <projeto>
   ```

3. No painel do Paperclip, crie o projeto apontando o **cwd** para `/work/<projeto>`.

### Atualizar a cópia de trabalho

```powershell
.\scripts\espelhar.ps1 -Projeto <projeto> -Atualizar
```

### Revisar o trabalho de um agente

| Comando | O que faz |
|---|---|
| `.\scripts\revisar.ps1 -Projeto <p>` | Mostra o diff do que o agente alterou |
| `.\scripts\puxar.ps1 -Projeto <p>` | Traz as mudanças para uma branch nova no repo real |
| `.\scripts\descartar.ps1 -Projeto <p>` | Descarta a branch; use `-AlsoCopy` para limpar a cópia |
| `.\scripts\backup.ps1` | Dump do banco para `backups\` |

## Acesso ao banco (DBeaver)

O PostgreSQL do Paperclip fica exposto na porta **5433** do host:

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Porta | `5433` |
| Database | `paperclip` |
| Usuário | *(valor de `POSTGRES_USER`)* |
| Senha | *(valor de `POSTGRES_PASSWORD`)* |

Acesso rápido via terminal:

```bash
docker exec -i paperclip-db psql -U paperclip -d paperclip
```

## Notas importantes

- **Segurança**: o `.env` contém tokens sensíveis. Ele já está no `.gitignore` — nunca o comite.
- **Agentes nunca fazem push** e só commitam na branch isolada da task.
- **Instruções de agente / detalhes técnicos**: a fonte única é o [`AGENTS.md`](./AGENTS.md)
  (índice), com o aprofundamento em [`docs/`](./docs/) — arquitetura, operação e regras do banco.
  O `CLAUDE.md` é só um ponteiro pro `AGENTS.md` (pro Claude Code).
