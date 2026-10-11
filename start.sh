#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="devilutionx-dev:latest"
CONTAINER_NAME="devilutionx-dev"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKSPACE_DIR="${PROJECT_DIR}/workspace"
CONTAINER_CLAUDE_DIR="${PROJECT_DIR}/.container-claude"
CONTAINER_CLAUDE_JSON="${PROJECT_DIR}/.claude.json"
CONTAINER_BASH_HIST="${PROJECT_DIR}/.bash_history"

# Auto-detect whether sudo is needed for Docker daemon
DOCKER_CMD="docker"
if ! docker info >/dev/null 2>&1; then
  if sudo docker info >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
  else
    echo "ERROR: Unable to communicate with Docker daemon even with sudo." >&2
    exit 1
  fi
fi

# Ensure project-local prerequisites exist
mkdir -p "${WORKSPACE_DIR}" "${CONTAINER_CLAUDE_DIR}"
touch "${CONTAINER_BASH_HIST}"

# Copy host credentials into project if not yet initialized
if [ ! -f "${CONTAINER_CLAUDE_JSON}" ]; then
  if [ -f "${HOME}/.claude.json" ]; then
    echo "==> Syncing initial Claude credentials from host ~/.claude.json..."
    cp "${HOME}/.claude.json" "${CONTAINER_CLAUDE_JSON}"
  else
    touch "${CONTAINER_CLAUDE_JSON}"
  fi
fi

# Fix ownership so non-root container user (UID 1000) can read/write them
${DOCKER_CMD} run --rm \
  -v "${PROJECT_DIR}:/mnt" \
  debian:testing-slim \
  chown -R 1000:1000 /mnt/workspace /mnt/.container-claude /mnt/.claude.json /mnt/.bash_history 2>/dev/null || true

# 1. Build image if it does not exist
if ! ${DOCKER_CMD} image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "==> Image '${IMAGE_NAME}' not found. Building..."
  ${DOCKER_CMD} build -t "${IMAGE_NAME}" -f "${PROJECT_DIR}/Dockerfile" "${PROJECT_DIR}"
fi

# 2. Start container if not running
if ! ${DOCKER_CMD} ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  if ${DOCKER_CMD} ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    echo "==> Removing stopped container '${CONTAINER_NAME}'..."
    ${DOCKER_CMD} rm "${CONTAINER_NAME}" >/dev/null
  fi

  echo "==> Starting '${CONTAINER_NAME}'..."
  ${DOCKER_CMD} run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -u developer \
    -v "${WORKSPACE_DIR}:/workspace" \
    -v "${CONTAINER_CLAUDE_JSON}:/home/developer/.claude.json" \
    -v "${CONTAINER_CLAUDE_DIR}:/home/developer/.claude" \
    -v "${CONTAINER_BASH_HIST}:/home/developer/.bash_history" \
    "${IMAGE_NAME}" \
    tail -f /dev/null >/dev/null
fi

# 3. Drop into interactive container shell as developer user
echo "==> Attaching to ${CONTAINER_NAME}..."
${DOCKER_CMD} exec -it -u developer "${CONTAINER_NAME}" /bin/bash