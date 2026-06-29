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

echo "=== Dev Workspace Base Image ==="
echo "Registry:  ${REGISTRY}"
echo "Image:     ${IMAGE_NAME}"
echo "Tag:       ${TAG}"
echo "Full ref:  ${FULL_IMAGE}"
echo ""

# Build
echo ">> Building ${FULL_IMAGE} ..."
buildah build \
    --layers \
    --format docker \
    -t "${FULL_IMAGE}" \
    -f "${SCRIPT_DIR}/Containerfile" \
    "${SCRIPT_DIR}"

echo ">> Build complete: ${FULL_IMAGE}"

# Push (optional)
if $PUSH; then
    echo ""
    echo ">> Pushing ${FULL_IMAGE} ..."
    buildah push "${FULL_IMAGE}"
    echo ">> Push complete."
fi

echo ""
echo ">> Done. To use in a Devfile, reference:"
echo "    image: ${FULL_IMAGE}"
