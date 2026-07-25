#!/bin/zsh
# Run a Codex task non-interactively with the flags this repo needs.
#
#   scripts/codex-task.sh <prompt-file> [sandbox-mode] [workdir]
#   cat prompt.md | scripts/codex-task.sh - read-only
#
# sandbox-mode defaults to workspace-write. Use read-only for investigations.
# The transcript is written to .codex-logs/ so a task can be reviewed after the
# fact, and so a dropped connection leaves evidence of how far Codex got.
#
# mcp_servers is cleared on every run: ~/.codex/config.toml declares the
# computer-use server with a relative command and cwd ".", so starting Codex
# from any other directory fails and takes the whole tool layer down with it.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

PROMPT_SOURCE="${1:-}"
SANDBOX="${2:-workspace-write}"
WORKDIR="${3:-$REPO_ROOT}"

if [[ -z "${PROMPT_SOURCE}" ]]; then
  echo "usage: scripts/codex-task.sh <prompt-file|-> [sandbox-mode] [workdir]" >&2
  exit 64
fi

if [[ "${PROMPT_SOURCE}" == "-" ]]; then
  PROMPT="$(cat)"
else
  if [[ ! -f "${PROMPT_SOURCE}" ]]; then
    echo "prompt file not found: ${PROMPT_SOURCE}" >&2
    exit 66
  fi
  PROMPT="$(cat "${PROMPT_SOURCE}")"
fi

if [[ -z "${PROMPT// /}" ]]; then
  echo "prompt is empty" >&2
  exit 65
fi

LOG_DIR="${CODEX_LOG_DIR:-${REPO_ROOT}/.codex-logs}"
mkdir -p "${LOG_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LABEL="$(basename "${PROMPT_SOURCE}" .md)"
[[ "${PROMPT_SOURCE}" == "-" ]] && LABEL="stdin"
LOG_FILE="${LOG_DIR}/${STAMP}-${LABEL}.log"

echo "Codex task"
echo "  prompt:  ${PROMPT_SOURCE}"
echo "  sandbox: ${SANDBOX}"
echo "  workdir: ${WORKDIR}"
echo "  log:     ${LOG_FILE}"
echo

codex exec \
  --sandbox "${SANDBOX}" \
  --skip-git-repo-check \
  -c 'mcp_servers={}' \
  -C "${WORKDIR}" \
  "${PROMPT}" 2>&1 | tee "${LOG_FILE}"
