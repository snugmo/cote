# AGENTS.md — DevWorkspaces Operator Configuration

## Project Overview

This repository contains configuration for the [DevWorkspaces Operator](https://devfile.io/) (successor to Eclipse Che Workspaces). It defines cloud-native development environments as Kubernetes resources. Workspaces are composed from a shared base image plus pluggable IDE and project-specific components.

## Structure

```
base-image/            # Base dev toolchain OCI image
  Containerfile        # Universal compilers, LSPs, package managers (no IDEs)
  build.sh             # Buildah wrapper with registry/tag config
devfiles/
  devfile.yaml         # Generic workspace template (Devfile schema 2.2.0)
```

## Essential Commands

| Task | Command |
|------|---------|
| Build base image | `./base-image/build.sh` |
| Build + push | `./base-image/build.sh push <registry>` |
| Override version | `DEV_VERSION=v1.2.3 ./base-image/build.sh` |
| Override image name | `DEV_IMAGE_NAME=my-base ./base-image/build.sh` |
| Apply workspace | `kubectl apply -f devfiles/devfile.yaml` |

## Key Conventions

### Base Image (`base-image/Containerfile`)

- **No IDEs** — IDEs are Devfile components, never baked into the base image.
- Based on `ubi9/ubi-minimal` for minimal attack surface and Red Hat compatibility.
- Runs as non-root user `developer` (UID 1000) to match DevWorkspaces security defaults.
- Toolchain includes: GCC, Go, Rust, Node.js 22, Python 3.11, plus LSP servers (gopls, rust-analyzer, typescript-language-server, pyright, ruff-lsp).
- Use `microdnf` for package installs; always `microdnf clean all` after installs to keep layers small.
- LSP servers are installed globally so they are available to any IDE component without reinstallation.

### Devfile (`devfiles/devfile.yaml`)

- Uses Devfile schema `2.2.0`.
- The `tools` container mounts source code and provides the shared toolchain.
- IDE components are commented out by default — uncomment and configure per-team.
- Persistent volumes (`tools-cache`, `tools-local`) survive pod restarts for pip/npm/cargo caches.
- The `image` field in the `tools` component must point to a reachable registry. Update it after building.

### Build Script (`base-image/build.sh`)

- Uses `buildah` (not `docker`) — buildah is rootless and works in CI without a Docker daemon.
- Tag defaults to the latest git tag or `git describe --always --dirty`.
- Registry defaults to `localhost:5000` (OpenShift internal registry). Override with `DEV_REGISTRY`.

## Gotchas

1. **Image pull access**: The Devfile `image` reference must be pullable by the service account running the workspace pods. If using a private registry, configure a `secret` component with image pull credentials.
2. **UID 1000**: The base image user is `developer` (UID 1000). DevWorkspaces runs workspace containers as this UID by default. Volume mounts must be writable by UID 1000.
3. **Layer caching**: In the Containerfile, order instructions from least-to-most frequently changing. Package installs should come before tool installations to maximize layer reuse.
4. **Devfile schema version**: The schema version (`2.2.0`) must match what your DevWorkspaces Operator supports. Check with `kubectl get devworkspace -o yaml` to see the operator's schema.
5. **Memory limits**: LSP servers (especially rust-analyzer and TypeScript) are memory-intensive. The default `2Gi` limit on the tools container is a minimum — increase for Rust-heavy projects.

## Adding New Components

- **New language/tool**: Add to the base image Containerfile, rebuild, update the Devfile image reference.
- **New IDE**: Add a commented-out component block in the Devfile (see VS Code example).
- **Project-specific devfile**: Copy `devfiles/devfile.yaml`, update `projects`, `commands`, and add project-specific env vars or endpoints.
