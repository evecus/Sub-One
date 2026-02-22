# Stage 1: Build
FROM --platform=$BUILDPLATFORM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache python3 make g++
COPY package*.json ./
RUN npm install
COPY . .

RUN npm run build

RUN node_modules/.bin/esbuild docker/docker-server.ts \
    --bundle \
    --platform=node \
    --target=node20 \
    --format=esm \
    --external:better-sqlite3 \
    --external:express \
    --outfile=dist/server.mjs

# Stage 2: 只装运行时必要的两个包
FROM node:20-alpine AS deps

WORKDIR /app

RUN apk add --no-cache python3 make g++
RUN npm install --no-save express@4 better-sqlite3 && \
    apk del python3 make g++

# Stage 3: 最终镜像
FROM node:20-alpine

LABEL org.opencontainers.image.source=https://github.com/binbankm/Sub-One
LABEL org.opencontainers.image.description="Sub-One subscription management"
LABEL org.opencontainers.image.licenses=MIT

WORKDIR /app
ENV PORT=3055
ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

RUN mkdir -p /app/data

EXPOSE 3055
CMD ["node", "dist/server.mjs"]
