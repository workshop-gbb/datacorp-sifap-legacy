FROM node:24-alpine@sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf
WORKDIR /app
COPY --chown=node:node server.mjs session-store.mjs messages.mjs credentials.mjs landing.html ./
USER node
EXPOSE 8082
HEALTHCHECK --interval=15s --timeout=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1:8082/internal/health || exit 1
CMD ["node", "server.mjs"]
