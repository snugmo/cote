# Adding a New Binary Tool to the Base Image

> **On-demand playbook** — read when adding a new binary or language tool to `base-image/Containerfile`. See [base-image.md](base-image.md) for the Containerfile stage architecture this playbook builds on.

The Containerfile is structured as **per-arch download stages → parallel install stages → `FROM scratch` artifact stages → a single final assembly**. A new tool needs the download, install, and artifact parts, plus doc sync.

> **Network / download constraints** for agent sessions (no `curl`/`wget`, use the `download` tool, `gh api` for GitHub, MCP limits) are documented in [updating-tool-versions.md](updating-tool-versions.md) → *Environment Constraints*. They apply here too.

### 1. Pick the install method

| Method                | Where it goes                                     | Examples                                                         |
| --------------------- | ------------------------------------------------- | ---------------------------------------------------------------- |
| npm global            | `nodejs-install` (`FROM base`, Node 26 via fnm)   | typescript-language-server, yaml-language-server, pnpm, eslint   |
| `go install`          | `go-install` (`FROM downloader`, Go toolchain)    | gopls, golangci-lint-langserver, golangci-lint                   |
| rustup / cargo        | `rust-install` (`FROM base`)                      | rust-analyzer, cargo-binstall                                    |
| pip                   | `python-install` (`FROM base`)                    | pyright, ruff, mypy, pyrefly, black, pylint                      |
| Raw binary download   | `<tool>-download-${TARGETARCH}` + install stage   | protols, marksman, helm-ls, tofu-ls, kubeconform, ast-grep       |

- If the tool is available through a package manager, append it to that stage's existing install command (`npm install -g …`, `go install <pkg>@<ref>`, `rustup component add …`, `cargo install <pkg>`, `pip3 install --no-cache-dir --break-system-packages …`). No new stage needed: the existing artifact stage already captures its output directory.
- Otherwise add three stages: a per-arch pair `FROM scratch AS <tool>-download-amd64`/`-arm64` (each a single `ADD` to a canonical `/download/<name>`), a `FROM <tool>-download-${TARGETARCH} AS <tool>-download` selector with a `# hadolint ignore=DL3006` comment above it, and a `FROM downloader AS <tool>-install` stage that starts with `COPY --from=<tool>-download /download/<name> /download/<name>` and, when the artifact needs unpacking, follows it with an unpack `RUN` (see `kubeconform` for the minimal shape). The version ARGs live in global scope at the top of the file; the download stages redeclare them bare. Place the new stages next to related tools and add the matching `<tool>-artifacts` stage in the `# EXTRAS` block.

### 2. Pick the verification method

1. **Upstream publishes per-arch SHA-256s** (`.sha256` sidecars, `checksums.txt`, `CHECKSUMS`) → pin the hashes in per-arch `FROM scratch` download stages so a build only downloads the selected arch. This is the standard pattern (go, uv, kubectl-linstor, tofu-ls, protols, kubeconform, marksman, helm-ls, ast-grep, gh, herdr):

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
   COPY --from=<tool>-download /download/tool.tar.gz /download/tool.tar.gz
   RUN tar -xzf /download/tool.tar.gz -C /usr/local/bin <bin>
   ```

   One scratch stage per architecture, each with a single `ADD` to a canonical `/download/<name>` destination; buildah expands the global `ARG TARGETARCH` in the selector `FROM` to pick exactly one of them, so cache-miss builds only download the selected arch. Every install stage consumes the download stage via `COPY --from=<tool>-download` — copy-only installs go straight to `/usr/local/bin` (the mode set by `ADD --chmod=0755` survives the copy), while unpacking installs copy the archive into the stage and follow it with an unpack `RUN` that references only the canonical name, so no arch variable appears in any `RUN` (buildah's `ADD` has no `--unpack` flag). `COPY --from` includes the source stage's image in its cache key, so a version bump that changes the download stage's `ADD` layer correctly invalidates the install stage and everything downstream; a `RUN --mount=type=bind,from=` does *not* include the mounted content in its cache key and can silently reuse stale installs of a re-downloaded archive. The `# hadolint ignore=DL3006` line suppresses hadolint's false positive that treats the selector as an untagged external image. Version ARGs are declared globally at the top of the file; the download stages redeclare them bare so the `ADD` URLs can expand. The hashes are pinned in the file, so every version bump must update them; see [updating-tool-versions.md](updating-tool-versions.md) → *Hash Recomputation on Bumps*.
2. **Upstream publishes a checksum file, but the release lacks an asset for one architecture** so not every download can be pinned → fetch the file at build time and verify with it:

   ```dockerfile
   EXPECTED=$(grep "<asset-name>$" checksums.txt | awk '{print $1}') && \
   echo "${EXPECTED}  <downloaded-file>" | sha256sum -c -
   ```
3. **Release is cosign-signed or SLSA-attested → verify the signature instead of hashes** (crush, kubeseal, cloudnative-pg).
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
3. **Shell completions**: if the tool has a `completion` subcommand, add it to the completion-generation loops in the `final` stage (currently covers cosign, fj, kubectl-cnpg, gh, bun, fnm, uv, buildah, herdr, nono).

### 5. Sync the docs (all surfaces)

1. The **`Toolchain includes`** bullet in [AGENTS.md](../AGENTS.md) (Base Image section) and the **`Toolchain`** bullet / `**LSP servers**` / `**Linters & formatters**` tables in [README.md](../README.md).
2. The **Per-Tool Lookup Commands** table in [updating-tool-versions.md](updating-tool-versions.md): add a row for the new `ARG <TOOL>_VERSION` with a minimal-output lookup command.
3. Note when the binary name differs from the package name (`fj`/forgejo-cli) so future lookups use the right name.

The markdown tables in [AGENTS.md](../AGENTS.md) and [README.md](../README.md) are **column-aligned** (pipes at fixed column positions). Match the alignment of existing rows when inserting one.

Then rebuild (`./base-image/build.sh`), check with `hadolint base-image/Containerfile`, and commit; the `.devfile.yaml` tag bump and release tagging happen later, in [updating-tool-versions.md](updating-tool-versions.md) → *Post-Bump Housekeeping*.
