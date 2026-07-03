# AGENTS.md — DevWorkspaces Operator Configuration

## Project Overview

This repository defines cloud-native development environments for the [DevWorkspaces Operator](https://devfile.io/) (successor to Eclipse Che Workspaces). Workspaces are composed from a shared base OCI image plus pluggable IDE and project-specific components.

## Structure

```
base-image/
  Containerfile        # Base dev toolchain OCI image (Fedora 44, no IDEs)
  build.sh             # Buildah wrapper with registry/tag config
devfiles/
  devfile.yaml         # Generic workspace template (Devfile schema 2.2.0)
.devfile.yaml          # Self-hosting devfile — opens this repo as a workspace
```

## Essential Commands

| Task | Command |
|------|---------|
| Build base image | `./base-image/build.sh` |
| Build + push | `./base-image/build.sh push <registry>` |
| Override version | `DEV_VERSION=v1.2.3 ./base-image/build.sh` |
| Override image name | `DEV_IMAGE_NAME=my-base ./base-image/build.sh` |
| Override registry | `DEV_REGISTRY=registry.example.com ./base-image/build.sh` |
| Apply workspace | `kubectl apply -f devfiles/devfile.yaml` |

## Key Conventions

### Base Image (`base-image/Containerfile`)

- **No IDEs** — IDEs are Devfile components, never baked into the base image.
- Based on **Fedora 44** (`registry.fedoraproject.org/fedora:44`) — not UBI.
- Runs as non-root user `user` (UID 1000) to match DevWorkspaces security defaults.
- Uses `dnf` (not `microdnf`) for package installs; always `dnf clean all` after installs to keep layers small.
- **Toolchain includes**: GCC, Clang/LLVM, Go 1.26.3, Rust (via rustup + rust-analyzer), Node.js 22, Python 3, Crush CLI, plus LSP servers (`gopls`, `typescript-language-server`, `pyright`, `ruff-lsp`, `yaml-language-server`).
- LSP servers are installed globally so they are available to any IDE component without reinstallation.
- Go version is controlled by `ARG GO_VERSION=1.26.3` — override at build time if needed.
- ENTRYPOINT uses `catatonit` (from podman) for zombie process reaping; CMD defaults to `tail -f /dev/null` so the container stays alive for `exec`.
- Subuid/subgid ranges (2000–65000) are configured on the `user` account to enable **rootless buildah/podman inside the container**.

### Devfile (`devfiles/devfile.yaml`)

- Uses Devfile schema `2.2.0`.
- The `tools` container mounts source code and provides the shared toolchain.
- IDE components are commented out by default — uncomment and configure per-team.
- Persistent volumes (`tools-cache`, `tools-local`) survive pod restarts for pip/npm/cargo caches.
- The `image` field in the `tools` component defaults to `localhost:5000/dev-workspace-base:latest` — update it after building.
- Commands section includes `run-tests` (placeholder) and `rebuild-base-image` (runs buildah inside the workspace).

### Self-hosting Devfile (`.devfile.yaml`)

- Opens this repository itself as a DevWorkspaces workspace.
- References a pre-built image at `codeberg.org/r5t/agent-workspace:v0.1.0`.
- Use this to iterate on the repo configuration inside a live workspace.

### Build Script (`base-image/build.sh`)

- Uses `buildah` (not `docker`) — rootless, works in CI without a Docker daemon.
- Tag defaults to latest git tag via `git describe --tags --always --dirty`, falling back to `latest`.
- Registry defaults to `localhost:5000` (OpenShift internal registry). Override with `DEV_REGISTRY` or pass as second argument to `push`.

## Gotchas

1. **Image pull access**: The Devfile `image` reference must be pullable by the service account running the workspace pods. If using a private registry, configure a `secret` component with image pull credentials.
2. **UID 1000**: The base image user is `user` (UID 1000). DevWorkspaces runs workspace containers as this UID by default. Volume mounts must be writable by UID 1000.
3. **Layer caching**: In the Containerfile, order instructions from least-to-most frequently changing. Package installs should come before tool installations to maximize layer reuse.
4. **Devfile schema version**: The schema version (`2.2.0`) must match what your DevWorkspaces Operator supports. Check with `kubectl get devworkspace -o yaml` to see the operator's schema.
5. **Memory limits**: LSP servers (especially rust-analyzer and TypeScript) are memory-intensive. The default `2Gi` limit on the tools container is a minimum — increase for Rust-heavy projects.
6. **Two devfiles, two purposes**: `devfiles/devfile.yaml` is the reusable template for end users. `.devfile.yaml` is for developing this repo itself. Don't confuse them.

## Adding New Components

- **New language/tool**: Add to the base image Containerfile, rebuild, update the Devfile image reference.
- **New IDE**: Add a commented-out component block in the Devfile (see VS Code example).
- **Project-specific devfile**: Copy `devfiles/devfile.yaml`, update `projects`, `commands`, and add project-specific env vars or endpoints.
