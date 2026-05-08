# ── Stage 1: builder — fonts + shell environment ─────────────────────────────
FROM node:22-alpine AS builder

RUN apk add --no-cache \
    zsh git curl unzip ca-certificates fontconfig

# Extract only the Mono variants needed for terminal rendering
RUN mkdir -p /usr/share/fonts/NerdFonts && \
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip" \
        -o /tmp/FiraCode.zip && \
    unzip -j /tmp/FiraCode.zip \
        "FiraCodeNerdFontMono-Regular.ttf" \
        "FiraCodeNerdFontMono-Bold.ttf" \
        -d /usr/share/fonts/NerdFonts && \
    fc-cache -fv && \
    rm /tmp/FiraCode.zip

RUN adduser -D -s /bin/zsh user

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER user

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k" && \
    cp "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k/config/p10k-lean.zsh" \
       "${HOME}/.p10k.zsh"

RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

COPY --chown=user:user .zshrc     /home/user/.zshrc
COPY --chown=user:user .tmux.conf /home/user/.tmux.conf

# ── Stage 2: base — common runtime tools ─────────────────────────────────────
FROM node:22-alpine AS base

RUN apk add --no-cache \
    zsh git curl ca-certificates \
    build-base python3 py3-pip py3-virtualenv \
    jq bash ripgrep fd vim openssh-client \
    tmux fontconfig \
    gcompat libgcc libstdc++

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PIP_BREAK_SYSTEM_PACKAGES=1

RUN pip3 install --no-cache-dir uv

COPY --from=builder /usr/share/fonts/NerdFonts /usr/share/fonts/NerdFonts
RUN fc-cache -fv

COPY --from=builder /usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN adduser -D -s /bin/zsh user

COPY --from=builder --chown=user:user /home/user /home/user

# ── Stage 3: agents ───────────────────────────────────────────────────────────
FROM base

RUN npm install -g @earendil-works/pi-coding-agent opencode-ai && npm cache clean --force

ENV AGENT=pi

USER user
RUN mkdir -p /home/user/.local/state /home/user/.local/share /home/user/.config
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
