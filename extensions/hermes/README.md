# Hermes Agent Extension

Installs [Hermes Agent](https://hermes-agent.nousresearch.com/) with ACP (Agent Communication Protocol) support on top of the dev-workspace base image.

Uses a shallow git clone of the upstream repo with an editable install — pip/uv package installs are [explicitly unsupported](https://hermes-agent.nousresearch.com/docs/getting-started/platform-support) by the Hermes team.

## What is ACP?

ACP enables Hermes to run as a stdio-based agent server that IDEs can connect to natively. Supported editors include:

- **VS Code** — via [ACP Client](https://marketplace.visualstudio.com/items?itemName=formulahendry.acp-client) extension
- **Zed** — via built-in ACP Registry (Zed v0.221+)
- **JetBrains** — via ACP-compatible plugins

## Build

```bash
# Build locally
./extensions/hermes/build.sh

# Build and push
./extensions/hermes/build.sh push <registry>
```

### Environment Variables

| Variable         | Default                | Description          |
| ---------------- | ---------------------- | -------------------- |
| `DEV_REGISTRY`   | `localhost:5000`       | Target registry      |
| `DEV_IMAGE_NAME` | `dev-workspace-hermes` | Image name           |
| `DEV_VERSION`    | git tag                | Image tag            |
| `DEV_BASE_IMAGE` | auto                   | Base image reference |

## Usage in Devfile

Replace the `tools` container image:

```yaml
components:
  - name: tools
    container:
      image: <registry>/dev-workspace-hermes:<tag>
```

## IDE Setup

### VS Code

1. Install the [ACP Client](https://marketplace.visualstudio.com/items?itemName=formulahendry.acp-client) extension
2. Open the ACP Client panel
3. Select **Hermes Agent** from the agent list
4. Configure credentials with `hermes model` or set in `~/.hermes/.env`

### Zed

1. Open the Agent Panel
2. Click **Add Agent** or run `zed: acp registry`
3. Search for **Hermes Agent**
4. Install and start a new session

## Configuration

Hermes uses standard config paths:

- Credentials: `~/.hermes/.env` or `~/.hermes/config.yaml`
- Skills: `~/.hermes/skills/`
- State: `~/.hermes/state.db`

First-time setup:

```bash
hermes model        # interactive provider configuration
```

## Browser Tools (Optional)

For web scraping/browser automation:

```bash
hermes acp --setup-browser --yes
```

This installs Playwright Chromium and the `agent-browser` npm package (~400 MB).
