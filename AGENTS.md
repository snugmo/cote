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
  pi-in-go/            # PiG (Pi in Go) coding agent extension
    Containerfile      # Extends base image with PiG coding agent
    models.json        # Baked-in r5t LLM provider (keyless OpenAI-compatible)
    settings.json      # Baked-in r5t defaults (model, thinking level)
    build.sh           # Build script for PiG extension
    README.md          # Extension documentation
  xpra/                # Xpra remote X11 desktop extension
    Containerfile      # Extends base image with Xpra, X11, and the xpra-html5 client
    build.sh           # Build script for Xpra extension
    xpra-desktop       # Desktop session launcher script
    README.md          # Extension documentation
devfiles/
  devfile.yaml         # Generic workspace template (Devfile schema 2.2.0)
.devfile.yaml          # Self-hosting devfile — opens this repo as a workspace
scripts/
  git-hooks/commit-msg # Optional commit-msg hook (adds goose agent trailers)
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
| Publish base image     | `./base-image/build.sh push r5t.io/agentic`               |
| Build Hermes extension | `./extensions/hermes/build.sh`                            |
| Build + push Hermes    | `./extensions/hermes/build.sh push <registry>`            |
| Build Pi extension     | `./extensions/pi/build.sh`                                |
| Build + push Pi        | `./extensions/pi/build.sh push <registry>`                |
| Build PiG extension    | `./extensions/pi-in-go/build.sh`                          |
| Build + push PiG       | `./extensions/pi-in-go/build.sh push <registry>`          |
| Build Xpra extension   | `./extensions/xpra/build.sh`                              |
| Build + push Xpra      | `./extensions/xpra/build.sh push <registry>`              |
| Apply workspace        | `kubectl apply -f devfiles/devfile.yaml`                  |

## Key Conventions

### Commit Conventions

- Make small, logically contained commits; one per meaningful change, committed as you go.
- Prefix every commit subject with a single emoji representing the change, followed by the conventional type prefix used in this repo (`feat(base-image):`, `chore(base-image):`, `docs:`, `fix:`, …); keep subjects under 72 characters. Use `feat(base-image):` when a change adds a new capability to the base image (a new language, tool, or package), and `chore(base-image):` for maintenance such as version bumps and internal adjustments. Examples: `✨ feat(base-image): add Temurin 25 JDK to base image`, `📦 chore(base-image): update herdr from 0.8.1 to 0.8.2`, `✏️ docs: …`, `🐛 fix: …`.
- End commit messages with an `Assisted-by: <agent>:<model>` trailer, where `<agent>` is the coding agent doing the committing (no "generated with" line).
- An optional `scripts/git-hooks/commit-msg` hook (install: `ln -sf ../../scripts/git-hooks/commit-msg .git/hooks/commit-msg`) auto-appends `Assisted-by:`, `Model:`, and `Agent-Session:` trailers when `AGENT=goose`; it is a no-op for every other agent and does not validate the emoji/conventional format.

### Base Image (`base-image/Containerfile`)

- **No IDEs** — IDEs and AI agents are Devfile components or extension images, never baked into the base image.
- Based on **Fedora 44** (`registry.fedoraproject.org/fedora:44`) — not UBI.
- Runs as non-root user `user` (UID 1000) to match DevWorkspaces security defaults.
- Uses `dnf` (not `microdnf`) for package installs; always `dnf clean all` after installs to keep layers small.
- **Toolchain includes**: GCC, Clang/LLVM, Go 1.27.1, Rust (via rustup + rust-analyzer + cargo-binstall), Node.js 26, Python 3, Java (Temurin 25 JDK), Maven, Crush CLI, SimpleX Chat CLI, nono, lola, plus LSP servers (`gopls`, `golangci-lint-langserver`, `typescript-language-server`, `pyright`, `pyrefly`, `ruff server`, `yaml-language-server`, `marksman`, `helm-ls`, `tofu-ls`, `protols`, `bash-language-server`, `dockerfile-language-server`, `clangd`, `rust-analyzer`).
- LSP servers are installed globally so they are available to any IDE component without reinstallation.
- Go version is controlled by `ARG GO_VERSION=1.27.1` — override at build time if needed.
- Bun binary is copied from `oven/bun` distroless OCI image (pinned by sha256 digest).
- ENTRYPOINT uses `catatonit` (from podman) for zombie process reaping; CMD defaults to `tail -f /dev/null` so the container stays alive for `exec`.
- Subuid/subgid ranges (2000–65000) are configured on the `user` account to enable **rootless buildah/podman inside the container**.
- All binary downloads are verified as far as possible: where upstreams publish SHA-256s, the download itself is an `ADD --checksum=sha256:…` in the Containerfile; otherwise cosign signatures or SLSA provenance — not all upstreams provide cryptographic signatures. Per-arch release assets download only the selected arch via `FROM scratch` download stages and a `FROM <tool>-download-${TARGETARCH}` selector (see *Adding a New Binary Tool to the Base Image*).

### Devfile (`devfiles/devfile.yaml`)

- Uses Devfile schema `2.2.0`.
- The `tools` container mounts source code and provides the shared toolchain.
- IDE components are commented out by default — uncomment and configure per-team.
- Env vars (`GOPATH`, `CARGO_HOME`, `RUSTUP_HOME`, `JAVA_HOME`, `PATH`) are baked into the image — no `env` block needed in devfiles.
- Persistent volumes (`tools-cache`, `tools-local`) survive pod restarts for pip/npm/cargo caches.
- The `image` field in the `tools` component defaults to `r5t.io/agentic/dev-workspace-base:latest`.
- Commands section includes `run-tests` (placeholder) and `rebuild-base-image` (runs buildah inside the workspace).

### Self-hosting Devfile (`.devfile.yaml`)

- Opens this repository itself as a DevWorkspaces workspace.
- References the pre-built base image at `r5t.io/agentic/dev-workspace-base:0.31.0` (bump the tag when a new base image is released).
- Use this to iterate on the repo configuration inside a live workspace.

### Build Script (`base-image/build.sh`)

- Uses `buildah` (not `docker`) — rootless, works in CI without a Docker daemon.
- Tag defaults to latest git tag via `git describe --tags --always --dirty`, falling back to `latest`.
- Registry defaults to `localhost:5000` (OpenShift internal registry). Override with `DEV_REGISTRY` or pass as second argument to `push`.
- To publish, run `./base-image/build.sh push r5t.io/agentic` (tags `r5t.io/agentic/dev-workspace-base:<tag>`); the default `localhost:5000` registry is for local development and CI only.

### Extensions (`extensions/`)

Extensions build on top of the base image to add specific capabilities without polluting the base. Each extension has its own `Containerfile`, `build.sh`, and `README.md`. Extensions keep the base lean while enabling agent-ready workspaces when needed.

**Available extensions:**

- **Hermes Agent** (`extensions/hermes/`) — Installs [Hermes Agent](https://hermes-agent.nousresearch.com/) with ACP (Agent Communication Protocol) support for IDE integration. Uses a shallow git clone of the upstream repo (pip installs are unsupported). Works with VS Code (ACP Client extension), Zed (ACP Registry), and JetBrains (ACP plugins).
- **Pi Coding Agent** (`extensions/pi/`) — Installs the [Pi coding agent](https://pi.dev) ([earendil-works/pi](https://github.com/earendil-works/pi)) from the official npm package (`@earendil-works/pi-coding-agent`) with `--ignore-scripts`. Terminal coding agent with interactive TUI, print, RPC, and SDK modes. Bakes in the keyless `r5t` provider (`https://llm.r5t.io/v1`, model `qwen3.8-27b`) as the default LLM in `~/.pi/agent/models.json` + `settings.json`. Its build pulls the base image `${REGISTRY}/dev-workspace-base:<same git-describe tag>` from the registry (override with `DEV_BASE_IMAGE`), so the base image must be pushed before building pi; publish with `./extensions/pi/build.sh push r5t.io/agentic`.
- **PiG (Pi in Go)** (`extensions/pi-in-go/`) — Installs [PiG](https://pi-in-go.dev/) ([MichaelKinsy/PiG](https://github.com/MichaelKinsy/PiG)), a faithful Go implementation of the Pi coding agent, from the official npm package (`@pi-in-go/pig`) with `--ignore-scripts`. A single native binary (no Node runtime needed unless running TypeScript extensions) with interactive TUI, print/JSON, RPC, and Go SDK modes; extensions in Go, Rust, Python, or Node, plus Piglets. Bakes in the keyless `r5t` provider (`https://llm.r5t.io/v1`, model `qwen3.8-27b`) as the default LLM in `~/.pig/agent/models.json` + `settings.json`. Its build pulls the base image `${REGISTRY}/dev-workspace-base:<same git-describe tag>` from the registry (override with `DEV_BASE_IMAGE`), so the base image must be pushed before building PiG; publish with `./extensions/pi-in-go/build.sh push r5t.io/agentic`.
- **Xpra Remote X11 Desktop** (`extensions/xpra/`) — Installs the [Xpra](https://xpra.org) server (Fedora package, with its headless Xorg/Xdummy + xauth deps) plus X11 desktop support (`xorg-x11-server-Xvfb`, `xset`, `xinput`, `xorg-x11-fonts-Type1`, `openbox`, `xterm`, `kitty`) and the [xpra-html5](https://github.com/Xpra-org/xpra-html5) browser client, installed from the upstream git repo at a pinned commit into `/usr/share/xpra/www` (not on PyPI). The `xpra-desktop` launcher starts a daemonized `start-desktop` session (Xdummy by default, `--xvfb` for Xvfb) running openbox and xterm, served on a TCP/WebSocket port with the HTML5 client — a headless container desktop usable from any browser or a native `xpra` client. The image's `CMD` is the `xpra-entrypoint` script: with no arguments it serves an empty X11 desktop (openbox) on a TCP/WebSocket port for the container's lifetime, and with arguments it runs the command as the container's foreground process inside a daemonized session (its stdout/stderr go to the container logs and its exit code becomes the container's). Its build pulls the base image `${REGISTRY}/dev-workspace-base:<same git-describe tag>` from the registry (override with `DEV_BASE_IMAGE`), so the base image must be pushed before building; publish with `./extensions/xpra/build.sh push r5t.io/agentic`.

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
9. **PiG credentials**: The baked-in `r5t` provider (`qwen3.8-27b`) needs no API key, so `pig` works out of the box. For any other provider, pre-populate an env var (e.g. `ANTHROPIC_API_KEY`) via a ConfigMap/Secret, or run `pig` and use `/login`. Set `PIG_OFFLINE=1` (or `PI_OFFLINE=1`) to silence startup network calls (update check, model-catalog fetch) in air-gapped workspaces.

## Adding New Components

- **New language/tool**: Add it to the base image following *Adding a New Binary Tool to the Base Image* below, then rebuild and update the Devfile image reference.
- **New extension**: Create a directory under `extensions/` with a `Containerfile` that extends the base image, a `build.sh` following the same pattern as `base-image/build.sh`, and a `README.md`.
- **New IDE**: Add a commented-out component block in the Devfile (see VS Code example).
- **Project-specific devfile**: Copy `devfiles/devfile.yaml`, update `projects`, `commands`, and add project-specific env vars or endpoints.

## Development Tips

### Verifying Artifact Stages

The Containerfile uses per-arch download stages → parallel install stages → scratch artifact stages → final assembly. After changing COPY directives in artifact stages, verify they capture all needed files:

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

Note: local nested `buildah`/`podman` builds inside a DevWorkspaces workspace may fail with `potentially insufficient UIDs or GIDs available in user namespace` (e.g. unpacking cosign's `nonroot` user, UID 65532). That is a rootless subuid-range limitation of the workspace environment, not a Containerfile bug. A full in-workspace build and push to `r5t.io/agentic` has succeeded (v0.16.0 on 2026-09-08), so running the whole build inside a live workspace is reasonable; for edge failures, the CI build with full subuid ranges is the source of truth.

## Adding a New Binary Tool to the Base Image

The Containerfile is structured as **per-arch download stages → parallel install stages → `FROM scratch` artifact stages → a single final assembly**. A new tool needs the download, install, and artifact parts, plus doc sync.

### 1. Pick the install method

| Method                | Where it goes                                     | Examples                                                         |
| --------------------- | ------------------------------------------------- | ---------------------------------------------------------------- |
| npm global            | `nodejs-install` (`FROM base`, Node 26 via fnm)   | typescript-language-server, yaml-language-server, pnpm, eslint   |
| `go install`          | `go-install` (`FROM downloader`, Go toolchain)    | gopls, golangci-lint-langserver, golangci-lint                   |
| rustup / cargo        | `rust-install` (`FROM base`)                      | rust-analyzer, cargo-binstall                                    |
| pip                   | `python-install` (`FROM base`)                    | pyright, ruff, mypy, pyrefly, black, pylint                      |
| Raw binary download   | `<tool>-download-${TARGETARCH}` + install stage   | protols, marksman, helm-ls, tofu-ls, kubeconform, ast-grep       |

- If the tool is available through a package manager, append it to that stage's existing install command (`npm install -g …`, `go install <pkg>@<ref>`, `rustup component add …`, `cargo install <pkg>`, `pip3 install --no-cache-dir --break-system-packages …`). No new stage needed: the existing artifact stage already captures its output directory.
- Otherwise add three stages: a per-arch pair `FROM scratch AS <tool>-download-amd64`/`-arm64` (each a single `ADD` to a canonical `/download/<name>`), a `FROM <tool>-download-${TARGETARCH} AS <tool>-download` selector with a `# hadolint ignore=DL3006` comment above it, and a `FROM downloader AS <tool>-install` stage that consumes the file via `COPY --from=<tool>-download` when no unpack step is needed, or a bind-mounted `RUN` otherwise (see `kubeconform` for the minimal shape). The version ARGs live in global scope at the top of the file; the download stages redeclare them bare. Place the new stages next to related tools and add the matching `<tool>-artifacts` stage in the `# EXTRAS` block.

### 2. Pick the verification method

1. **Upstream publishes per-arch SHA-256s** (`.sha256` sidecars, `checksums.txt`, `CHECKSUMS`) → pin the hashes in per-arch `FROM scratch` download stages so a build only downloads the selected arch. This is the standard pattern (go, uv, kubectl-linstor, tofu-ls, protols, kubeconform, agctl, marksman, helm-ls, ast-grep, gh, herdr):

   ```dockerfile
   FROM scratch AS <tool>-download-amd64
   ARG TARGETARCH
   ARG <TOOL>_VERSION
   ADD --checksum=sha256:<hash-amd64> \
       https://example.com/tool-${TOOL_VERSION}-linux-amd64 /download/tool

   FROM scratch AS <tool>-download-arm64
   ARG TARGETARCH
   ARG <TOOL>_VERSION
   ADD --checksum=sha256:<hash-arm64> \
       https://example.com/tool-${TOOL_VERSION}-linux-arm64 /download/tool

   # hadolint ignore=DL3006
   FROM <tool>-download-${TARGETARCH} AS <tool>-download

   FROM downloader AS <tool>-install
   RUN --mount=type=bind,dst=/download,from=<tool>-download,src=/download/ \
       tar -xzf /download/tool.tar.gz -C /usr/local/bin <bin>
   ```

   One scratch stage per architecture, each with a single `ADD` to a canonical `/download/<name>` destination; buildah expands the global `ARG TARGETARCH` in the selector `FROM` to pick exactly one of them, so cache-miss builds only download the selected arch. Copy-only installs use a plain `COPY --from=<tool>-download` (the mode set by `ADD --chmod=0755` survives the copy); installs that unpack use `RUN --mount=type=bind,dst=/download,from=<tool>-download,src=/download/` and reference only the canonical name, so no arch variable appears in any `RUN` (buildah's `ADD` has no `--unpack` flag). The bind mount is read-only, so unpacking RUNs only read from it. The `# hadolint ignore=DL3006` line suppresses hadolint's false positive that treats the selector as an untagged external image. Version ARGs are declared globally at the top of the file; the download stages redeclare them bare so the `ADD` URLs can expand. The hashes are pinned in the file, so every version bump must update them; see *Hash Recomputation on Bumps*.
2. **Upstream publishes a checksum file, but the release lacks an asset for one architecture** so not every download can be pinned → fetch the file at build time and verify with it (mcp-cli: no `linux-arm64` asset upstream):

   ```dockerfile
   EXPECTED=$(grep "<asset-name>$" checksums.txt | awk '{print $1}') && \
   echo "${EXPECTED}  <downloaded-file>" | sha256sum -c -
   ```
3. **Release is cosign-signed or SLSA-attested → verify the signature instead of hashes** (crush, kubeseal, cloudnative-pg, cert-manager).
4. **No verification available → say so explicitly** in a stage comment (forgejo-cli, fnm).

### 3. Extract release tarballs safely

Inspect the layout first (`tar -tzf <archive>`): many release tarballs bundle `LICENSE` / `README` next to the binary. Extract **only the binary member** so `/usr/local/bin` is not cluttered:

```dockerfile
tar -xzf tool.tar.gz -C /usr/local/bin <bin>
```

### 4. Wire it into the final image

1. **Artifact stage** (in the `# EXTRAS` block for binary-download tools):

   ```dockerfile
   FROM scratch AS <tool>-artifacts
   COPY --from=<tool>-install /usr/local/bin/<bin> /usr/local/bin/
   ```

2. **Final assembly**: add a `COPY --link --from=<tool>-artifacts / /` line to the `final` stage next to the other toolchains.
3. **Shell completions**: if the tool has a `completion` subcommand, add it to the completion-generation loops in the `final` stage (currently covers cosign, fj, kubectl-cnpg, cmctl, agctl, gh, bun, fnm, uv, buildah, herdr, nono).

### 5. Sync the docs (all surfaces)

1. The **`Toolchain includes`** bullet in the Base Image section above.
2. The `## Toolchain` table in `README.md` for major tools, and/or its `**LSP servers**` / `**Linters & formatters**` tables.
3. The **Per-Tool Lookup Commands** table below: add a row for the new `ARG <TOOL>_VERSION` with a minimal-output lookup command.
4. Note when the binary name differs from the package name (`fj`/forgejo-cli, `agctl`/agentgateway) so future lookups use the right name.

The markdown tables in this file and in `README.md` are **column-aligned** (pipes at fixed column positions). Match the alignment of existing rows when inserting one.

Then rebuild (`./base-image/build.sh`), check with `hadolint base-image/Containerfile`, and commit; the `.devfile.yaml` tag bump and release tagging happen later, in *Post-Bump Housekeeping*.

## Updating Base Image Tool Versions

The base image pins ~24 binary tools, either as `ARG *_VERSION` values or as image tags/digests (cosign, curlimages/curl, oven/bun). To update everything to the latest upstream releases:

1. Create a todo list with one item per pinned tool, then check releases **one at a time**. Never fetch release info for all tools in parallel: a single raw GitHub API release JSON response is enough to overflow the session context.
2. For each tool, look up the latest release with the minimal-output command from the table below and compare it to the pin in the Containerfile.
3. If a newer version exists, edit the global `ARG` line (plus the two per-arch `--checksum` hashes where applicable — see *Hash Recomputation on Bumps*), then immediately commit that single tool with the message `📦 chore(base-image): update <tool> from <old> to <new>` (see *Commit Conventions*). One commit per tool, never batch.

### Environment Constraints (agent sessions)

These apply whenever an agent session needs network access — both for version lookups and for downloading/verifying release artifacts when adding or updating tools.

- `curl` and `wget` are not available in the bash tool; use the `download` tool to save non-GitHub JSON endpoints (Docker Hub, go.dev, Codeberg, nodejs.org) **and binary release assets** to /tmp, then parse JSON with `jq` or verify binaries with `sha256sum` / `tar`.
- The `gh` CLI is installed and authenticated; always use `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name` for GitHub repos and never fetch raw release JSON.
- MCP GitHub release tools: never use `get_latest_release` or `get_release_by_tag` for version lookups; they return the entire release object (full changelog body plus all asset metadata, including an embedded uploader object per asset) and can consume large amounts of session tokens. The manual minimal-output commands from the table below are the default; the only acceptable MCP call is `list_releases` with a restricted `fields` selection (e.g. `["tag_name","prerelease","draft"]`) and a small `perPage` (e.g. 3). Its field enum has no `assets`, so digest cross-checks for hash-pinned tools still need the `gh api` one-liner: `gh api repos/<owner>/<repo>/releases/tags/v<ver> --jq '.assets[] | select(.name | test("linux")) | [.name, .digest] | @tsv'`.

### Per-Tool Lookup Commands

| Pin (Containerfile)       | Latest release lookup                                                                                                                                                      |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| cosign image tag          | `gh api repos/sigstore/cosign/releases/latest --jq .tag_name`                                                                                                              |
| curlimages/curl digest    | download `https://hub.docker.com/v2/repositories/curlimages/curl/tags/latest`, then `jq -r .digest`                                                                        |
| `CRUSH_VERSION`           | `gh api repos/charmbracelet/crush/releases/latest --jq .tag_name`                                                                                                          |
| `FNM_VERSION`             | `gh api repos/Schniz/fnm/releases/latest --jq .tag_name`                                                                                                                   |
| `NODE_VERSION` (major)    | download `https://nodejs.org/dist/index.json` (sorted newest first), then `jq -r '.[0].version'`; bump only when the major changes                                         |
| oven/bun digest           | download `https://hub.docker.com/v2/repositories/oven/bun/tags/latest`, then `jq -r .digest`                                                                               |
| `GO_VERSION`              | no GitHub releases; download `https://go.dev/dl/?mode=json`, then `jq -r '.[0].version'` (strip the `go` prefix) (hash pinned in ADD; recompute on bump)                   |
| `UV_VERSION`              | `gh api repos/astral-sh/uv/releases/latest --jq .tag_name` (no `v` prefix) (hash pinned in ADD; recompute on bump)                                                         |
| `FJ_VERSION`              | download `https://codeberg.org/api/v1/repos/forgejo-contrib/forgejo-cli/releases/latest`, then `jq -r .tag_name`                                                           |
| `GH_VERSION`              | `gh api repos/cli/cli/releases/latest --jq .tag_name` (hash pinned in ADD; recompute on bump)                                                                              |
| `KUBESEAL_VERSION`        | `gh api repos/bitnami/sealed-secrets/releases/latest --jq .tag_name` (verified with cosign signature, no hash to update)                                                   |
| `KUBECTL_LINSTOR_VERSION` | `gh api repos/piraeusdatastore/kubectl-linstor/releases/latest --jq .tag_name` (hash pinned in ADD; recompute on bump)                                                     |
| `CLOUDNATIVE_PG_VERSION`  | `gh api repos/cloudnative-pg/cloudnative-pg/releases/latest --jq .tag_name`                                                                                                |
| `CERT_MANAGER_VERSION`    | `gh api repos/cert-manager/cmctl/releases/latest --jq .tag_name`                                                                                                           |
| `AGENTGATEWAY_VERSION`    | `gh api repos/agentgateway/agentgateway/releases/latest --jq .tag_name` (hash pinned in ADD; recompute on bump)                                                            |
| `MCP_CLI_VERSION`         | `gh api repos/philschmid/mcp-cli/releases/latest --jq .tag_name` (no linux-arm64 asset upstream; build-time `checksums.txt` fallback)                                      |
| `MARKSMAN_VERSION`        | `gh api repos/artempyanykh/marksman/releases/latest --jq .tag_name` (date-based tag, `2026-02-08`; used bare in the URL, no `v`; hash pinned in ADD, recompute on bump)    |
| `HELM_LS_VERSION`         | `gh api repos/mrjosh/helm-ls/releases/latest --jq .tag_name` (hash pinned in ADD; recompute on bump)                                                                       |
| `TOFU_LS_VERSION`         | `gh api repos/opentofu/tofu-ls/releases/latest --jq .tag_name` (hash pinned in ADD; update from the upstream checksum file on bump)                                        |
| `PROTOLS_VERSION`         | `gh api repos/kralicky/protols/releases/latest --jq .tag_name` (hash pinned in ADD; update from the upstream checksum file on bump)                                        |
| `HERDR_VERSION`           | `gh api repos/herdrdev/herdr/releases/latest --jq .tag_name` (hash pinned in ADD; recompute on bump)                                                                       |
| `AST_GREP_VERSION`        | `gh api repos/ast-grep/ast-grep/releases/latest --jq .tag_name` (no `v` prefix; hash pinned in ADD, recompute on bump)                                                     |
| `KUBECONFORM_VERSION`     | `gh api repos/yannh/kubeconform/releases/latest --jq .tag_name` (hash pinned in ADD; update from the upstream checksum file on bump)                                       |
| `PI_VERSION`              | `gh api repos/earendil-works/pi/releases/latest --jq .tag_name` (extension image `extensions/pi/`; npm registry is the install source, see note below)                     |
| `PIG_VERSION`             | `gh api repos/MichaelKinsy/PiG/releases/latest --jq .tag_name` (extension image `extensions/pi-in-go/`; npm registry `@pi-in-go/pig` is the install source, see note)      |
| `SIMPLEX_CHAT_VERSION`    | `gh api repos/simplex-chat/simplex-chat/releases/latest --jq .tag_name` (no `v` prefix; hash published in the release body; recompute on bump)                             |
| `NONO_VERSION`            | `gh api repos/nolabs-ai/nono/releases/latest --jq .tag_name` (strip the `v` prefix; hash published in the release's `SHA256SUMS.txt`; recompute on bump)                   |

Note: the pi extension installs the npm package `@earendil-works/pi-coding-agent` (`extensions/pi/Containerfile`), so the npm registry is the source of truth for what actually gets installed: download `https://registry.npmjs.org/@earendil-works%2Fpi-coding-agent/latest`, then `jq .version` to cross-check the ARG. Likewise, the PiG extension installs the npm package `@pi-in-go/pig` (`extensions/pi-in-go/Containerfile`): download `https://registry.npmjs.org/@pi-in-go%2Fpig/latest`, then `jq .version` to cross-check `PIG_VERSION` (the GitHub release tag `v<tag>` sources the release archives).

### Hash Recomputation on Bumps

Fourteen tools pin per-architecture SHA-256 hashes in the `ADD --checksum=sha256:…` lines of their per-arch download stages: go, uv, kubectl-linstor, tofu-ls, protols, kubeconform, agctl, marksman, helm-ls, ast-grep, gh, herdr, simplex-chat, nono. After bumping one of their global `ARG <TOOL>_VERSION` lines, update both `--checksum` values.

**Case 1 — upstream publishes a hash file (go, uv, kubectl-linstor, tofu-ls, protols, kubeconform, agctl, gh, nono).** Download only the hash file with the `download` tool (no binary fetch needed) and read the new hashes:

   - go: `https://dl.google.com/go/go<ver>.linux-amd64.tar.gz.sha256` and `.../go<ver>.linux-arm64.tar.gz.sha256`
   - uv: `https://github.com/astral-sh/uv/releases/download/<ver>/uv-x86_64-unknown-linux-gnu.tar.gz.sha256` and `.../uv-aarch64-unknown-linux-gnu.tar.gz.sha256`
   - kubectl-linstor: `https://github.com/piraeusdatastore/kubectl-linstor/releases/download/v<ver>/kubectl-linstor_v<ver>_checksums.txt`
   - tofu-ls: `https://github.com/opentofu/tofu-ls/releases/download/v<ver>/tofu-ls_v<ver>_checksums.txt`
   - protols: `https://github.com/kralicky/protols/releases/download/v<ver>/checksums.txt`
   - kubeconform: `https://github.com/yannh/kubeconform/releases/download/v<ver>/CHECKSUMS`
   - agctl: `https://github.com/agentgateway/agentgateway/releases/download/v<ver>/agctl-linux-amd64.sha256` and `.../agctl-linux-arm64.sha256`
   - gh: `https://github.com/cli/cli/releases/download/v<ver>/gh_<ver>_checksums.txt`
   - nono: `https://github.com/nolabs-ai/nono/releases/download/v<ver>/SHA256SUMS.txt`

**Case 2 — no hash file (marksman, helm-ls, ast-grep, herdr, simplex-chat).** Download each release asset into /tmp with the `download` tool and run `sha256sum /tmp/<asset>` on each file:

   - marksman: `https://github.com/artempyanykh/marksman/releases/download/<tag>/marksman-linux-x64` and `.../marksman-linux-arm64`
   - helm-ls: `https://github.com/mrjosh/helm-ls/releases/download/v<ver>/helm_ls_linux_amd64` and `.../helm_ls_linux_arm64`
   - ast-grep: `https://github.com/ast-grep/ast-grep/releases/download/<ver>/app-x86_64-unknown-linux-gnu.zip` and `.../app-aarch64-unknown-linux-gnu.zip` — hash the `.zip` files: the Containerfile verifies the zip before unzipping.
   - herdr: `https://github.com/herdrdev/herdr/releases/download/v<ver>/herdr-linux-x86_64` and `.../herdr-linux-aarch64`
   - simplex-chat: `https://github.com/simplex-chat/simplex-chat/releases/download/v<ver>/simplex-chat-ubuntu-22_04-x86_64` and `.../simplex-chat-ubuntu-22_04-aarch64` (hashes also published in the release body; older releases ship a GPG-signed `_sha256sums`)

Then update both `--checksum=sha256:…` values in the tool's two download stages and the global `ARG <TOOL>_VERSION` line, and rebuild.

### Post-Bump Housekeeping

The full release flow, in order:

1. Commit tool bumps one at a time (see *Commit Conventions*), one commit per tool, never batched.
2. Sync docs: the `Toolchain includes` bullet in the Base Image section and the `## Toolchain` table in `README.md` must match the Containerfile.
3. Bump the image references in `.devfile.yaml` and in this file's Self-hosting Devfile section to the new tag, in one commit.
4. Tag the final HEAD: `git tag vN.N.N`. The image tag derives from `git describe --tags --always --dirty` (with the leading `v` stripped), so the tag must exist and the tree must be clean at build time, or the image tag gets a `-dirty` suffix.
5. Build and push: `./base-image/build.sh push r5t.io/agentic` → `r5t.io/agentic/dev-workspace-base:<tag>`.
6. Only if `PI_VERSION` changed: `./extensions/pi/build.sh push r5t.io/agentic`. The pi build pulls `${REGISTRY}/dev-workspace-base:<same tag>` from the registry (`DEV_BASE_IMAGE` override), so the base image must be pushed first. Likewise, only if `PIG_VERSION` changed: `./extensions/pi-in-go/build.sh push r5t.io/agentic` (the PiG build pulls the same base image tag).
7. Never rebase across a release tag: a stranded tag makes `git describe` fall back to the last reachable tag and silently degrades the image tag (this happened to `v0.15.0`, which degraded `git describe` on `main` to `v0.14.3-N-g<sha>` until a clean tag was created). If it ever happens, re-tag onto the equivalent new commit.
8. Agent sessions stop here: local commits, the tag, and the image push are done. Pushing the branch and the tag to origin is the user's job.
