# Dev Workspace Images

OCI-based coding workspaces for human developers and AI agents. Provides a universal toolchain with compilers, package managers, LSP servers, and shell utilities — no IDEs baked in, so you can plug in whatever editor or agent you prefer.

## Toolchain

| Language / Tool | Version | Source |
|-----------------|---------|--------|
| **Go** | 1.26.5 | golang.org/dl |
| **Node.js** | 24 LTS | fnm (Schniz/fnm) |
| **Bun** | latest | oven/bun (OCI image) |
| **Python** | Fedora 44 stock | dnf |
| **Rust** | stable | rustup |
| **GCC / Clang** | Fedora 44 stock | dnf |
| **Crush CLI** | 0.85.0 | charmbracelet/crush (GitHub release, cosign verified) |
| **uv** | 0.11.29 | astral-sh/uv (GitHub release) |
| **cosign** | 3.1.1 | sigstore/cosign (OCI image) |

**LSP servers**:

| Server | Languages | File extensions |
|--------|-----------|-----------------|
| `gopls` | Go | `.go` |
| `typescript-language-server` | TypeScript, JavaScript | `.ts`, `.tsx`, `.js`, `.jsx` |
| `pyright` | Python | `.py` |
| `ruff-lsp` | Python | `.py` |
| `yaml-language-server` | YAML | `.yaml`, `.yml` |
| `bash-language-server` | Bash, Shell | `.sh`, `.bash`, `.zsh`, `.fish` |
| `dockerfile-language-server` | Dockerfile | `Dockerfile`, `Containerfile`, `.dockerfile` |
| `clangd` | C, C++, Objective-C | `.c`, `.h`, `.cpp`, `.cc`, `.cxx`, `.hpp`, `.m`, `.mm` |
| `rust-analyzer` | Rust | `.rs`, `Cargo.toml` |

**Linters & formatters**:

| Tool | Languages | File extensions |
|------|-----------|-----------------|
| `shellcheck` | Bash, Shell | `.sh`, `.bash`, `.zsh`, `.fish` |
| `shfmt` | Shell (formatter) | `.sh`, `.bash`, `.zsh` |
| `hadolint` | Dockerfile | `Dockerfile`, `Containerfile`, `.dockerfile` |
| `golangci-lint` | Go | `.go` |
| `eslint` | JavaScript, TypeScript | `.js`, `.jsx`, `.ts`, `.tsx` |
| `prettier` | JavaScript, TypeScript, JSON, YAML, Markdown, CSS | `.js`, `.ts`, `.json`, `.yaml`, `.md`, `.css` |
| `pylint` | Python | `.py` |
| `ruff` | Python | `.py` |
| `mypy` | Python (type checker) | `.py` |
| `black` | Python (formatter) | `.py` |

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
- All binary downloads are verified (SHA-256 checksums, cosign signatures, or SLSA provenance).

## Details

See [AGENTS.md](AGENTS.md) for conventions, commands, and gotchas.
