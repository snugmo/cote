# Base Image Build Reference

> **On-demand reference** — read when building or editing `base-image/`. The always-relevant facts (no IDEs, Fedora 44, non-root UID 1000) live in [AGENTS.md](../AGENTS.md); the deep build mechanics live here.

## Containerfile architecture

The Containerfile is structured as **per-arch download stages → parallel install stages → `FROM scratch` artifact stages → a single final assembly**.

Per-arch release assets download only the selected arch: each tool has `FROM scratch AS <tool>-download-amd64` and `FROM scratch AS <tool>-download-arm64` stages (one `ADD` to a canonical `/download/<name>` destination each) and a `FROM <tool>-download-${TARGETARCH} AS <tool>-download` selector. buildah expands the global `ARG TARGETARCH` in that selector to pick exactly one of the two stages, so a cache-miss build only downloads the selected arch.

The final stage assembles everything from the `# EXTRAS` block: each tool contributes a `FROM scratch AS <tool>-artifacts` stage, and the final stage pulls them in with `COPY --link --from=<tool>-artifacts / /` next to the other toolchains.

## Facts

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
- All binary downloads are verified as far as possible: where upstreams publish SHA-256s, the download itself is an `ADD --checksum=sha256:…` in the Containerfile; otherwise cosign signatures or SLSA provenance — not all upstreams provide cryptographic signatures.

## Devfiles

- **`devfiles/devfile.yaml`** — the reusable end-user template (Devfile schema `2.2.0`). The `tools` container mounts source and provides the shared toolchain; IDE components are commented out by default (uncomment per-team). Env vars (`GOPATH`, `CARGO_HOME`, `RUSTUP_HOME`, `JAVA_HOME`, `PATH`) are baked into the image, so no `env` block is needed. Persistent volumes (`tools-cache`, `tools-local`) survive pod restarts for pip/npm/cargo caches. The `image` field defaults to `ghcr.io/snugmo/cote:latest-base`. The commands section includes `run-tests` (placeholder) and `rebuild-base-image` (runs buildah inside the workspace).
- **`.devfile.yaml`** — the self-hosting devfile: opens this repo itself as a workspace and references the pre-built base image at `ghcr.io/snugmo/cote:0.34.0-base` (bump the tag when a new base image is released). Use it to iterate on the repo configuration inside a live workspace.

## Verifying Artifact Stages

After changing `COPY` directives in artifact stages, verify they capture all needed files:

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

3. **Cross-reference** the output against `COPY` directives in the artifact stages to find missing files.

Note: local nested `buildah`/`podman` builds inside a DevWorkspaces workspace may fail with `potentially insufficient UIDs or GIDs available in user namespace` (e.g. unpacking cosign's `nonroot` user, UID 65532). That is a rootless subuid-range limitation of the workspace environment, not a Containerfile bug. A full in-workspace build and push to `r5t.io/agentic` has succeeded (v0.16.0 on 2026-09-08), so running the whole build inside a live workspace is reasonable; for edge failures, the CI build with full subuid ranges is the source of truth.
