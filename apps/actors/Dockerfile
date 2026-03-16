## syntax=docker/dockerfile:1.7
ARG BUN_BUILDER_TAG=1.3-alpine
ARG CODE_VARIANT=prod
FROM oven/bun:${BUN_BUILDER_TAG} AS builder
WORKDIR /workspace

COPY . .
RUN --mount=type=cache,target=/root/.bun/install/cache \
	if [ "${CODE_VARIANT}" = "dev" ]; then \
		bun install --frozen-lockfile --filter actors; \
	else \
		bun install --frozen-lockfile --production --filter actors; \
	fi

FROM scratch
WORKDIR /workspace
COPY --from=builder /workspace/package.json /workspace/package.json
COPY --from=builder /workspace/bun.lock /workspace/bun.lock
COPY --from=builder /workspace/bunfig.toml /workspace/bunfig.toml
COPY --from=builder /workspace/node_modules /workspace/node_modules
COPY --from=builder /workspace/apps/actors /workspace/apps/actors
COPY --from=builder /workspace/packages/actors /workspace/packages/actors