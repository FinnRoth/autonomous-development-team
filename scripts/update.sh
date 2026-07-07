#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}▶${NC} $*"; }
fail()  { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

# ─── check symlinks are intact ──────────────────────────────────────────────
echo -e "${BOLD}Checking symlinks${NC}"

AGENTS=(architect backend frontend uiux reviewer qa)
EXPECTED_USER="/home/node/.openclaw/adt-shared/USER.md"
EXPECTED_CONV="/home/node/.openclaw/adt-shared/CONVENTIONS.md"

for agent in "${AGENTS[@]}"; do
  ws="$REPO_ROOT/openclaw/data/workspace-$agent"

  # USER.md
  if [[ ! -L "$ws/USER.md" ]]; then
    fail "workspace-$agent/USER.md is not a symlink — it has been locally modified. Restore it to a symlink before updating."
  fi
  actual=$(readlink "$ws/USER.md")
  [[ "$actual" == "$EXPECTED_USER" ]] || \
    fail "workspace-$agent/USER.md points to '$actual', expected '$EXPECTED_USER'. Fix before updating."

  # CONVENTIONS.md
  if [[ ! -L "$ws/CONVENTIONS.md" ]]; then
    fail "workspace-$agent/CONVENTIONS.md is not a symlink — it has been locally modified. Restore it to a symlink before updating."
  fi
  actual=$(readlink "$ws/CONVENTIONS.md")
  [[ "$actual" == "$EXPECTED_CONV" ]] || \
    fail "workspace-$agent/CONVENTIONS.md points to '$actual', expected '$EXPECTED_CONV'. Fix before updating."

  info "workspace-$agent OK"
done

# ─── pull ───────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}Pulling latest${NC}"
git -C "$REPO_ROOT" pull --ff-only || \
  fail "git pull failed. Resolve conflicts manually, then re-run update.sh."

info "Up to date."
echo
echo -e "${GREEN}${BOLD}Update complete.${NC}"
echo -e "Run ${BOLD}docker compose up -d --build${NC} to apply changes."
