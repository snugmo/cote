# Updating Base Image Tool Versions

> **On-demand playbook** — read when bumping a pinned tool to a newer upstream release. The base image pins ~24 binary tools, either as `ARG *_VERSION` values or as image tags/digests (cosign, curlimages/curl, oven/bun).

To update everything to the latest upstream releases:

1. Create a todo list with one item per pinned tool, then check releases **one at a time**. Never fetch release info for all tools in parallel: a single raw GitHub API release JSON response is enough to overflow the session context.
2. For each tool, look up the latest release with the minimal-output command from the table below and compare it to the pin in the Containerfile.
3. If a newer version exists, edit the global `ARG` line (plus the two per-arch `--checksum` hashes where applicable — see *Hash Recomputation on Bumps* below), then immediately commit that single tool with the message `📦 chore(base-image): update <tool> from <old> to <new>` (see [Commit Conventions](../AGENTS.md#commit-conventions)). One commit per tool, never batch.

## Environment Constraints (agent sessions)

These apply whenever an agent session needs network access — both for version lookups and for downloading/verifying release artifacts when adding or updating tools.

- `curl` and `wget` are not available in the bash tool; use the `download` tool to save non-GitHub JSON endpoints (Docker Hub, go.dev, Codeberg, nodejs.org) **and binary release assets** to /tmp, then parse JSON with `jq` or verify binaries with `sha256sum` / `tar`.
- The `gh` CLI is installed and authenticated; always use `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name` for GitHub repos and never fetch raw release JSON.
- MCP GitHub release tools: never use `get_latest_release` or `get_release_by_tag` for version lookups; they return the entire release object (full changelog body plus all asset metadata, including an embedded uploader object per asset) and can consume large amounts of session tokens. The manual minimal-output commands from the table below are the default; the only acceptable MCP call is `list_releases` with a restricted `fields` selection (e.g. `["tag_name","prerelease","draft"]`) and a small `perPage` (e.g. 3). Its field enum has no `assets`, so digest cross-checks for hash-pinned tools still need the `gh api` one-liner: `gh api repos/<owner>/<repo>/releases/tags/v<ver> --jq '.assets[] | select(.name | test("linux")) | [.name, .digest] | @tsv'`.

## Per-Tool Lookup Commands

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
| `MCP_CLI_VERSION`         | `gh api repos/philschmid/mcp-cli/releases/latest --jq .tag_name` (no linux-arm64 asset upstream; build-time `checksums.txt` fallback)                                      |
| `MARKSMAN_VERSION`        | `gh api repos/artempyanykh/marksman/releases/latest --jq .tag_name` (date-based tag, `2026-02-08`; used bare in the URL, no `v`; hash pinned in ADD, recompute on bump)    |
| `HELM_LS_VERSION`         | `gh api repos/mrjosh/helm-ls/releases/latest --jq .tag_name` (hash pinned in ADD; recompute on bump)                                                                       |
| `TOFU_LS_VERSION`         | `gh api repos/opentofu/tofu-ls/releases/latest --jq .tag_name` (hash pinned in ADD; update from the upstream checksum file on bump)                                        |
| `PROTOLS_VERSION`         | `gh api repos/kralicky/protols/releases/latest --jq .tag_name` (hash pinned in ADD; update from the upstream checksum file on bump)                                        |
| `HERDR_VERSION`           | `gh api repos/herdrdev/herdr/releases/latest --jq .tag_name` (hash pinned in ADD; recompute on bump)                                                                       |
| `AST_GREP_VERSION`        | `gh api repos/ast-grep/ast-grep/releases/latest --jq .tag_name` (no `v` prefix; hash pinned in ADD, recompute on bump)                                                     |
| `SHFMT_VERSION`           | `gh api repos/mvdan/sh/releases/latest --jq .tag_name` (strip the `v` prefix; hash pinned in ADD; recompute on bump)                                                       |
| `KUBECONFORM_VERSION`     | `gh api repos/yannh/kubeconform/releases/latest --jq .tag_name` (hash pinned in ADD; update from the upstream checksum file on bump)                                       |
| `PI_VERSION`              | `gh api repos/earendil-works/pi/releases/latest --jq .tag_name` (extension image `extensions/pi/`; npm registry is the install source, see note below)                     |
| `PIG_VERSION`             | `gh api repos/MichaelKinsy/PiG/releases/latest --jq .tag_name` (extension image `extensions/pi-in-go/`; npm registry `@pi-in-go/pig` is the install source, see note)      |
| `SIMPLEX_CHAT_VERSION`    | `gh api repos/simplex-chat/simplex-chat/releases/latest --jq .tag_name` (no `v` prefix; hash published in the release body; recompute on bump)                             |
| `NONO_VERSION`            | `gh api repos/nolabs-ai/nono/releases/latest --jq .tag_name` (strip the `v` prefix; hash published in the release's `SHA256SUMS.txt`; recompute on bump)                   |

Note: the pi extension installs the npm package `@earendil-works/pi-coding-agent` (`extensions/pi/Containerfile`), so the npm registry is the source of truth for what actually gets installed: download `https://registry.npmjs.org/@earendil-works%2Fpi-coding-agent/latest`, then `jq .version` to cross-check the ARG. Likewise, the PiG extension installs the npm package `@pi-in-go/pig` (`extensions/pi-in-go/Containerfile`): download `https://registry.npmjs.org/@pi-in-go%2Fpig/latest`, then `jq .version` to cross-check `PIG_VERSION` (the GitHub release tag `v<tag>` sources the release archives).

## Hash Recomputation on Bumps

Thirteen tools pin per-architecture SHA-256 hashes in the `ADD --checksum=sha256:…` lines of their per-arch download stages: go, uv, kubectl-linstor, tofu-ls, protols, kubeconform, marksman, helm-ls, ast-grep, gh, herdr, simplex-chat, nono. After bumping one of their global `ARG <TOOL>_VERSION` lines, update both `--checksum` values.

**Case 1 — upstream publishes a hash file (go, uv, kubectl-linstor, tofu-ls, protols, kubeconform, gh, nono).** Download only the hash file with the `download` tool (no binary fetch needed) and read the new hashes:

   - go: `https://dl.google.com/go/go<ver>.linux-amd64.tar.gz.sha256` and `.../go<ver>.linux-arm64.tar.gz.sha256`
   - uv: `https://github.com/astral-sh/uv/releases/download/<ver>/uv-x86_64-unknown-linux-gnu.tar.gz.sha256` and `.../uv-aarch64-unknown-linux-gnu.tar.gz.sha256`
   - kubectl-linstor: `https://github.com/piraeusdatastore/kubectl-linstor/releases/download/v<ver>/kubectl-linstor_v<ver>_checksums.txt`
   - tofu-ls: `https://github.com/opentofu/tofu-ls/releases/download/v<ver>/tofu-ls_v<ver>_checksums.txt`
   - protols: `https://github.com/kralicky/protols/releases/download/v<ver>/checksums.txt`
   - kubeconform: `https://github.com/yannh/kubeconform/releases/download/v<ver>/CHECKSUMS`
   - gh: `https://github.com/cli/cli/releases/download/v<ver>/gh_<ver>_checksums.txt`
   - nono: `https://github.com/nolabs-ai/nono/releases/download/v<ver>/SHA256SUMS.txt`

**Case 2 — no hash file (marksman, helm-ls, ast-grep, herdr, simplex-chat).** Download each release asset into /tmp with the `download` tool and run `sha256sum /tmp/<asset>` on each file:

   - marksman: `https://github.com/artempyanykh/marksman/releases/download/<tag>/marksman-linux-x64` and `.../marksman-linux-arm64`
   - helm-ls: `https://github.com/mrjosh/helm-ls/releases/download/v<ver>/helm_ls_linux_amd64` and `.../helm_ls_linux_arm64`
   - ast-grep: `https://github.com/ast-grep/ast-grep/releases/download/<ver>/app-x86_64-unknown-linux-gnu.zip` and `.../app-aarch64-unknown-linux-gnu.zip` — hash the `.zip` files: the Containerfile verifies the zip before unzipping.
   - herdr: `https://github.com/herdrdev/herdr/releases/download/v<ver>/herdr-linux-x86_64` and `.../herdr-linux-aarch64`
   - simplex-chat: `https://github.com/simplex-chat/simplex-chat/releases/download/v<ver>/simplex-chat-ubuntu-22_04-x86_64` and `.../simplex-chat-ubuntu-22_04-aarch64` (hashes also published in the release body; older releases ship a GPG-signed `_sha256sums`)

Then update both `--checksum=sha256:…` values in the tool's two download stages and the global `ARG <TOOL>_VERSION` line, and rebuild.

## Post-Bump Housekeeping

The full release flow, in order:

1. Commit tool bumps one at a time (see [Commit Conventions](../AGENTS.md#commit-conventions)), one commit per tool, never batched.
2. Sync docs: the `Toolchain includes` bullet in the Base Image section of [AGENTS.md](../AGENTS.md) and the `## Toolchain` table in [README.md](../README.md) must match the Containerfile.
3. Bump the image references in `.devfile.yaml` and in [AGENTS.md](../AGENTS.md) → *Self-hosting Devfile* to the new tag, in one commit.
4. Tag the final HEAD: `git tag vN.N.N`. The image tag derives from `git describe --tags --always --dirty` (with the leading `v` stripped and a `-base` suffix), so the tag must exist and the tree must be clean at build time, or the image tag gets a `-dirty` suffix.
5. Build and push: `./base-image/build.sh push` → `quay.io/snugmo/cote:<tag>-base`.
6. Only if `PI_VERSION` changed: `./extensions/pi/build.sh push`. The pi build pulls `${REGISTRY}/cote:<same tag>-base` from the registry (`DEV_BASE_IMAGE` override), so the base image must be pushed first. Likewise, only if `PIG_VERSION` changed: `./extensions/pi-in-go/build.sh push` (the PiG build pulls the same base image tag).
7. Never rebase across a release tag: a stranded tag makes `git describe` fall back to the last reachable tag and silently degrades the image tag (this happened to `v0.15.0`, which degraded `git describe` on `main` to `v0.14.3-N-g<sha>` until a clean tag was created). If it ever happens, re-tag onto the equivalent new commit.
8. Agent sessions stop here: local commits, the tag, and the image push are done. Pushing the branch and the tag to origin is the user's job.
