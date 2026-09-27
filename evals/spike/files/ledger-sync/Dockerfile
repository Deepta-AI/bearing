FROM node:20.18-alpine
# better-sqlite3 compiles from source on musl: prebuilt binaries are glibc only.
RUN apk add --no-cache python3 make g++
WORKDIR /app
COPY package.json ./
RUN corepack enable && pnpm install --prod
COPY src ./src
USER node
ENTRYPOINT ["node", "src/cli.js"]
