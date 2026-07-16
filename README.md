# DevWorkspaces Operator Configuration

Configuration for the [DevWorkspaces Operator](https://devfile.io/) — cloud-native development environments as Kubernetes resources.

## What's Inside

- **`base-image/`** — OCI image with a universal dev toolchain (GCC, Go, Rust, Node.js 24, Python 3, Crush, glow, LSP servers). IDEs are excluded by design.
- **`devfiles/`** — Devfile 2.2.0 workspace template referencing the base image, with extension points for IDEs and project-specific tools.

## Quick Start

```bash
# Build and push the base image
./base-image/build.sh push <registry>

# Update the image reference in devfiles/devfile.yaml, then apply
kubectl apply -f devfiles/devfile.yaml
```

## Design

- The base image provides compilers, package managers, shell utils, and LSP servers.
- IDEs (VS Code, Eclipse Che, etc.) are added as separate Devfile components — never baked into the base image.
- Workspace containers run as non-root (UID 1000) to match DevWorkspaces security defaults.

## Details

See [AGENTS.md](AGENTS.md) for conventions, commands, and gotchas.
