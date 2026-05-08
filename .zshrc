# Powerlevel10k instant prompt — must stay at the very top
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  node
)

source "$ZSH/oh-my-zsh.sh"

# opencode: bypass Node.js wrapper — PTY inheritance broken on Alpine+musl
_arch=$(uname -m); [[ "$_arch" == "aarch64" ]] && _arch="arm64"
_base="/usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-${_arch}"
_bin="${_base}-musl/bin/opencode"
[[ -f "$_bin" ]] || _bin="${_base}/bin/opencode"
export OPENCODE_BIN_PATH="$_bin"
export OPENCODE_DISABLE_MODELS_FETCH=1
unset _arch _base _bin

# Aliases useful inside the sandbox
alias ll="ls -lah"
alias grep="grep --color=auto"
alias rg="rg --color=auto"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ── pi.dev colour overrides for Powerlevel10k ─────────────────────────────────
typeset -g POWERLEVEL9K_DIR_FOREGROUND='#6A9FCC'
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND='#4b607c'
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND='#6A9FCC'
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND='#6A9FCC'
typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='#9fa4ab'
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='#EBE7E4'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_FOREGROUND='#6A9FCC'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND='#8f3222'
typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND='#8f3222'
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='#9fa4ab'
