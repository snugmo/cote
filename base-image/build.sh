#!/usr/bin/env bash
# Build and optionally push the base dev workspace image.
# Usage:
#   ./build.sh                          # Build only
#   ./build.sh push                     # Build and push
#   ./build.sh push myregistry.io/dev   # Build and push to custom registry
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configurable via environment or defaults
REGISTRY="${DEV_REGISTRY:-localhost:5000}"
IMAGE_NAME="${DEV_IMAGE_NAME:-dev-workspace-base}"
VERSION="${DEV_VERSION:-$(git -C "$PROJECT_ROOT" describe --tags --always --dirty 2>/dev/null || echo 'latest')}"
TAG="${VERSION}"

PUSH=false
if [[ "${1:-}" == "push" ]]; then
    PUSH=true
    if [[ -n "${2:-}" ]]; then
        REGISTRY="$2"
    fi
fi

FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

printf '=== Dev Workspace Base Image ===\n'
printf 'Registry:  %s\n' "${REGISTRY}"
printf 'Image:     %s\n' "${IMAGE_NAME}"
printf 'Tag:       %s\n' "${TAG}"
printf 'Full ref:  %s\n' "${FULL_IMAGE}"
printf '\n'

# Build
printf '>> Building %s ...\n' "${FULL_IMAGE}"
buildah build \
    --layers \
    --format docker \
    -t "${FULL_IMAGE}" \
    -f "${SCRIPT_DIR}/Containerfile" \
    "${SCRIPT_DIR}"

printf '>> Build complete: %s\n' "${FULL_IMAGE}"

# Push (optional)
if $PUSH; then
    printf '\n'
    printf '>> Pushing %s ...\n' "${FULL_IMAGE}"
    buildah push "${FULL_IMAGE}"
    printf '>> Push complete.\n'
fi

printf '\n'
printf '>> Done. To use in a Devfile, reference:\n'
printf '    image: %s\n' "${FULL_IMAGE}"
