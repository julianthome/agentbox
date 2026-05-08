#!/bin/sh
set -eu

AGENT="${AGENT:-pi}"
OLLAMA_URL="http://host.docker.internal:11434"
OLLAMA_API="${OLLAMA_URL}/v1"

# ── Ollama auto-discovery ─────────────────────────────────────────────────────
ollama_models=$(curl -sf "${OLLAMA_URL}/api/tags" 2>/dev/null \
    | jq '[.models[].name | {id: .}]' 2>/dev/null || echo '[]')

if [ "$ollama_models" != '[]' ]; then
  echo "Ollama: $(echo "$ollama_models" | jq -r '[.[].id] | join(", ")')"

  case "$AGENT" in
    pi)
      mkdir -p /home/user/.pi/agent
      jq -n --argjson models "$ollama_models" --arg url "$OLLAMA_API" \
        '{providers: {ollama: {baseUrl: $url, api: "openai-completions", apiKey: "ollama", models: $models}}}' \
        > /home/user/.pi/agent/models.json
      ;;
    opencode)
      cfg=/home/user/.config/opencode/opencode.json
      auth=/home/user/.local/share/opencode/auth.json
      mkdir -p "$(dirname "$cfg")" "$(dirname "$auth")"

      models_obj=$(echo "$ollama_models" | jq '[.[] | {(.id): {name: .id, tools: true}}] | add')

      existing=$([ -f "$cfg" ] && cat "$cfg" || echo '{}')
      printf '%s' "$existing" | jq \
        --argjson models "$models_obj" --arg url "$OLLAMA_API" \
        '.["$schema"] = "https://opencode.ai/config.json"
         | .provider.ollama = {
             npm: "@ai-sdk/openai-compatible",
             name: "Ollama",
             options: {baseURL: $url},
             models: $models
           }' > "$cfg"

      existing=$([ -f "$auth" ] && cat "$auth" || echo '{}')
      printf '%s' "$existing" | jq '. + {"ollama":{"key":"local"}}' > "$auth"
      ;;
  esac
else
  echo "Ollama: not reachable or no models pulled"
fi

# ── Trust mounted workspace directories ──────────────────────────────────────
git config --global --add safe.directory '*'

# ── Session branch ───────────────────────────────────────────────────────────
if [ "${SNAPSHOT:-1}" = "1" ]; then
  ts=$(date -u +%Y%m%d-%H%M%S)
  for dir in /workspace/*/; do
    [ -d "$dir" ] || continue
    if git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
      parent=$(git -C "$dir" branch --show-current)
      [ -z "$parent" ] && parent="detached-$(git -C "$dir" rev-parse --short HEAD)"
      git -C "$dir" checkout -b "agentbox/${parent}/${ts}"
      echo "Session branch: agentbox/${parent}/${ts} in $(basename "$dir")"
    fi
  done
fi

# ── tmux session: two windows ─────────────────────────────────────────────────
case "$AGENT" in
  pi)
    agent_cmd="sh -c 'unset TMUX && exec pi'"
    ;;
  opencode)
    # Node.js wrapper doesn't inherit tmux PTY on Alpine — use native musl binary directly.
    arch=$(uname -m); [ "$arch" = "aarch64" ] && arch="arm64"
    base="/usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-${arch}"
    bin="${base}-musl/bin/opencode"
    [ -f "$bin" ] || bin="${base}/bin/opencode"
    agent_cmd="env OPENCODE_BIN_PATH=$bin OPENCODE_DISABLE_MODELS_FETCH=1 opencode"
    ;;
  *)
    agent_cmd="$AGENT"
    ;;
esac

tmux new-session -d -s sandbox -n "$AGENT" "$agent_cmd"
tmux new-window  -t sandbox    -n "shell"
tmux select-window -t "sandbox:$AGENT"
exec tmux attach-session -t sandbox
