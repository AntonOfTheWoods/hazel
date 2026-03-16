ARG BUN_BUILDER_TAG=1.3-alpine
FROM oven/bun:${BUN_BUILDER_TAG} AS builder
WORKDIR /workspace

COPY . .
RUN bun install --frozen-lockfile
RUN bun run --cwd apps/link-preview-worker test

RUN mkdir -p /artifact/workspace
RUN cp -R /workspace/. /artifact/workspace/

FROM scratch
WORKDIR /workspace
COPY --from=builder /artifact/workspace/ /workspace/
