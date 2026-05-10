# ---------------------------------------------------------------------------
# Memora Bot Server – Production Docker Image
# ---------------------------------------------------------------------------
FROM node:22-slim

WORKDIR /app

# ---------------------------------------------------------------------------
# Labels (OCI Image Format)
# ---------------------------------------------------------------------------
LABEL org.opencontainers.image.title="Memora Bot Server"
LABEL org.opencontainers.image.description="Bot server that joins online meetings (Zoom, Google Meet, Teams) and captures audio for the Memora iOS app"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/hashimotokenichi/Memora"
LABEL org.opencontainers.image.licenses="MIT"

# ---------------------------------------------------------------------------
# Dependencies layer (cached separately from source)
# ---------------------------------------------------------------------------
COPY package.json package-lock.json* ./
RUN npm ci --only=production \
    && npm cache clean --force

# ---------------------------------------------------------------------------
# Application code (only compiled output)
# ---------------------------------------------------------------------------
COPY dist/ ./dist/

# ---------------------------------------------------------------------------
# Runtime defaults (override via docker-compose / env)
# ---------------------------------------------------------------------------
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# ---------------------------------------------------------------------------
# Security: run as non-root
# ---------------------------------------------------------------------------
USER node

# ---------------------------------------------------------------------------
# Health check via built-in /health endpoint
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
CMD ["node", "dist/index.js"]
