# Dev Workspace Images

Cloud-native development environments for [DevWorkspaces Operator](https://devfile.io/) — Kubernetes-based workspaces that work for both human developers and AI coding agents.

## What's Inside

- **`base-image/`** — Universal dev toolchain OCI image (Fedora 44): GCC, Clang/LLVM, Go 1.26.5, Rust, Node.js 24, Python 3, Bun, Crush CLI, plus LSP servers for Go, TypeScript, Python, YAML, and Bash.
- **`extensions/`** — Optional add-on images built on the base. Currently includes [Hermes agent](extensions/hermes/) with ACP support for IDE integration.
- **`devfiles/`** — Devfile 2.2.0 workspace templates with extension points for IDEs and project-specific tools.

## Quick Start

```bash
# Build and push the base image
./base-image/build.sh push <registry>

# Build an extension (e.g., Hermes agent)
./extensions/hermes/build.sh push <registry>

# Apply a workspace
kubectl apply -f devfiles/devfile.yaml
```

## Design

- Base image provides compilers, package managers, shell utils, and LSP servers — no IDEs baked in.
- IDEs (VS Code, Zed, etc.) and AI agents are added as Devfile components or extension images.
- Extensions keep the base lean while enabling agent-ready workspaces when needed.
- Workspace containers run as non-root (UID 1000) to match DevWorkspaces security defaults.

## Details

See [AGENTS.md](AGENTS.md) for conventions, commands, and gotchas.
