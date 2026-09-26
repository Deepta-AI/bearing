# Build with the dev toolchain, then ship only the standalone server that
# `output: "standalone"` produces, as the unprivileged node user.
FROM node:24-alpine AS build
WORKDIR /src
RUN corepack enable
# pnpm-lock.yaml is committed (make setup writes it); the glob keeps a first
# build working before it exists, at the cost of an unpinned resolution.
COPY package.json pnpm-lock.yaml* ./
RUN if [ -f pnpm-lock.yaml ]; then pnpm fetch && pnpm install --frozen-lockfile --offline; \
    else echo "lockfile: none committed, installing unfrozen (run pnpm install and commit pnpm-lock.yaml)"; pnpm install; fi
COPY . .
# NEXT_PUBLIC_ variables are inlined at build time and are public. Never a secret here.
ARG NEXT_PUBLIC_APP_NAME=__REPO_NAME__
ENV NEXT_PUBLIC_APP_NAME=$NEXT_PUBLIC_APP_NAME NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build

FROM node:24-alpine
ENV NODE_ENV=production PORT=3000 HOSTNAME=0.0.0.0 NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY --from=build --chown=node:node /src/.next/standalone ./
COPY --from=build --chown=node:node /src/.next/static ./.next/static
COPY --from=build --chown=node:node /src/public ./public
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:3000/api/healthz >/dev/null || exit 1
CMD ["node", "server.js"]
