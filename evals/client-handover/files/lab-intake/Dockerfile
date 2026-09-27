FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
COPY third_party ./third_party
RUN npm ci --omit=dev
COPY src ./src
CMD ["node", "src/server.js"]
