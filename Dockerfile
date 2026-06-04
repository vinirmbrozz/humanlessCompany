# Imagem de runtime do Paperclip (empresa human-less).
# Instala git + Claude Code CLI em BUILD-TIME (antes era no command, rodava a cada restart).
# A identidade git do fundador também é baked aqui (sobrevive a qualquer recriação).
FROM node:20-bookworm-slim

# git: usado pelos workspaces/cópias. ca-certificates: TLS pro npm/claude.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# CLIs dos agentes: `claude` (claude-local), `codex` (codex-local), `gemini` (gemini-local).
# Cada adapter procura seu binário no PATH.
RUN npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli \
    && npm cache clean --force

# Identidade git dos agentes (commits saem no nome do fundador, não do dev herdado).
RUN git config --global user.name "Vinícius Rodrigues" \
    && git config --global user.email "vinicius@truther.to"

WORKDIR /root

# Sanity: falha o build se algum CLI não ficou resolvível no PATH.
RUN claude --version && codex --version && gemini --version
