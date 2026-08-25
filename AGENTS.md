# AGENTS.md — DevWorkspaces Operator Configuration

## Project Overview

OCI-based coding workspaces for [DevWorkspaces Operator](https://devfile.io/) — designed for both human developers and AI coding agents. Workspaces are composed from a shared base OCI image plus pluggable IDE and project-specific components.

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
  pi/                  # Pi coding agent extension
    Containerfile      # Extends base image with Pi coding agent
    models.json        # Baked-in r5t LLM provider (keyless OpenAI-compatible)
    settings.json      # Baked-in r5t defaults (model, thinking level)
    build.sh           # Build script for Pi extension
    README.md          # Extension documentation
devfiles/
  devfile.yaml         # Generic workspace template (Devfile schema 2.2.0)
.devfile.yaml          # Self-hosting devfile — opens this repo as a workspace
```

## Essential Commands

| Task                   | Command                                                   |
| ---------------------- | --------------------------------------------------------- |
| Build base image       | `./base-image/build.sh`                                   |
| Build + push           | `./base-image/build.sh push <registry>`                   |
| Override version       | `DEV_VERSION=v1.2.3 ./base-image/build.sh`                |
| Override image name    | `DEV_IMAGE_NAME=my-base ./base-image/build.sh`            |
| Override registry      | `DEV_REGISTRY=registry.example.com ./base-image/build.sh` |
| Parallel build         | `DEV_JOBS=$(nproc) ./base-image/build.sh`                 |
| Build Hermes extension | `./extensions/hermes/build.sh`                            |
| Build + push Hermes    | `./extensions/hermes/build.sh push <registry>`            |
| Build Pi extension     | `./extensions/pi/build.sh`                                |
| Build + push Pi        | `./extensions/pi/build.sh push <registry>`                |
| Apply workspace        | `kubectl apply -f devfiles/devfile.yaml`                  |

## Key Conventions

### Base Image (`base-image/Containerfile`)

- **No IDEs** — IDEs and AI agents are Devfile components or extension images, never baked into the base image.
- Based on **Fedora 44** (`registry.fedoraproject.org/fedora:44`) — not UBI.
- Runs as non-root user `user` (UID 1000) to match DevWorkspaces security defaults.
- Uses `dnf` (not `microdnf`) for package installs; always `dnf clean all` after installs to keep layers small.
- **Toolchain includes**: GCC, Clang/LLVM, Go 1.27.0, Rust (via rustup + rust-analyzer), Node.js 26, Python 3, Crush CLI, plus LSP servers (`gopls`, `golangci-lint-langserver`, `typescript-language-server`, `pyright`, `ruff-lsp`, `yaml-language-server`, `marksman`, `helm-ls`, `tofu-ls`, `bash-language-server`, `dockerfile-language-server`, `clangd`, `rust-analyzer`).
- LSP servers are installed globally so they are available to any IDE component without reinstallation.
- Go version is controlled by `ARG GO_VERSION=1.27.0` — override at build time if needed.
- Bun binary is copied from `oven/bun` distroless OCI image (pinned by sha256 digest).
- ENTRYPOINT uses `catatonit` (from podman) for zombie process reaping; CMD defaults to `tail -f /dev/null` so the container stays alive for `exec`.
- Subuid/subgid ranges (2000–65000) are configured on the `user` account to enable **rootless buildah/podman inside the container**.
- All binary downloads are verified as far as possible (SHA-256 checksums, cosign signatures, or SLSA provenance) — not all upstreams provide cryptographic signatures.

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
- References the pre-built base image at `r5t.io/agentic/dev-workspace-base:0.11.6` (bump the tag when a new base image is released).
- Use this to iterate on the repo configuration inside a live workspace.

### Build Script (`base-image/build.sh`)

- Uses `buildah` (not `docker`) — rootless, works in CI without a Docker daemon.
- Tag defaults to latest git tag via `git describe --tags --always --dirty`, falling back to `latest`.
- Registry defaults to `localhost:5000` (OpenShift internal registry). Override with `DEV_REGISTRY` or pass as second argument to `push`.

### Extensions (`extensions/`)

Extensions build on top of the base image to add specific capabilities without polluting the base. Each extension has its own `Containerfile`, `build.sh`, and `README.md`. Extensions keep the base lean while enabling agent-ready workspaces when needed.

**Available extensions:**

- **Hermes Agent** (`extensions/hermes/`) — Installs [Hermes Agent](https://hermes-agent.nousresearch.com/) with ACP (Agent Communication Protocol) support for IDE integration. Uses a shallow git clone of the upstream repo (pip installs are unsupported). Works with VS Code (ACP Client extension), Zed (ACP Registry), and JetBrains (ACP plugins).
- **Pi Coding Agent** (`extensions/pi/`) — Installs the [Pi coding agent](https://pi.dev) ([earendil-works/pi](https://github.com/earendil-works/pi)) from the official npm package (`@earendil-works/pi-coding-agent`) with `--ignore-scripts`. Terminal coding agent with interactive TUI, print, RPC, and SDK modes. Bakes in the keyless `r5t` provider (`https://llm.r5t.io/v1`, model `qwen3.8-27b`) as the default LLM in `~/.pi/agent/models.json` + `settings.json`.

To use an extension, replace the `tools` container image in your Devfile with the extension image reference.

## Gotchas

1. **Image pull access**: The Devfile `image` reference must be pullable by the service account running the workspace pods. If using a private registry, configure a `secret` component with image pull credentials.
2. **UID 1000**: The base image user is `user` (UID 1000). DevWorkspaces runs workspace containers as this UID by default. Volume mounts must be writable by UID 1000.
3. **Layer caching**: In the Containerfile, order instructions from least-to-most frequently changing. Package installs should come before tool installations to maximize layer reuse.
4. **Devfile schema version**: The schema version (`2.2.0`) must match what your DevWorkspaces Operator supports. Check with `kubectl get devworkspace -o yaml` to see the operator's schema.
5. **Memory limits**: LSP servers (especially rust-analyzer and TypeScript) are memory-intensive. The default `2Gi` limit on the tools container is a minimum — increase for Rust-heavy projects.
6. **Two devfiles, two purposes**: `devfiles/devfile.yaml` is the reusable template for end users. `.devfile.yaml` is for developing this repo itself. Don't confuse them.
7. **Hermes credentials**: Hermes agent requires API credentials configured before first use. Run `hermes model` inside the workspace or pre-populate `~/.hermes/.env` via a ConfigMap/Secret.
8. **Pi credentials**: The baked-in `r5t` provider (`qwen3.8-27b`) needs no API key, so `pi` works out of the box. For any other provider, pre-populate an env var (e.g. `ANTHROPIC_API_KEY`) via a ConfigMap/Secret, or run `pi` and use `/login`. Set `PI_OFFLINE=1` to silence startup network calls (update check, telemetry) in air-gapped workspaces.

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

## Updating Base Image Tool Versions

The base image pins ~20 binary tools, either as `ARG *_VERSION` values or as image tags/digests (cosign, curlimages/curl, oven/bun). To update everything to the latest upstream releases:

1. Create a todo list with one item per pinned tool, then check releases **one at a time**. Never fetch release info for all tools in parallel: a single raw GitHub API release JSON response is enough to overflow the session context.
2. For each tool, look up the latest release with the minimal-output command from the table below and compare it to the pin in the Containerfile.
3. If a newer version exists, edit the `ARG` line (plus `EXPECTED=` hashes where applicable), then immediately commit that single tool with the message `chore(base-image): update <tool> from <old> to <new>`. One commit per tool, never batch.

### Environment Constraints (agent sessions)

- `curl` and `wget` are not available in the bash tool; use the `download` tool to save non-GitHub JSON endpoints (Docker Hub, go.dev, Codeberg, nodejs.org) to /tmp, then parse with `jq`.
- The `gh` CLI is installed and authenticated; always use `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name` for GitHub repos and never fetch raw release JSON.

### Per-Tool Lookup Commands

| Pin (Containerfile)         | Latest release lookup                                                                                              |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| cosign image tag            | `gh api repos/sigstore/cosign/releases/latest --jq .tag_name`                                                       |
| curlimages/curl digest      | download `https://hub.docker.com/v2/repositories/curlimages/curl/tags/latest`, then `jq -r .digest`                 |
| `CRUSH_VERSION`             | `gh api repos/charmbracelet/crush/releases/latest --jq .tag_name`                                                   |
| `FNM_VERSION`               | `gh api repos/Schniz/fnm/releases/latest --jq .tag_name`                                                            |
| `NODE_VERSION` (major only) | download `https://nodejs.org/dist/index.json` (sorted newest first), then `jq -r '.[0].version'`; bump only when the major changes |
| oven/bun digest             | download `https://hub.docker.com/v2/repositories/oven/bun/tags/latest`, then `jq -r .digest`                        |
| `GO_VERSION`                | no GitHub releases; download `https://go.dev/dl/?mode=json`, then `jq -r '.[0].version'` (strip the `go` prefix)    |
| `UV_VERSION`                | `gh api repos/astral-sh/uv/releases/latest --jq .tag_name` (no `v` prefix)                                          |
| `FJ_VERSION`                | download `https://codeberg.org/api/v1/repos/forgejo-contrib/forgejo-cli/releases/latest`, then `jq -r .tag_name`    |
| `GH_VERSION`                | `gh api repos/cli/cli/releases/latest --jq .tag_name`                                                               |
| `KUBESEAL_VERSION`          | `gh api repos/bitnami/sealed-secrets/releases/latest --jq .tag_name` (verified with cosign signature, no hash to update) |
| `KUBECTL_LINSTOR_VERSION`   | `gh api repos/piraeusdatastore/kubectl-linstor/releases/latest --jq .tag_name`                                      |
| `CLOUDNATIVE_PG_VERSION`    | `gh api repos/cloudnative-pg/cloudnative-pg/releases/latest --jq .tag_name`                                         |
| `CERT_MANAGER_VERSION`      | `gh api repos/cert-manager/cmctl/releases/latest --jq .tag_name`                                                    |
| `AGENTGATEWAY_VERSION`      | `gh api repos/agentgateway/agentgateway/releases/latest --jq .tag_name`                                             |
| `MCP_CLI_VERSION`           | `gh api repos/philschmid/mcp-cli/releases/latest --jq .tag_name`                                                    |
| `MARKSMAN_VERSION`          | `gh api repos/artempyanykh/marksman/releases/latest --jq .tag_name` (date-based tag, e.g. `2026-02-08`; used bare in the URL, no `v`) |
| `HELM_LS_VERSION`           | `gh api repos/mrjosh/helm-ls/releases/latest --jq .tag_name`                                                         |
| `TOFU_LS_VERSION`           | `gh api repos/opentofu/tofu-ls/releases/latest --jq .tag_name` (verified against upstream `checksums.txt`, no hash to update) |
| `HERDR_VERSION`             | `gh api repos/ogulcancelik/herdr/releases/latest --jq .tag_name`                                                    |
| `AST_GREP_VERSION`          | `gh api repos/ast-grep/ast-grep/releases/latest --jq .tag_name` (no `v` prefix)                                     |
| `KUBECONFORM_VERSION`       | `gh api repos/yannh/kubeconform/releases/latest --jq .tag_name` (verified against upstream `CHECKSUMS`, no hash to update) |
| `PI_VERSION`                | `gh api repos/earendil-works/pi/releases/latest --jq .tag_name` (extension image `extensions/pi/`; strip the `v` prefix for the npm package) |

### sha256 Recomputation (marksman, helm-ls, ast-grep)

These three tools hardcode per-architecture `EXPECTED="..."` hashes in the Containerfile. After bumping their version:

1. Download each release asset into /tmp with the `download` tool:
   - marksman: `https://github.com/artempyanykh/marksman/releases/download/<tag>/marksman-linux-x64` and `.../marksman-linux-arm64`
   - helm-ls: `https://github.com/mrjosh/helm-ls/releases/download/v<ver>/helm_ls_linux_amd64` and `.../helm_ls_linux_arm64`
   - ast-grep: `https://github.com/ast-grep/ast-grep/releases/download/<ver>/app-x86_64-unknown-linux-gnu.zip` and `.../app-aarch64-unknown-linux-gnu.zip`
2. Run `sha256sum /tmp/<asset>` for each file and replace both `EXPECTED=` values (amd64 and arm64 branches).
3. For ast-grep, hash the `.zip` files: the Containerfile verifies the zip before unzipping.

### Post-Bump Housekeeping

- Keep the version references in this file (see the Base Image section) and the Toolchain table in `README.md` in sync with the Containerfile.
- Rebuild and push the base image, then bump the tag in `.devfile.yaml` (see the Self-hosting Devfile section).
