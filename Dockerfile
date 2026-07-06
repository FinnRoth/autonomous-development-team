FROM ghcr.io/openclaw/openclaw:latest

USER root

# Base Python (for sequential-thinking and misc MCP scripts), git host CLIs,
# Playwright system deps, and Docker-in-Docker (daemon + CLI + compose plugin).
# Browsers themselves are installed lazily by QA's `playwright-init` skill on
# first run (`npx playwright install --with-deps chromium`).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv \
        ca-certificates curl gnupg iptables uidmap \
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
    # Docker-in-Docker: full daemon (`docker-ce`) + CLI + compose/buildx plugins.
    # Runs inside this container against a container-local /var/lib/docker so
    # nothing the agents build or run leaks to the host. Requires
    # `privileged: true` in docker-compose.yml.
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin && \
    # Let the `node` user talk to the in-container docker socket without sudo.
    usermod -aG docker node && \
    rm -rf /var/lib/apt/lists/*

# Entrypoint wrapper: start dockerd in the background (as root, needed for
# namespaces/cgroups/iptables), wait for the socket, then drop back to `node`
# and exec the original OpenClaw CMD under tini. Tini stays PID 1 so process
# reaping and signal forwarding continue to work exactly as in the base image.
COPY --chmod=0755 <<'EOF' /usr/local/bin/adt-entrypoint.sh
#!/bin/sh
set -e

# Start the docker daemon in the background. It writes to /var/lib/docker,
# which docker-compose.yml backs with a Docker-managed named volume so image
# layers survive `docker compose restart` and are wiped by `docker compose down -v`.
if [ ! -S /var/run/docker.sock ]; then
    dockerd --host=unix:///var/run/docker.sock >/var/log/dockerd.log 2>&1 &
    # Wait up to 30s for the socket to appear before handing off.
    for i in $(seq 1 60); do
        [ -S /var/run/docker.sock ] && break
        sleep 0.5
    done
    # Socket is root:docker 0660; group membership handles access for `node`.
fi

# Hand off to the original OpenClaw CMD as the `node` user. `exec` replaces
# this shell so tini (PID 1) sees `node` as its direct child.
exec setpriv --reuid=node --regid=node --init-groups "$@"
EOF

USER root
CMD ["/usr/local/bin/adt-entrypoint.sh", "node", "openclaw.mjs", "gateway"]
