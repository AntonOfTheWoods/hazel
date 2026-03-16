## syntax=docker/dockerfile:1.7
ARG BUN_BUILDER_TAG=1.3-alpine
FROM oven/bun:${BUN_BUILDER_TAG} AS builder
WORKDIR /workspace

COPY . .
RUN --mount=type=cache,target=/root/.bun/install/cache bun install --frozen-lockfile --production --filter @hazel/electric-proxy

FROM scratch
WORKDIR /workspace
COPY --from=builder /workspace/package.json /workspace/package.json
COPY --from=builder /workspace/bun.lock /workspace/bun.lock
COPY --from=builder /workspace/bunfig.toml /workspace/bunfig.toml
COPY --from=builder /workspace/node_modules /workspace/node_modules
COPY --from=builder /workspace/apps/electric-proxy /workspace/apps/electric-proxy
COPY --from=builder /workspace/packages/auth /workspace/packages/auth
COPY --from=builder /workspace/packages/db /workspace/packages/db
COPY --from=builder /workspace/packages/effect-bun /workspace/packages/effect-bun
COPY --from=builder /workspace/packages/schema /workspace/packages/schema
