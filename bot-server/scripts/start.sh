#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Memora Bot Server – One-command Startup
#
# Usage:
#   chmod +x scripts/start.sh
#   ./scripts/start.sh
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "========================================"
echo "  Memora Bot Server – Quick Start"
echo "========================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Ensure .env exists
# ---------------------------------------------------------------------------
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "[1/3] Created .env from .env.example"
    echo ""
    echo "  >>> IMPORTANT: Edit .env with your API keys before starting <<<"
    echo ""
    echo "  Required:"
    echo "    API_KEY  – must match BotMeetingConfig in the iOS app"
    echo ""
    echo "  Platform-specific (only if using that platform):"
    echo "    GOOGLE_SERVICE_ACCOUNT_JSON  – GCP service account for Google Meet"
    echo "    ZOOM_CLIENT_ID / ZOOM_CLIENT_SECRET  – Zoom Server-to-Server OAuth"
    echo "    TEAMS_CLIENT_ID / TEAMS_CLIENT_SECRET  – Azure AD for Teams"
    echo ""
    echo "  After editing, re-run:"
    echo "    ./scripts/start.sh"
    echo ""
    read -rp "  Press Enter to open .env for editing now (or Ctrl-C to exit)..." _
    ${EDITOR:-nano} .env
  else
    echo "[!] ERROR: .env.example not found. Cannot create .env."
    exit 1
  fi
else
  echo "[1/3] .env already exists, skipping"
fi

# ---------------------------------------------------------------------------
# 2. Build TypeScript
# ---------------------------------------------------------------------------
echo "[2/3] Building TypeScript..."
if [ -f package.json ]; then
  if command -v npm &> /dev/null; then
    npm run build
  else
    echo "  npm not found locally – skipping tsc build (Docker will use pre-built dist/)"
  fi
else
  echo "  package.json not found – skipping tsc build"
fi

# ---------------------------------------------------------------------------
# 3. Start Docker Compose
# ---------------------------------------------------------------------------
echo "[3/3] Starting Docker containers..."
docker compose up -d --build

echo ""
echo "========================================"
echo "  Bot server is running."
echo "  Health check: http://localhost:3000/health"
echo ""
echo "  View logs:  docker compose logs -f"
echo "  Stop:       docker compose down"
echo "========================================"
