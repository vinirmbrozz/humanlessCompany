# Imagem de runtime do Paperclip (empresa human-less).
# Instala git + Claude Code CLI em BUILD-TIME (antes era no command, rodava a cada restart).
# A identidade git do fundador também é baked aqui (sobrevive a qualquer recriação).
FROM node:20-bookworm-slim

# git: usado pelos workspaces/cópias. ca-certificates: TLS pro npm/claude.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI: o binário `claude` que o adapter claude-local procura no PATH.
RUN npm install -g @anthropic-ai/claude-code \
    && npm cache clean --force

# Identidade git dos agentes (commits saem no nome do fundador, não do dev herdado).
RUN git config --global user.name "Vinícius Rodrigues" \
    && git config --global user.email "vinicius@truther.to"

WORKDIR /root

# Sanity: falha o build se o claude não ficou resolvível no PATH.
RUN claude --version
