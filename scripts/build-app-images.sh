#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

readonly ALL_APPS=(
	"actors"
	"backend"
	"bot-gateway"
	"cluster"
	"docs"
	"electric-proxy"
	"landing"
	"link-preview-worker"
	"web"
)

BASE_REPO="ghcr.io/hazelchat/hazel/"
TAG=""
BUILDER_TAG=""
VARIANT="prod"
APPS_CSV=""
PUSH=false
JOBS=""
USE_BUILDX=false
CACHE_DIR=""
CACHE_REF=""

usage() {
	cat <<EOF
Build app code images for all non-desktop apps.

Usage:
	$(basename "$0") [--base <image-base>] [--tag <tag>] [--builder-tag <tag-or-digest>]
							 [--variant <dev|prod>] [--apps <comma-separated-apps>] [--push]
									 [--jobs <n>] [--buildx]
									 [--cache-dir <path>] [--cache-ref <registry-ref>]

Options:
  --base <image-base>  Base image repository prefix.
                       Default: ghcr.io/hazelchat/hazel/
  --tag <tag>          Image tag.
                       Default: git describe --tags
	--builder-tag <ref>  Value for Docker build arg BUN_BUILDER_TAG.
									 Supports digest-pinned forms (e.g. 1.3-alpine@sha256:...).
	--variant <value>    Build variant passed as CODE_VARIANT build arg.
									 Default: prod
	--apps <list>        Comma-separated app list to build.
									 Default: all apps
  --push               Push images after successful build.
	--jobs <n>           Number of parallel builds.
											 Default: half of host CPU cores (minimum 1)
	--buildx             Use docker buildx build.
											 Uses --load by default, or --push when --push is set.
	--cache-dir <path>   BuildKit local cache directory (requires --buildx).
	--cache-ref <ref>    BuildKit registry cache ref (requires --buildx).
  -h, --help           Show this help text.

Image naming:
  <base><app>-code:<tag>

Example:
	$(basename "$0")
	$(basename "$0") --variant dev --apps actors,link-preview-worker
	$(basename "$0") --builder-tag 1.3-alpine@sha256:deadbeef...
	$(basename "$0") --jobs 4 --buildx --cache-dir .cache/buildx
	$(basename "$0") --base ghcr.io/acme/hazel/ --tag v1.2.3 --push
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--base)
			[[ $# -ge 2 ]] || {
				echo "Error: --base requires a value" >&2
				exit 1
			}
			BASE_REPO="$2"
			shift 2
			;;
		--tag)
			[[ $# -ge 2 ]] || {
				echo "Error: --tag requires a value" >&2
				exit 1
			}
			TAG="$2"
			shift 2
			;;
		--builder-tag)
			[[ $# -ge 2 ]] || {
				echo "Error: --builder-tag requires a value" >&2
				exit 1
			}
			BUILDER_TAG="$2"
			shift 2
			;;
		--variant)
			[[ $# -ge 2 ]] || {
				echo "Error: --variant requires a value" >&2
				exit 1
			}
			VARIANT="$2"
			shift 2
			;;
		--apps)
			[[ $# -ge 2 ]] || {
				echo "Error: --apps requires a value" >&2
				exit 1
			}
			APPS_CSV="$2"
			shift 2
			;;
		--push)
			PUSH=true
			shift
			;;
		--jobs)
			[[ $# -ge 2 ]] || {
				echo "Error: --jobs requires a value" >&2
				exit 1
			}
			JOBS="$2"
			shift 2
			;;
		--buildx)
			USE_BUILDX=true
			shift
			;;
		--cache-dir)
			[[ $# -ge 2 ]] || {
				echo "Error: --cache-dir requires a value" >&2
				exit 1
			}
			CACHE_DIR="$2"
			shift 2
			;;
		--cache-ref)
			[[ $# -ge 2 ]] || {
				echo "Error: --cache-ref requires a value" >&2
				exit 1
			}
			CACHE_REF="$2"
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "Error: unknown option '$1'" >&2
			usage >&2
			exit 1
			;;
	esac
done

detect_host_cores() {
	local cores=""
	if command -v nproc >/dev/null 2>&1; then
		cores="$(nproc)"
	elif command -v getconf >/dev/null 2>&1; then
		cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
	fi

	if ! [[ "${cores}" =~ ^[1-9][0-9]*$ ]]; then
		cores=2
	fi

	echo "${cores}"
}

if [[ -z "${JOBS}" ]]; then
	host_cores="$(detect_host_cores)"
	JOBS=$(( host_cores / 2 ))
	if (( JOBS < 1 )); then
		JOBS=1
	fi
fi

if [[ -z "${TAG}" ]]; then
	if ! TAG="$(git -C "${REPO_ROOT}" describe --tags)"; then
		echo "Error: failed to resolve tag via 'git describe --tags'. Use --tag to override." >&2
		exit 1
	fi
fi

if [[ "${BASE_REPO}" != */ ]]; then
	BASE_REPO="${BASE_REPO}/"
fi

if [[ "${VARIANT}" != "dev" && "${VARIANT}" != "prod" ]]; then
	echo "Error: --variant must be 'dev' or 'prod'" >&2
	exit 1
fi

SELECTED_APPS=()
if [[ -z "${APPS_CSV}" ]]; then
	SELECTED_APPS=("${ALL_APPS[@]}")
else
	IFS=',' read -r -a requested_apps <<< "${APPS_CSV}"
	for app in "${requested_apps[@]}"; do
		if [[ -z "${app}" ]]; then
			continue
		fi
		valid=false
		for known in "${ALL_APPS[@]}"; do
			if [[ "${app}" == "${known}" ]]; then
				valid=true
				break
			fi
		done
		if [[ "${valid}" != true ]]; then
			echo "Error: unknown app '${app}' in --apps list" >&2
			exit 1
		fi
		SELECTED_APPS+=("${app}")
	done
fi

if [[ ${#SELECTED_APPS[@]} -eq 0 ]]; then
	echo "Error: no apps selected" >&2
	exit 1
fi

if ! [[ "${JOBS}" =~ ^[1-9][0-9]*$ ]]; then
	echo "Error: --jobs must be a positive integer" >&2
	exit 1
fi

if [[ ( -n "${CACHE_DIR}" || -n "${CACHE_REF}" ) && "${USE_BUILDX}" != true ]]; then
	echo "Error: --cache-dir/--cache-ref require --buildx" >&2
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "Error: docker CLI not found" >&2
	exit 1
fi

if [[ "${USE_BUILDX}" == true ]]; then
	if ! docker buildx version >/dev/null 2>&1; then
		echo "Error: docker buildx is required when --buildx is set" >&2
		exit 1
	fi
fi

if [[ -n "${CACHE_DIR}" ]]; then
	mkdir -p "${CACHE_DIR}"
fi

cleanup_background_jobs() {
	local exit_code=$?
	if (( exit_code != 0 )); then
		local pids
		pids="$(jobs -pr || true)"
		if [[ -n "${pids}" ]]; then
			kill ${pids} >/dev/null 2>&1 || true
		fi
	fi
}

trap cleanup_background_jobs EXIT

echo "Repo root: ${REPO_ROOT}"
echo "Base repo: ${BASE_REPO}"
echo "Tag: ${TAG}"
echo "Variant: ${VARIANT}"
if [[ -n "${BUILDER_TAG}" ]]; then
	echo "Builder tag: ${BUILDER_TAG}"
fi
echo "Jobs: ${JOBS}"
echo "Buildx: ${USE_BUILDX}"
echo "Apps: ${SELECTED_APPS[*]}"

if [[ -n "${CACHE_DIR}" ]]; then
	echo "Cache dir: ${CACHE_DIR}"
fi

if [[ -n "${CACHE_REF}" ]]; then
	echo "Cache ref: ${CACHE_REF}"
fi

build_one() {
	local app="$1"
	local dockerfile
	local image
	local -a cmd

	dockerfile="${REPO_ROOT}/apps/${app}/Dockerfile"
	if [[ ! -f "${dockerfile}" ]]; then
		echo "Error: missing Dockerfile for app '${app}' at ${dockerfile}" >&2
		exit 1
	fi

	image="${BASE_REPO}${app}-code:${TAG}"
	echo "\n==> Building ${image}"

	if [[ "${USE_BUILDX}" == true ]]; then
		cmd=(docker buildx build -f "${dockerfile}" -t "${image}")
		cmd+=(--build-arg "CODE_VARIANT=${VARIANT}")

		if [[ -n "${BUILDER_TAG}" ]]; then
			cmd+=(--build-arg "BUN_BUILDER_TAG=${BUILDER_TAG}")
		fi

		if [[ -n "${CACHE_DIR}" ]]; then
			cmd+=(--cache-from "type=local,src=${CACHE_DIR}")
			cmd+=(--cache-to "type=local,dest=${CACHE_DIR},mode=max")
		fi

		if [[ -n "${CACHE_REF}" ]]; then
			cmd+=(--cache-from "type=registry,ref=${CACHE_REF}")
			cmd+=(--cache-to "type=registry,ref=${CACHE_REF},mode=max")
		fi

		if [[ "${PUSH}" == true ]]; then
			cmd+=(--push)
		else
			cmd+=(--load)
		fi

		cmd+=("${REPO_ROOT}")
		"${cmd[@]}"
	else
		cmd=(docker build -f "${dockerfile}" -t "${image}")
		cmd+=(--build-arg "CODE_VARIANT=${VARIANT}")
		if [[ -n "${BUILDER_TAG}" ]]; then
			cmd+=(--build-arg "BUN_BUILDER_TAG=${BUILDER_TAG}")
		fi
		cmd+=("${REPO_ROOT}")
		"${cmd[@]}"

		if [[ "${PUSH}" == true ]]; then
			echo "==> Pushing ${image}"
			docker push "${image}"
		fi
	fi
}

if [[ "${JOBS}" -eq 1 ]]; then
	for app in "${SELECTED_APPS[@]}"; do
		build_one "${app}"
	done
else
	running_jobs=0
	for app in "${SELECTED_APPS[@]}"; do
		build_one "${app}" &
		((running_jobs += 1))

		if (( running_jobs >= JOBS )); then
			wait -n
			((running_jobs -= 1))
		fi
	done

	while (( running_jobs > 0 )); do
		wait -n
		((running_jobs -= 1))
	done
fi

echo "\nDone. Built ${#SELECTED_APPS[@]} images."
