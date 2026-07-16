# AGENTS.md — DevWorkspaces Operator Configuration

## Project Overview

This repository defines cloud-native development environments for the [DevWorkspaces Operator](https://devfile.io/) (successor to Eclipse Che Workspaces). Workspaces are composed from a shared base OCI image plus pluggable IDE and project-specific components.

## Structure

```
base-image/
  Containerfile        # Base dev toolchain OCI image (Fedora 44, no IDEs)
  build.sh             # Buildah wrapper with registry/tag config
extensions/
  hermes/              # Hermes agent + ACP support extension
    Containerfile      # Extends base image with Hermes agent
    build.sh           # Build script for Hermes extension
    README.md          # Extension documentation
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
| Build Hermes extension | `./extensions/hermes/build.sh` |
| Build + push Hermes | `./extensions/hermes/build.sh push <registry>` |
| Apply workspace | `kubectl apply -f devfiles/devfile.yaml` |

## Key Conventions

### Base Image (`base-image/Containerfile`)

- **No IDEs** — IDEs are Devfile components, never baked into the base image.
- Based on **Fedora 44** (`registry.fedoraproject.org/fedora:44`) — not UBI.
- Runs as non-root user `user` (UID 1000) to match DevWorkspaces security defaults.
- Uses `dnf` (not `microdnf`) for package installs; always `dnf clean all` after installs to keep layers small.
- **Toolchain includes**: GCC, Clang/LLVM, Go 1.26.5, Rust (via rustup + rust-analyzer), Node.js 24, Python 3, Crush CLI, plus LSP servers (`gopls`, `typescript-language-server`, `pyright`, `ruff-lsp`, `yaml-language-server`).
- LSP servers are installed globally so they are available to any IDE component without reinstallation.
- Go version is controlled by `ARG GO_VERSION=1.26.5` — override at build time if needed.
- Bun binary is copied from `oven/bun` distroless OCI image (pinned by sha256 digest).
- ENTRYPOINT uses `catatonit` (from podman) for zombie process reaping; CMD defaults to `tail -f /dev/null` so the container stays alive for `exec`.
- Subuid/subgid ranges (2000–65000) are configured on the `user` account to enable **rootless buildah/podman inside the container**.

### Devfile (`devfiles/devfile.yaml`)

- Uses Devfile schema `2.2.0`.
- The `tools` container mounts source code and provides the shared toolchain.
- IDE components are commented out by default — uncomment and configure per-team.
- Env vars (`GOPATH`, `CARGO_HOME`, `RUSTUP_HOME`, `PATH`) are baked into the image — no `env` block needed in devfiles.
- Persistent volumes (`tools-cache`, `tools-local`) survive pod restarts for pip/npm/cargo caches.
- The `image` field in the `tools` component defaults to `r5t.io/agentic/dev-workspace-base:latest`.
- Commands section includes `run-tests` (placeholder) and `rebuild-base-image` (runs buildah inside the workspace).

### Self-hosting Devfile (`.devfile.yaml`)

- Opens this repository itself as a DevWorkspaces workspace.
- References a pre-built image at `codeberg.org/r5t/agent-workspace:0.1.0`.
- Use this to iterate on the repo configuration inside a live workspace.

### Build Script (`base-image/build.sh`)

- Uses `buildah` (not `docker`) — rootless, works in CI without a Docker daemon.
- Tag defaults to latest git tag via `git describe --tags --always --dirty`, falling back to `latest`.
- Registry defaults to `localhost:5000` (OpenShift internal registry). Override with `DEV_REGISTRY` or pass as second argument to `push`.

### Extensions (`extensions/`)

Extensions build on top of the base image to add specific capabilities without polluting the base. Each extension has its own `Containerfile`, `build.sh`, and `README.md`.

**Available extensions:**

- **Hermes Agent** (`extensions/hermes/`) — Installs [Hermes Agent](https://hermes-agent.nousresearch.com/) with ACP (Agent Communication Protocol) support for IDE integration. Uses a shallow git clone of the upstream repo (pip installs are unsupported). Works with VS Code (ACP Client extension), Zed (ACP Registry), and JetBrains (ACP plugins).

To use an extension, replace the `tools` container image in your Devfile with the extension image reference.

## Gotchas

1. **Image pull access**: The Devfile `image` reference must be pullable by the service account running the workspace pods. If using a private registry, configure a `secret` component with image pull credentials.
2. **UID 1000**: The base image user is `user` (UID 1000). DevWorkspaces runs workspace containers as this UID by default. Volume mounts must be writable by UID 1000.
3. **Layer caching**: In the Containerfile, order instructions from least-to-most frequently changing. Package installs should come before tool installations to maximize layer reuse.
4. **Devfile schema version**: The schema version (`2.2.0`) must match what your DevWorkspaces Operator supports. Check with `kubectl get devworkspace -o yaml` to see the operator's schema.
5. **Memory limits**: LSP servers (especially rust-analyzer and TypeScript) are memory-intensive. The default `2Gi` limit on the tools container is a minimum — increase for Rust-heavy projects.
6. **Two devfiles, two purposes**: `devfiles/devfile.yaml` is the reusable template for end users. `.devfile.yaml` is for developing this repo itself. Don't confuse them.
7. **Hermes credentials**: Hermes agent requires API credentials configured before first use. Run `hermes model` inside the workspace or pre-populate `~/.hermes/.env` via a ConfigMap/Secret.

## Adding New Components

- **New language/tool**: Add to the base image Containerfile, rebuild, update the Devfile image reference.
- **New extension**: Create a directory under `extensions/` with a `Containerfile` that extends the base image, a `build.sh` following the same pattern as `base-image/build.sh`, and a `README.md`.
- **New IDE**: Add a commented-out component block in the Devfile (see VS Code example).
- **Project-specific devfile**: Copy `devfiles/devfile.yaml`, update `projects`, `commands`, and add project-specific env vars or endpoints.

## Development Tips

### Verifying Artifact Stages

The Containerfile uses parallel install stages → scratch artifact stages → final assembly. After changing COPY directives in artifact stages, verify they capture all needed files:

1. **Build each install stage as a tagged image:**
   ```bash
   buildah build --isolation chroot --layers --target base -t diff-base -f Containerfile .
   buildah build --isolation chroot --layers --target nodejs-install -t diff-nodejs -f Containerfile .
   # ... repeat for each install stage
   ```
   `--isolation chroot` is required for nested container builds. `--layers` reuses cached base layers.

2. **Diff each install image against the base:**
   ```bash
   BASE=$(podman inspect diff-base --format '{{.Id}}')
   podman diff diff-nodejs "$BASE" > nodejs_added.txt
   ```
   Filter to `^A ` (Added) lines to see only new files. Extract unique directory prefixes with:
   ```bash
   grep '^A ' nodejs_added.txt | sed 's/^A //' | awk -F/ '{if(NF>=3) print "/"$2"/"$3; else print $0}' | sort -u
   ```

3. **Cross-reference** the output against COPY directives in the artifact stages to find missing files.
