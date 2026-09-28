#!/usr/bin/env bash
# Build and optionally push the PiG (Pi in Go) extension image.
# Usage:
#   ./build.sh                          # Build only
#   ./build.sh push                     # Build and push
#   ./build.sh push <registry>          # Build and push to custom registry
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

usage() {
    printf 'Usage:\n'
    printf '  ./build.sh                          # Build only\n'
    printf '  ./build.sh push                     # Build and push\n'
    printf '  ./build.sh push <registry>          # Build and push to registry\n'
}

# Configurable via environment or defaults
REGISTRY="${DEV_REGISTRY:-localhost:5000}"
IMAGE_NAME="${DEV_IMAGE_NAME:-dev-workspace-pi-in-go}"
VERSION="${DEV_VERSION:-$(git -C "$PROJECT_ROOT" describe --tags --always --dirty 2>/dev/null || echo 'latest')}"
TAG="${VERSION#v}"

PUSH=false
if [[ $# -gt 2 ]]; then
    printf '\nError: Too many arguments. '
    usage
    printf '\nAborting.\n'
    exit 2
fi

if [[ "${1:-}" == "push" ]]; then
    PUSH=true
    if [[ -n "${2:-}" ]]; then
        REGISTRY="$2"
    fi
elif [[ -n "${1:-}" ]]; then
    printf '\n⚠ WARNING: First argument "%s" is not "push".\n' "$1"
    printf '   Image will be built locally but NOT pushed.\n'
    printf '   Did you mean:  ./build.sh push %s\n\n' "$1"
    usage
    printf '\nAborting.\n'
    exit 2
fi

# BASE_IMAGE is computed here, after arg parsing, so a registry passed as the
# second argument applies to the base image reference as well.
BASE_IMAGE="${DEV_BASE_IMAGE:-${REGISTRY}/dev-workspace-base:${TAG}}"

FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

printf '=== PiG (Pi in Go) Extension Image ===\n'
printf 'Registry:  %s\n' "${REGISTRY}"
printf 'Image:     %s\n' "${IMAGE_NAME}"
printf 'Tag:       %s\n' "${TAG}"
printf 'Full ref:  %s\n' "${FULL_IMAGE}"
printf 'Base:      %s\n' "${BASE_IMAGE}"
printf '\n'

# Build
printf '>> Building %s ...\n' "${FULL_IMAGE}"
buildah build \
    --isolation chroot \
    --layers \
    --format docker \
    --storage-opt ignore_chown_errors=true \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
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
