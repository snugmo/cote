# AGENTS.md — DevWorkspaces Operator Configuration

## Project Overview

**cote** — OCI-based coding workspaces for [DevWorkspaces Operator](https://devfile.io/), from the [Snugmo](https://github.com/snugmo) GitHub org, designed for both human developers and AI coding agents. Workspaces are composed from a shared base OCI image plus pluggable IDE and project-specific components.

## Structure

```
base-image/
  Containerfile        # Base dev toolchain OCI image (Fedora 45, no IDEs)
  build.sh             # Buildah wrapper with registry/tag config
extensions/
  hermes/              # Hermes agent + ACP support extension
  pi/                  # Pi coding agent extension
  pi-in-go/            # PiG (Pi in Go) coding agent extension
  xpra/                # Xpra remote X11 desktop extension
  (each: Containerfile, build.sh, README.md — see docs/extensions.md)
devfiles/
  devfile.yaml         # Generic workspace template (Devfile schema 2.2.0)
.devfile.yaml          # Self-hosting devfile — opens this repo as a workspace
docs/                  # On-demand reference docs — read when relevant (see below)
```

## Essential Commands

| Task                  | Command                                      |
| --------------------- | -------------------------------------------- |
| Build base image      | `./base-image/build.sh`                      |
| Build + push          | `./base-image/build.sh push`                 |
| Build + push (custom) | `./base-image/build.sh push <registry>`      |
| Build an extension    | `./extensions/<name>/build.sh`               |
| Publish to quay.io    | push a `vX.Y.Z` tag, or run the `Publish` workflow |
| Apply workspace       | `kubectl apply -f devfiles/devfile.yaml`     |

Build overrides: `DEV_VERSION=`, `DEV_IMAGE_NAME=`, `DEV_REGISTRY=`, `DEV_JOBS=` (see `base-image/build.sh`). Per-extension build/publish/credential details are in [docs/extensions.md](docs/extensions.md).

## Key Conventions

### Commit Conventions

- Make small, logically contained commits; one per meaningful change, committed as you go.
- Subject: `<emoji> <type>: <summary>` — a conventional type prefix (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, …), optionally with a scope naming the affected component when the change is component-specific (`(base-image)`, `(hermes)`, `(pi)`, `(pi-in-go)`, `(quadlet)`, …), and a summary under 72 characters. `feat` adds a new capability (a new language, tool, or package); `chore` covers maintenance such as version bumps and internal adjustments. The single emoji is chosen per change to capture what actually changed; there is no fixed set of allowed emojis.
- End commit messages with an `Assisted-by: <agent>:<model>` trailer, where `<agent>` is the coding agent doing the committing (no "generated with" line).
### Base Image (`base-image/Containerfile`)

- **No IDEs** — IDEs and AI agents are Devfile components or extension images, never baked into the base image.
- Based on **Fedora 45** (`registry.fedoraproject.org/fedora:45`), not UBI; runs as non-root user `user` (UID 1000).
- Ships a broad toolchain (compilers, Go, Node.js, Python, Rust, Java, LSP servers, linters, k8s/cloud & shell utils) — see [README.md](README.md) `## Toolchain` for the full list with versions.
- All binary downloads are verified as far as possible (SHA-256 `ADD --checksum=…`, cosign signatures, or SLSA provenance).
- Build internals — Containerfile stage architecture, `build.sh`, bun digest, `catatonit` entrypoint, subuid ranges, and verifying artifact stages: see [docs/base-image.md](docs/base-image.md).

### Devfile (`devfiles/devfile.yaml`)

- Uses Devfile schema `2.2.0`.
- The `tools` container mounts source code and provides the shared toolchain; IDE components are commented out by default (uncomment per-team).
- Env vars (`GOPATH`, `CARGO_HOME`, `RUSTUP_HOME`, `JAVA_HOME`, `PATH`) are baked into the image — no `env` block needed.
- The `image` field in the `tools` component defaults to `ghcr.io/snugmo/cote:latest-base`.

### Self-hosting Devfile (`.devfile.yaml`)

- Opens this repository itself as a DevWorkspaces workspace.
- References the pre-built base image at `ghcr.io/snugmo/cote:0.38.0-base` (bump the tag when a new base image is released).

### Build Script (`base-image/build.sh`)

- Uses `buildah` (not `docker`) — rootless, no Docker daemon needed; the script is for local builds (the CI publish pipeline uses BuildKit/docker buildx instead).
- The tag is the git-describe version (`git describe --tags --always --dirty`, leading `v` stripped, falls back to `latest`) plus a `-base` suffix, so the image ref is `ghcr.io/snugmo/cote:<tag>-base` — e.g. `0.38.0-base`.
- Registry defaults to `ghcr.io/snugmo`; `./base-image/build.sh push` publishes to GitHub Container Registry. For local dev use `DEV_REGISTRY=localhost:5000`.

### CI Publishing (`.github/workflows/publish.yaml`)

- Publishes the base image and all four extensions to `quay.io/snugmo` as multi-arch manifests (linux/amd64 + linux/arm64): each arch builds natively on a matching GitHub-hosted runner, pushes a per-arch tag (`<v>-base-<arch>` / `<v>-<arch>`), and a final job merges them with `docker buildx imagetools create`.
- Triggers: a `vX.Y.Z` tag push (publishes `<v>` / `<v>-base` and moves `latest` / `latest-base`) and manual workflow_dispatch runs (git-describe version, does not touch `latest`).
- Requires the secrets `REGISTRY_SERVER`, `REGISTRY_NAMESPACE`, `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` (a quay.io robot account with write access to all five image repos).
- All five Containerfiles lead with `# syntax=docker/dockerfile:1`, which tells BuildKit to pull the latest stable Dockerfile frontend (newer than its bundled default) so the parser is new enough for `COPY --link`. buildah (local `build.sh`) ignores the directive and uses its own parser, so the same file must stay buildable by both — keep it free of tool-specific syntax; `COPY --link` is the one shared extension both parsers accept.

### Extensions (`extensions/`)

Extensions add capabilities on top of the base image without polluting it. To use one, point the Devfile `tools` image at the extension image.

- **Hermes** (`extensions/hermes/`) — Hermes agent with ACP support (VS Code, Zed, JetBrains).
- **Pi** (`extensions/pi/`) — terminal coding agent (npm `@earendil-works/pi-coding-agent`), keyless `example` default.
- **PiG / Pi in Go** (`extensions/pi-in-go/`) — Go port of Pi (npm `@pi-in-go/pig`), single native binary, keyless `example` default.
- **Xpra** (`extensions/xpra/`) — headless X11 desktop + xpra-html5 browser client.

Full detail, build/publish, and credential notes: see [docs/extensions.md](docs/extensions.md).

## Gotchas

1. **Image pull access**: The Devfile `image` reference must be pullable by the service account running the workspace pods. If using a private registry, configure a `secret` component with image pull credentials.
2. **UID 1000**: The base image user is `user` (UID 1000). DevWorkspaces runs workspace containers as this UID by default. Volume mounts must be writable by UID 1000.
3. **Layer caching**: In the Containerfile, order instructions from least-to-most frequently changing. Package installs should come before tool installations to maximize layer reuse.
4. **Devfile schema version**: The schema version (`2.2.0`) must match what your DevWorkspaces Operator supports. Check with `kubectl get devworkspace -o yaml` to see the operator's schema.
5. **Memory limits**: LSP servers (especially rust-analyzer and TypeScript) are memory-intensive. The default `2Gi` limit on the tools container is a minimum — increase for Rust-heavy projects.
6. **Two devfiles, two purposes**: `devfiles/devfile.yaml` is the reusable template for end users. `.devfile.yaml` is for developing this repo itself. Don't confuse them.
7. **Extension credentials**: the agent extensions (Hermes, Pi, PiG) each need credentials configured or a keyless default — see [docs/extensions.md](docs/extensions.md) → *Credentials / gotchas*.

## Adding New Components

- **New language/tool**: add it to the base image following [docs/adding-a-binary-tool.md](docs/adding-a-binary-tool.md), then rebuild and update the Devfile image reference.
- **New extension**: create a directory under `extensions/` with a `Containerfile` that extends the base image, a `build.sh` like `base-image/build.sh`, and a `README.md` — see [docs/extensions.md](docs/extensions.md).
- **New IDE**: add a commented-out component block in the Devfile.
- **Project-specific devfile**: copy `devfiles/devfile.yaml`, update `projects`/`commands`, and add project-specific env vars or endpoints.

## On-Demand Reference Docs

This file holds only the context useful for *any* work in this repo. The detailed, task-specific playbooks live in `docs/` — read the matching one when you're doing that kind of work:

- **[docs/base-image.md](docs/base-image.md)** — building/editing the base image: Containerfile stage architecture, `build.sh`, base/devfile specifics, verifying artifact stages.
- **[docs/adding-a-binary-tool.md](docs/adding-a-binary-tool.md)** — adding a new binary or language tool to the base image.
- **[docs/updating-tool-versions.md](docs/updating-tool-versions.md)** — bumping a pinned tool to a newer release: lookup commands, hash recompute, the release flow.
- **[docs/extensions.md](docs/extensions.md)** — working on an extension image (Hermes, Pi, PiG, Xpra) or its credentials.
