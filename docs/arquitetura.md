# Arquitetura — modelo de cópia isolada

> Como o código dos projetos entra no Paperclip sem que a pasta real do fundador seja tocada.

## Princípio: a pasta real NUNCA é editada

Cada projeto entra por **duas camadas**:

- **`/seed/<projeto>` (somente-leitura)** — a pasta real do host (`${DIR_PATH}/<projeto>`)
  montada `:ro`. Escrita do agente é bloqueada pelo SO (verificado: `Read-only file system`).
- **`/work/<projeto>` (gravável)** — uma **cópia** num volume Docker (`paperclip_work`), fora do
  OneDrive. O agente trabalha AQUI, in-place na cópia.

Detalhes da cópia:
- `node_modules` é **excluído** (o do host é Windows; quebra no Linux — o agente reinstala).
- O remoto `origin` é **removido** da cópia → zero destino de push.
- A identidade git da cópia cai no global do container (`Vinícius Rodrigues <vinicius@truther.to>`).

## Por que cópia, e não a pasta real

A estratégia de execução observada no Paperclip é `mode=shared_workspace`,
`strategy_type=project_primary`, **sem branch isolada** → o agente edita **in-place no `cwd`**.
Se o `cwd` fosse a pasta real, o agente alteraria seu código direto (e o OneDrive sincronizaria).
Por isso o `cwd` do workspace aponta para `/work/<projeto>` (a cópia), **nunca** para `/seed`.

## Adicionar um projeto novo (espelho) — 3 passos

Paths e senhas vêm do `.env` (`${DIR_PATH}` = pasta base dos projetos).

1. **Mount `:ro` no `docker-compose.yml`** (volumes do serviço `paperclip`):
   `- "${DIR_PATH}/<projeto>:/seed/<projeto>:ro"` → depois `docker compose up -d`.
2. **Criar a cópia de trabalho** em `/work/<projeto>` (passo fácil de esquecer — sem ele a
   criação de issue dá **422** porque o cwd não existe):
   `.\scripts\espelhar.ps1 -Projeto <projeto>`  (refresh: `... -Atualizar`).
3. **No Paperclip**: criar o projeto e apontar o **cwd do workspace** para `/work/<projeto>`.

## Fluxo de revisão / PR (o fundador decide)

O agente trabalha na cópia, numa branch da task. Nada vai pro remoto. Você revisa e decide:

- `.\scripts\revisar.ps1 -Projeto <p>` — mostra o diff do que o agente fez (read-only).
- `.\scripts\puxar.ps1 -Projeto <p>` — traz como **patch** para uma **branch nova** do repo real.
- `.\scripts\descartar.ps1 -Projeto <p>` — apaga a branch; `-AlsoCopy` também limpa a cópia.

**Regra inegociável**: agentes **nunca fazem push** e só commitam na branch isolada da task.
A cláusula no `AGENTS.md` da cópia (tempo de execução) reforça isso.

> ⚠️ A cópia inclui o `.env` do projeto com segredos. Revise/remova de `/work/<projeto>/.env`
> antes de soltar um sênior, se não quiser expor credenciais ao agente.
