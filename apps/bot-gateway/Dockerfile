## syntax=docker/dockerfile:1.7
ARG BUN_BUILDER_TAG=1.3-alpine
FROM oven/bun:${BUN_BUILDER_TAG} AS builder
WORKDIR /workspace

COPY . .
RUN --mount=type=cache,target=/root/.bun/install/cache bun install --frozen-lockfile
RUN bun run --cwd apps/bot-gateway typecheck

RUN mkdir -p /artifact/workspace
RUN cp -R /workspace/. /artifact/workspace/

FROM scratch
WORKDIR /workspace
COPY --from=builder /artifact/workspace/ /workspace/
