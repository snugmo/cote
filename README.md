# Dev Workspace Images

OCI-based coding workspaces for human developers and AI agents. Provides a universal toolchain with compilers, package managers, LSP servers, and shell utilities — no IDEs baked in, so you can plug in whatever editor or agent you prefer.

## Toolchain

| Language / Tool | Version | Source |
|-----------------|---------|--------|
| **[Go](https://go.dev)** | 1.26.5 | golang.org/dl |
| **[Node.js](https://nodejs.org)** | 24 LTS | [fnm](https://github.com/Schniz/fnm) |
| **[Bun](https://bun.sh)** | latest | [oven-sh/bun](https://github.com/oven-sh/bun) (OCI image) |
| **[Python](https://python.org)** | Fedora 44 stock | dnf |
| **[Rust](https://rust-lang.org)** | stable | [rustup](https://github.com/rust-lang/rustup) |
| **[GCC](https://gcc.gnu.org) / [Clang](https://clang.llvm.org)** | Fedora 44 stock | dnf |
| **[Crush CLI](https://github.com/charmbracelet/crush)** | 0.85.0 | GitHub release, cosign verified |
| **[uv](https://github.com/astral-sh/uv)** | 0.11.29 | GitHub release |
| **[cosign](https://github.com/sigstore/cosign)** | 3.1.1 | OCI image |

**LSP servers**:

| Server | Languages | File extensions |
|--------|-----------|-----------------|
| [gopls](https://github.com/golang/tools/tree/master/gopls) | Go | `.go` |
| [typescript-language-server](https://github.com/typescript-language-server/typescript-language-server) | TypeScript, JavaScript | `.ts`, `.tsx`, `.js`, `.jsx` |
| [pyright](https://github.com/microsoft/pyright) | Python | `.py` |
| [ruff-lsp](https://github.com/astral-sh/ruff-lsp) | Python | `.py` |
| [yaml-language-server](https://github.com/redhat-developer/yaml-language-server) | YAML | `.yaml`, `.yml` |
| [marksman](https://github.com/artempyanykh/marksman) | Markdown | `.md` |
| [helm-ls](https://github.com/mrjosh/helm-ls) | Helm | `.yaml`, `.yml` |
| [bash-language-server](https://github.com/bash-lsp/bash-language-server) | Bash, Shell | `.sh`, `.bash`, `.zsh`, `.fish` |
| [dockerfile-language-server](https://github.com/rcjsuen/dockerfile-language-server) | Dockerfile | `Dockerfile`, `Containerfile`, `.dockerfile` |
| [clangd](https://github.com/clangd/clangd) | C, C++, Objective-C | `.c`, `.h`, `.cpp`, `.cc`, `.cxx`, `.hpp`, `.m`, `.mm` |
| [rust-analyzer](https://github.com/rust-lang/rust-analyzer) | Rust | `.rs`, `Cargo.toml` |

**Linters & formatters**:

| Tool | Languages | File extensions |
|------|-----------|-----------------|
| [shellcheck](https://github.com/koalaman/shellcheck) | Bash, Shell | `.sh`, `.bash`, `.zsh`, `.fish` |
| [shfmt](https://github.com/mvdan/sh) | Shell (formatter) | `.sh`, `.bash`, `.zsh` |
| [hadolint](https://github.com/hadolint/hadolint) | Dockerfile | `Dockerfile`, `Containerfile`, `.dockerfile` |
| [golangci-lint](https://github.com/golangci/golangci-lint) | Go | `.go` |
| [eslint](https://github.com/eslint/eslint) | JavaScript, TypeScript | `.js`, `.jsx`, `.ts`, `.tsx` |
| [prettier](https://github.com/prettier/prettier) | JavaScript, TypeScript, JSON, YAML, Markdown, CSS | `.js`, `.ts`, `.json`, `.yaml`, `.md`, `.css` |
| [pylint](https://github.com/pylint-dev/pylint) | Python | `.py` |
| [ruff](https://github.com/astral-sh/ruff) | Python | `.py` |
| [mypy](https://github.com/python/mypy) | Python (type checker) | `.py` |
| [black](https://github.com/psf/black) | Python (formatter) | `.py` |

**Kubernetes / cloud tools**: `kubectl`, `helm`, `kustomize`, `opentofu`, `awscli2`, `kubeseal`, `kubectl-cnpg`, `kubectl-linstor`, `cmctl`, `agctl`, `mcp-cli`, `fj`, `gh`.

**Shell utilities**: `git`, `ripgrep`, `fd-find`, `jq`, `yq`, `bat`, `glow`, `tmux`, `age`, `gnupg2`, `ImageMagick`, `libsixel-utils`.

## Extensions

Optional add-on images built on the base:

- **[Hermes agent](extensions/hermes/)** — AI coding agent with ACP support for IDE integration (VS Code, Zed, JetBrains).

## Usage

### DevWorkspaces Operator

The recommended way to run these images in Kubernetes:

```bash
# Build and push the base image
./base-image/build.sh push <registry>

# Apply a workspace
kubectl apply -f devfiles/devfile.yaml
```

See [AGENTS.md](AGENTS.md) for Devfile conventions and gotchas.

### Standalone

Run directly with podman/buildah:

```bash
./base-image/build.sh
podman run -it --rm localhost:5000/dev-workspace-base:latest
```

## Design

- Base image provides compilers, package managers, shell utils, and LSP servers — no IDEs baked in.
- IDEs and AI agents are added as Devfile components or extension images.
- Extensions keep the base lean while enabling agent-ready workspaces when needed.
- Workspace containers run as non-root (UID 1000).
- All binary downloads are verified as far as possible (SHA-256 checksums, cosign signatures, or SLSA provenance) — not all upstreams provide cryptographic signatures.

## Details

See [AGENTS.md](AGENTS.md) for conventions, commands, and gotchas.
