#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$REPO_ROOT/data/adt-shared/templates"

# ─── colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${GREEN}▶${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
section() { echo -e "\n${BOLD}$*${NC}"; }

# ─── prompt helper ──────────────────────────────────────────────────────────
ask() {
  local prompt="$1" default="${2:-}" var
  if [[ -n "$default" ]]; then
    read -rp "$(echo -e "${BOLD}${prompt}${NC} [${default}]: ")" var
    echo "${var:-$default}"
  else
    read -rp "$(echo -e "${BOLD}${prompt}${NC}: ")" var
    echo "$var"
  fi
}

ask_secret() {
  local prompt="$1" var
  read -rsp "$(echo -e "${BOLD}${prompt}${NC}: ")" var; echo >&2
  echo "$var"
}

ask_choice() {
  local prompt="$1" default="$2"; shift 2; local options=("$@")
  echo -e "${BOLD}${prompt}${NC}" >&2
  for i in "${!options[@]}"; do
    echo -e "  $((i+1))) ${options[$i]}" >&2
  done
  local choice
  read -rp "$(echo -e "Choose [${default}]: ")" choice
  choice="${choice:-$default}"
  echo "${options[$((choice-1))]}"
}

# ─── checks ─────────────────────────────────────────────────────────────────
section "Checking prerequisites"
command -v docker >/dev/null 2>&1 || { echo -e "${RED}✗ docker not found${NC}"; exit 1; }
info "docker found"

# ─── gather config ──────────────────────────────────────────────────────────
section "Configuration"

CONTAINER_NAME=$(ask "Container name" "adt")
GATEWAY_PORT=$(ask "Gateway port" "18789")
OPENCLAW_GATEWAY_PASSWORD=$(ask_secret "OpenClaw gateway password")

echo
LITELLM_BASE_URL=$(ask "LiteLLM base URL" "http://host.docker.internal:6655")
LITELLM_API_KEY=$(ask_secret "LiteLLM API key")

echo
FIGMA_TOKEN=$(ask_secret "Figma personal access token (leave blank to skip)")
GIT_HOST_CLI=$(ask_choice "Git host CLI" "1" "gh (GitHub)" "glab (GitLab)" "tea (Gitea)")
GIT_HOST_CLI="${GIT_HOST_CLI%% *}"  # keep only the CLI name before the space
GIT_HOST_TOKEN=$(ask_secret "Git host token (leave blank to skip)")

# ─── generate docker-compose.yml ────────────────────────────────────────────
section "Generating docker-compose.yml"

sed \
  -e "s|{{CONTAINER_NAME}}|${CONTAINER_NAME}|g" \
  -e "s|{{GATEWAY_PORT}}|${GATEWAY_PORT}|g" \
  -e "s|{{OPENCLAW_GATEWAY_PASSWORD}}|${OPENCLAW_GATEWAY_PASSWORD}|g" \
  -e "s|{{LITELLM_BASE_URL}}|${LITELLM_BASE_URL}|g" \
  -e "s|{{LITELLM_API_KEY}}|${LITELLM_API_KEY}|g" \
  -e "s|{{FIGMA_TOKEN}}|${FIGMA_TOKEN}|g" \
  -e "s|{{GIT_HOST_TOKEN}}|${GIT_HOST_TOKEN}|g" \
  -e "s|{{GIT_HOST_CLI}}|${GIT_HOST_CLI}|g" \
  "$TEMPLATES/docker-compose.yml" > "$REPO_ROOT/docker-compose.yml"

info "docker-compose.yml written"

# ─── project-lead USER.md ───────────────────────────────────────────────────
section "Setting up project-lead USER.md"

PL_USER="$REPO_ROOT/data/workspace-project-lead/USER.md"
if [[ -f "$PL_USER" ]]; then
  warn "workspace-project-lead/USER.md already exists — skipping (delete it manually to re-run)"
else
  cp "$TEMPLATES/USER.md" "$PL_USER"
  info "workspace-project-lead/USER.md created from template"
fi

# ─── symlinks ───────────────────────────────────────────────────────────────
section "Creating symlinks"

AGENTS=(architect backend frontend uiux reviewer qa)
SHARED_USER="/home/node/.openclaw/adt-shared/USER.md"
SHARED_CONV="/home/node/.openclaw/adt-shared/CONVENTIONS.md"

for agent in "${AGENTS[@]}"; do
  ws="$REPO_ROOT/data/workspace-$agent"

  # USER.md symlink
  if [[ -L "$ws/USER.md" ]]; then
    info "workspace-$agent/USER.md symlink already in place"
  elif [[ -f "$ws/USER.md" ]]; then
    warn "workspace-$agent/USER.md is a regular file — skipping (remove it to let setup create the symlink)"
  else
    ln -s "$SHARED_USER" "$ws/USER.md"
    info "workspace-$agent/USER.md → $SHARED_USER"
  fi

  # CONVENTIONS.md symlink
  if [[ -L "$ws/CONVENTIONS.md" ]]; then
    info "workspace-$agent/CONVENTIONS.md symlink already in place"
  elif [[ -f "$ws/CONVENTIONS.md" ]]; then
    warn "workspace-$agent/CONVENTIONS.md is a regular file — skipping"
  else
    ln -s "$SHARED_CONV" "$ws/CONVENTIONS.md"
    info "workspace-$agent/CONVENTIONS.md → $SHARED_CONV"
  fi
done

# ─── done ───────────────────────────────────────────────────────────────────
echo
echo -e "${GREEN}${BOLD}Setup complete.${NC}"
echo -e "Run ${BOLD}docker compose up -d --build${NC} to start ADT."
