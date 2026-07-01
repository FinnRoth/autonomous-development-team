FROM ghcr.io/openclaw/openclaw:latest

USER root

# Base Python (for sequential-thinking and misc MCP scripts), git host CLIs,
# and Playwright system deps. Browsers themselves are installed lazily by QA's
# `playwright-init` skill on first run (`npx playwright install --with-deps chromium`).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv \
        ca-certificates curl gnupg \
        # Playwright/Chromium runtime deps
        libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
        libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
        libgbm1 libpango-1.0-0 libcairo2 libasound2 fonts-liberation \
        && \
    # GitHub CLI (gh) — host-agnostic enough for our purposes when paired with GIT_HOST_CLI env var.
    (curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg) && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

USER node
