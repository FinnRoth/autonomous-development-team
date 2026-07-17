#!/usr/bin/env bash
# ADT — Autonomous Development Team — setup script.
# Interactively configures the Docker Compose stack, generates openclaw.json,
# builds the container image, boots the gateway, and applies MCP + default-agent
# patches. Idempotent: re-running it will skip work already done and re-emit
# the config files with the values you provide.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$REPO_ROOT/templates"
AGENT_TEMPLATES="$REPO_ROOT/openclaw/data/adt-shared/agent-templates"
LOG_DIR="$REPO_ROOT/.setup-logs"
mkdir -p "$LOG_DIR"

# ─── colours & symbols ──────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; DIM=$'\033[2m'
  BOLD=$'\033[1m'; NC=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; DIM=""; BOLD=""; NC=""
fi

CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}!${NC}"
ARROW="${CYAN}▸${NC}"
BULLET="${DIM}·${NC}"

TOTAL_STEPS=7
CURRENT_STEP=0

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo
  echo "${BOLD}${BLUE}━━━ [${CURRENT_STEP}/${TOTAL_STEPS}] $* ━━━${NC}"
}

ok()   { echo "  ${CHECK} $*"; }
warn() { echo "  ${WARN} ${YELLOW}$*${NC}"; }
fail() { echo; echo "${CROSS} ${RED}${BOLD}$*${NC}" >&2; }
note() { echo "  ${DIM}$*${NC}"; }
sub()  { echo "  ${ARROW} $*"; }

# ─── prompts ────────────────────────────────────────────────────────────────
ask() {
  local prompt="$1" default="${2:-}" reply
  local rendered
  if [[ -n "$default" ]]; then
    rendered="  ${BOLD}${prompt}${NC} ${DIM}[${default}]${NC}: "
  else
    rendered="  ${BOLD}${prompt}${NC}: "
  fi
  # Prompt to stderr so command substitution captures only the value.
  read -rp "$rendered" reply </dev/tty
  echo "${reply:-$default}"
}

ask_secret() {
  local prompt="$1" note_txt="${2:-}" reply
  local rendered="  ${BOLD}${prompt}${NC} ${DIM}(hidden${note_txt:+, $note_txt})${NC}: "
  read -rsp "$rendered" reply </dev/tty
  echo >&2
  echo "$reply"
}

ask_choice() {
  # Renders a numbered menu to stderr, returns the chosen value on stdout.
  local prompt="$1" default_idx="$2"; shift 2
  local options=("$@")
  echo "  ${BOLD}${prompt}${NC}" >&2
  for i in "${!options[@]}"; do
    local marker="  "
    [[ $((i+1)) -eq $default_idx ]] && marker="${GREEN}▸${NC} "
    echo "  ${marker}$((i+1))) ${options[$i]}" >&2
  done
  local reply
  read -rp "  ${DIM}Choose [${default_idx}]${NC}: " reply </dev/tty
  reply="${reply:-$default_idx}"
  if [[ ! "$reply" =~ ^[0-9]+$ ]] || (( reply < 1 || reply > ${#options[@]} )); then
    echo "  ${YELLOW}Invalid choice, using default (${default_idx})${NC}" >&2
    reply="$default_idx"
  fi
  echo "${options[$((reply-1))]}"
}

# ─── docker helpers ────────────────────────────────────────────────────────
port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$port" -sTCP:LISTEN -n -P >/dev/null 2>&1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn "sport = :$port" 2>/dev/null | grep -q "$port"
  else
    return 1  # can't check
  fi
}

next_free_port() {
  local port="$1"
  while port_in_use "$port"; do port=$((port + 1)); done
  echo "$port"
}

detect_litellm() {
  # Return 0 if something responds at the URL, 1 otherwise.
  local url="$1"
  curl -sS -o /dev/null -m 2 "$url" 2>/dev/null
}

# Ensure htpasswd is available; prompt to install if missing; exit if declined.
ensure_htpasswd() {
  if command -v htpasswd >/dev/null 2>&1; then
    return 0
  fi
  echo
  warn "htpasswd not found — it is required to hash the master password."
  echo "  ${DIM}Install it with one of:${NC}"
  echo "    macOS:  brew install httpd"
  echo "    Debian/Ubuntu: sudo apt-get install -y apache2-utils"
  echo "    RHEL/Fedora:   sudo dnf install -y httpd-tools"
  echo
  local reply
  read -rp "  ${BOLD}Install now? [y/N]${NC} " reply </dev/tty
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      brew install httpd
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get install -y apache2-utils
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y httpd-tools
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y httpd-tools
    else
      fail "No supported package manager found. Install apache2-utils / httpd-tools manually and re-run."
      exit 1
    fi
  else
    fail "htpasswd is required. Aborting."
    exit 1
  fi

  if ! command -v htpasswd >/dev/null 2>&1; then
    fail "htpasswd still not found after installation attempt. Aborting."
    exit 1
  fi
}

# Generate a bcrypt hash using htpasswd -B (guaranteed bcrypt output).
bcrypt_hash() {
  local password="$1"
  # htpasswd -B -n -b: bcrypt, stdout only, batch (non-interactive).
  # Output is "user:hash" — strip the "dummy:" prefix.
  htpasswd -B -n -b dummy "$password" 2>/dev/null | cut -d: -f2
}

# ─── banner ────────────────────────────────────────────────────────────────
clear 2>/dev/null || true
cat <<EOF

${BOLD}${CYAN}    ▄▀█ █▀▄ ▀█▀${NC}    ${BOLD}Autonomous Development Team${NC}
${BOLD}${CYAN}    █▀█ █▄▀  █ ${NC}    ${DIM}A cloneable 7-agent OpenClaw setup${NC}

  This wizard will:
    ${BULLET} check prerequisites
    ${BULLET} collect a handful of connection details
    ${BULLET} generate ${BOLD}docker-compose.yml${NC} and ${BOLD}openclaw/data/openclaw.json${NC}
    ${BULLET} build and boot the container
    ${BULLET} register the 7 ADT agents with OpenClaw
    ${BULLET} apply MCP + default-agent patches inside the running container

  Press ${BOLD}Enter${NC} to accept the ${DIM}[default]${NC} shown in brackets.
EOF

# ─── [1] prerequisites ─────────────────────────────────────────────────────
step "Prerequisites"

MISSING=()
for cmd in docker curl sed; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd found"
  else
    MISSING+=("$cmd")
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  MISSING+=("docker compose (v2)")
else
  ok "docker compose v2 found"
fi

if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not running. Start Docker Desktop (or the Docker service) and re-run this script."
  exit 1
fi
ok "docker daemon reachable"

if [[ ${#MISSING[@]} -gt 0 ]]; then
  fail "Missing tools: ${MISSING[*]}"
  exit 1
fi

ensure_htpasswd
ok "htpasswd found"

# ─── [2] configuration ─────────────────────────────────────────────────────
step "Configuration"

echo
echo "  ${BOLD}Container${NC}"
CONTAINER_NAME=$(ask "Container name" "adt")

DEFAULT_PORT=18789
if port_in_use "$DEFAULT_PORT"; then
  SUGGESTED_PORT=$(next_free_port $((DEFAULT_PORT + 1)))
  warn "Port ${DEFAULT_PORT} is already in use — suggesting ${SUGGESTED_PORT}"
  DEFAULT_PORT="$SUGGESTED_PORT"
fi
GATEWAY_PORT=$(ask "Gateway port" "$DEFAULT_PORT")

echo
echo "  ${BOLD}Master password${NC}"
note "Single password for the OpenClaw gateway UI/API and the n8n UI. Leave blank to disable gateway auth (local-only)."
MASTER_PASSWORD=$(ask_secret "Master password" "leave blank for none")

echo
echo "  ${BOLD}LLM backend (LiteLLM)${NC}"
DEFAULT_LITELLM_URL="http://host.docker.internal:6655"
if detect_litellm "http://localhost:6655/"; then
  note "Detected a service listening at ${BOLD}http://localhost:6655${NC} — using it as the default."
fi
LITELLM_BASE_URL=$(ask "LiteLLM base URL" "$DEFAULT_LITELLM_URL")
LITELLM_API_KEY=$(ask_secret "LiteLLM API key")
if [[ -z "$LITELLM_API_KEY" ]]; then
  warn "No LiteLLM API key provided — agents won't be able to reach the model."
fi

echo
echo "  ${BOLD}Integrations${NC} ${DIM}(optional — press Enter to skip)${NC}"
FIGMA_TOKEN=$(ask_secret "Figma personal access token" "optional")
GIT_HOST_CHOICE=$(ask_choice "Git host CLI" "1" "gh (GitHub)" "glab (GitLab)" "tea (Gitea)")
GIT_HOST_CLI="${GIT_HOST_CHOICE%% *}"
GIT_HOST_TOKEN=$(ask_secret "Git host token" "optional")

echo
echo "  ${BOLD}Board API${NC}"
DEFAULT_BOARD_API_PORT=3001
while port_in_use "$DEFAULT_BOARD_API_PORT" 2>/dev/null || false; do
  DEFAULT_BOARD_API_PORT=$((DEFAULT_BOARD_API_PORT + 1))
done
BOARD_API_PORT=$(ask "Board API host port (for local inspection; agents use internal hostname)" "$DEFAULT_BOARD_API_PORT")

echo
echo "  ${BOLD}n8n${NC}"
DEFAULT_N8N_PORT=5678
if port_in_use "$DEFAULT_N8N_PORT"; then
  SUGGESTED_N8N_PORT=$(next_free_port $((DEFAULT_N8N_PORT + 1)))
  warn "Port ${DEFAULT_N8N_PORT} is already in use — suggesting ${SUGGESTED_N8N_PORT}"
  DEFAULT_N8N_PORT="$SUGGESTED_N8N_PORT"
fi
N8N_PORT=$(ask "n8n host port" "$DEFAULT_N8N_PORT")
N8N_OWNER_EMAIL=$(ask "n8n owner email" "admin@docker.internal")

# ─── [3] generate files ────────────────────────────────────────────────────
step "Generating configuration files"

# Derive n8n owner password hash from the master password.
# n8n requires a bcrypt hash — plain text is not accepted.
if [[ -n "$MASTER_PASSWORD" ]]; then
  sub "hashing master password for n8n (bcrypt)…"
  N8N_OWNER_PASSWORD_HASH=$(bcrypt_hash "$MASTER_PASSWORD")
  if [[ -z "$N8N_OWNER_PASSWORD_HASH" ]]; then
    fail "bcrypt hashing failed. Aborting."
    exit 1
  fi
  ok "bcrypt hash generated"
else
  N8N_OWNER_PASSWORD_HASH=""
fi

# Escape $ in the bcrypt hash so docker-compose doesn't treat them as variable refs.
N8N_OWNER_PASSWORD_HASH_ESCAPED="${N8N_OWNER_PASSWORD_HASH//\$/$\$}"

# docker-compose.yml
sed \
  -e "s|{{CONTAINER_NAME}}|${CONTAINER_NAME}|g" \
  -e "s|{{GATEWAY_PORT}}|${GATEWAY_PORT}|g" \
  -e "s|{{OPENCLAW_GATEWAY_PASSWORD}}|${MASTER_PASSWORD}|g" \
  -e "s|{{LITELLM_BASE_URL}}|${LITELLM_BASE_URL}|g" \
  -e "s|{{LITELLM_API_KEY}}|${LITELLM_API_KEY}|g" \
  -e "s|{{FIGMA_TOKEN}}|${FIGMA_TOKEN}|g" \
  -e "s|{{GIT_HOST_TOKEN}}|${GIT_HOST_TOKEN}|g" \
  -e "s|{{GIT_HOST_CLI}}|${GIT_HOST_CLI}|g" \
  -e "s|{{BOARD_API_PORT}}|${BOARD_API_PORT}|g" \
  -e "s|{{N8N_PORT}}|${N8N_PORT}|g" \
  -e "s|{{N8N_OWNER_EMAIL}}|${N8N_OWNER_EMAIL}|g" \
  -e "s|{{N8N_OWNER_PASSWORD_HASH}}|${N8N_OWNER_PASSWORD_HASH_ESCAPED}|g" \
  -e "s|{{N8N_OWNER_FIRST_NAME}}|Admin|g" \
  -e "s|{{N8N_OWNER_LAST_NAME}}|ADT|g" \
  "$TEMPLATES/docker-compose.yml" > "$REPO_ROOT/docker-compose.yml"
ok "docker-compose.yml"

# openclaw.json — always regenerate (idempotent, uses fresh values)
OPENCLAW_JSON="$REPO_ROOT/openclaw/data/openclaw.json"
# Backup existing config (so users can recover if the fresh render is wrong).
if [[ -f "$OPENCLAW_JSON" ]]; then
  cp "$OPENCLAW_JSON" "$OPENCLAW_JSON.bak"
fi

# Generate openclaw.json inline via python (Python is required by an MCP
# server anyway, and this avoids the fragile multi-line sed/awk dance).
if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 is required to generate openclaw.json but was not found in PATH."
  exit 1
fi

OPENCLAW_GATEWAY_PASSWORD="$MASTER_PASSWORD" \
LITELLM_BASE_URL="$LITELLM_BASE_URL" \
python3 - "$OPENCLAW_JSON" <<'PY'
import json, os, sys
password = os.environ.get("OPENCLAW_GATEWAY_PASSWORD", "")
base_url = os.environ["LITELLM_BASE_URL"].rstrip("/")
gateway = {"mode": "local"}
if password:
    gateway["auth"] = {"mode": "password", "password": password}
config = {
    "gateway": gateway,
    "models": {
        "providers": {
            "litellm": {
                "baseUrl": f"{base_url}/litellm/v1",
                "apiKey": "${LITELLM_API_KEY}",
                "api": "openai-completions",
                "models": [
                    {
                        "id": "anthropic--claude-opus-4-6",
                        "name": "Claude Opus 4.6",
                        "reasoning": True,
                        "input": ["text", "image"],
                    }
                ],
            }
        }
    },
}
with open(sys.argv[1], "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY
ok "openclaw/data/openclaw.json"

# project-lead USER.md
PL_USER="$REPO_ROOT/openclaw/data/workspace-project-lead/USER.md"
if [[ -f "$PL_USER" ]]; then
  note "openclaw/data/workspace-project-lead/USER.md already exists — kept as-is"
else
  cp "$AGENT_TEMPLATES/USER.md" "$PL_USER"
  ok "openclaw/data/workspace-project-lead/USER.md (from template)"
fi

# ─── [4] verify symlinks ───────────────────────────────────────────────────
step "Verifying agent workspace symlinks"

AGENTS=(project-lead architect backend frontend uiux reviewer qa)
SHARED_USER="/home/node/.openclaw/adt-shared/USER.md"
SHARED_CONV="/home/node/.openclaw/adt-shared/CONVENTIONS.md"
SHARED_DOCS_STRUCT="/home/node/.openclaw/adt-shared/DOCS-REPO-STRUCTURE.md"

SYMLINK_ISSUES=0
for agent in "${AGENTS[@]}"; do
  ws="$REPO_ROOT/openclaw/data/workspace-$agent"
  for pair in "USER.md:$SHARED_USER" "CONVENTIONS.md:$SHARED_CONV" "DOCS-REPO-STRUCTURE.md:$SHARED_DOCS_STRUCT"; do
    file="${pair%%:*}"
    target="${pair#*:}"
    path="$ws/$file"
    if [[ -L "$path" ]]; then
      actual=$(readlink "$path")
      if [[ "$actual" != "$target" ]]; then
        warn "$agent/$file → $actual (expected $target) — repairing"
        rm -f "$path"; ln -s "$target" "$path"
      fi
    elif [[ -f "$path" ]]; then
      warn "$agent/$file is a regular file — leaving alone (delete it manually if you want the symlink back)"
      SYMLINK_ISSUES=$((SYMLINK_ISSUES + 1))
    else
      ln -s "$target" "$path"
    fi
  done
done
if [[ $SYMLINK_ISSUES -eq 0 ]]; then
  ok "all 6 agent workspaces point at adt-shared/USER.md, adt-shared/CONVENTIONS.md, and adt-shared/DOCS-REPO-STRUCTURE.md"
else
  warn "$SYMLINK_ISSUES workspace file(s) are regular files, not symlinks — see notes above"
fi

# ─── [5] build & start container ───────────────────────────────────────────
step "Building and starting container"

BUILD_LOG="$LOG_DIR/docker-build.log"
sub "docker compose up -d --build ${DIM}(logs: $BUILD_LOG)${NC}"

if ! docker compose -f "$REPO_ROOT/docker-compose.yml" up -d --build \
        > "$BUILD_LOG" 2>&1; then
  fail "docker compose failed to build/start the container."
  echo "  Last 30 lines of $BUILD_LOG:"
  tail -30 "$BUILD_LOG" | sed 's/^/    /'
  exit 1
fi
ok "container built and started"

# Resolve the actual container name from compose (in case compose mangled it).
CONTAINER_ID=$(docker compose -f "$REPO_ROOT/docker-compose.yml" ps -q openclaw 2>/dev/null | head -1)
if [[ -z "$CONTAINER_ID" ]]; then
  fail "Could not find the started container. Check '$BUILD_LOG'."
  exit 1
fi
CONTAINER_NAME_ACTUAL=$(docker inspect -f '{{.Name}}' "$CONTAINER_ID" | sed 's|^/||')
note "container: $CONTAINER_NAME_ACTUAL"

sub "waiting for the gateway to become ready (up to 60s)…"
HEALTH_URL="http://localhost:18789/health"
READY=0
for i in $(seq 1 30); do
  # Prefer container-internal check because 'health' isn't reliably exposed
  # externally in every OpenClaw build.
  if docker exec "$CONTAINER_NAME_ACTUAL" curl -sSf --max-time 1 "$HEALTH_URL" >/dev/null 2>&1; then
    READY=1
    break
  fi
  # Fallback: `openclaw gateway status` exits 0 when ready.
  if docker exec "$CONTAINER_NAME_ACTUAL" openclaw gateway status >/dev/null 2>&1; then
    READY=1
    break
  fi
  # Bail out if the container has died (restart-looping counts).
  if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME_ACTUAL" 2>/dev/null | grep -q true; then
    fail "Container is not running any more — likely a fatal config error."
    echo "  Last 30 lines of container logs:"
    docker logs --tail 30 "$CONTAINER_NAME_ACTUAL" 2>&1 | sed 's/^/    /'
    echo "  Stability bundles (if any) are in data/logs/stability/."
    exit 1
  fi
  sleep 2
done

if [[ $READY -ne 1 ]]; then
  fail "Gateway did not become ready within 60 seconds."
  echo "  Last 30 lines of container logs:"
  docker logs --tail 30 "$CONTAINER_NAME_ACTUAL" 2>&1 | sed 's/^/    /'
  echo
  echo "  Diagnostics:"
  echo "    ${BULLET} docker logs $CONTAINER_NAME_ACTUAL"
  echo "    ${BULLET} docker exec $CONTAINER_NAME_ACTUAL openclaw gateway status --deep"
  echo "    ${BULLET} check data/logs/stability/ for startup_failed bundles"
  exit 1
fi
ok "gateway is ready"

sub "waiting for board-api to become healthy…"
BOARD_READY=0
for i in $(seq 1 30); do
  if docker exec "${CONTAINER_NAME_ACTUAL}" curl -sSf --max-time 1 "http://board-api:3000/health" >/dev/null 2>&1; then
    BOARD_READY=1
    break
  fi
  sleep 2
done
if [[ $BOARD_READY -ne 1 ]]; then
  warn "board-api did not respond within 60s — check 'docker compose logs board-api'"
fi

# ─── [6] register agents ───────────────────────────────────────────────────
step "Registering ADT agents"

# The 7 ADT agents that back the workspaces already committed in the repo.
# Order matters only for cosmetics; project-lead first so it's the natural
# 'main' replacement.
ADT_AGENTS=(project-lead architect backend frontend uiux reviewer qa)
ADT_MODEL="litellm/anthropic--claude-opus-4-6"

# `openclaw agents add` is idempotent-ish: it errors if the agent already
# exists. Skip agents that are already present so re-runs of setup.sh don't
# fail on a second boot.
EXISTING_AGENTS=$(docker exec "$CONTAINER_NAME_ACTUAL" openclaw agents list 2>/dev/null \
                    | awk '/^- /{gsub(/[()]/,""); print $2}')

ADD_LOG="$LOG_DIR/agents-add.log"
: > "$ADD_LOG"

for agent in "${ADT_AGENTS[@]}"; do
  if grep -qxF "$agent" <<<"$EXISTING_AGENTS"; then
    note "$agent already registered — skipping"
    continue
  fi
  sub "adding $agent"
  if docker exec "$CONTAINER_NAME_ACTUAL" openclaw agents add \
        --workspace "/home/node/.openclaw/workspace-$agent" \
        --model "$ADT_MODEL" \
        --non-interactive \
        "$agent" >>"$ADD_LOG" 2>&1; then
    ok "$agent registered"
  else
    fail "Failed to register $agent — see $ADD_LOG"
    tail -20 "$ADD_LOG" | sed 's/^/    /'
    exit 1
  fi
done

# ─── [7] apply patches ─────────────────────────────────────────────────────
step "Applying OpenClaw patches"

PATCHES_DIR="/home/node/.openclaw/adt-shared/patches"
PATCH_LOG="$LOG_DIR/patches.log"
: > "$PATCH_LOG"

apply_patch() {
  local name="$1" file="$2"
  sub "$name"
  if docker exec "$CONTAINER_NAME_ACTUAL" openclaw config patch --file "$file" \
        >>"$PATCH_LOG" 2>&1; then
    ok "$name applied"
  else
    fail "Failed to apply $name — see $PATCH_LOG"
    tail -20 "$PATCH_LOG" | sed 's/^/    /'
    exit 1
  fi
}

apply_patch "default-agent-patch (make project-lead the front door)" "$PATCHES_DIR/default-agent-patch.json5"
apply_patch "mcp-patch (13 MCP servers, per-agent scoping)"           "$PATCHES_DIR/mcp-patch.json5"

sub "validating final config"
if docker exec "$CONTAINER_NAME_ACTUAL" openclaw config validate \
      >>"$PATCH_LOG" 2>&1; then
  ok "config valid"
else
  fail "Config validation failed — see $PATCH_LOG"
  tail -20 "$PATCH_LOG" | sed 's/^/    /'
  exit 1
fi

# Patches say "Restart the gateway to apply" — do that transparently so the
# user doesn't need to know the two-step dance.
sub "restarting container so the patches take effect"
if docker restart "$CONTAINER_NAME_ACTUAL" >/dev/null 2>&1; then
  # Wait for readiness again (same probe as [5]).
  READY=0
  for i in $(seq 1 30); do
    if docker exec "$CONTAINER_NAME_ACTUAL" curl -sSf --max-time 1 "$HEALTH_URL" >/dev/null 2>&1; then
      READY=1; break
    fi
    sleep 2
  done
  if [[ $READY -eq 1 ]]; then
    ok "container restarted, gateway back up"
  else
    warn "container restarted but gateway is slow to come back — check 'docker logs $CONTAINER_NAME_ACTUAL'"
  fi
else
  warn "restart failed — you may need to run 'docker restart $CONTAINER_NAME_ACTUAL' manually"
fi

# ─── done ──────────────────────────────────────────────────────────────────
echo
echo "${GREEN}${BOLD}✔  ADT is up and running.${NC}"
echo
echo "  Gateway:      ${BOLD}http://localhost:${GATEWAY_PORT}${NC}"
echo "  n8n:          ${BOLD}http://localhost:${N8N_PORT}${NC}  ${DIM}(${N8N_OWNER_EMAIL} / master password)${NC}"
echo "  Container:    ${BOLD}${CONTAINER_NAME_ACTUAL}${NC}"
if [[ -n "$MASTER_PASSWORD" ]]; then
  echo "  Auth:         master password (set during this run)"
else
  echo "  Auth:         ${YELLOW}none${NC} ${DIM}(local-only)${NC}"
fi
echo
echo "  ${BOLD}Next steps${NC}"
echo "    ${BULLET} Open the gateway URL above. You'll land on ${BOLD}project-lead${NC} (Atlas 🧭)."
echo "    ${BULLET} Say hello — Atlas will run ${DIM}onboard-project${NC} to interrogate you and set up the team."
echo "    ${BULLET} To stop:    ${DIM}docker compose down${NC}"
echo "    ${BULLET} To restart: ${DIM}docker compose up -d${NC}"
echo "    ${BULLET} Logs:       ${DIM}docker logs -f ${CONTAINER_NAME_ACTUAL}${NC}"
echo
