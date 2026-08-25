# Pi Coding Agent Extension

Installs the [Pi coding agent](https://pi.dev) ([earendil-works/pi](https://github.com/earendil-works/pi)) on top of the dev-workspace base image.

Pi is a minimal terminal coding harness with `read`, `write`, `edit`, and `bash` tools by default. It runs in four modes: interactive TUI, print/JSON, RPC for process integration, and an SDK for embedding. Extend it with TypeScript extensions, skills, prompt templates, themes, and pi packages (npm or git).

Installed from the official npm package (`@earendil-works/pi-coding-agent`) with `--ignore-scripts`, as recommended upstream. The published package ships an `npm-shrinkwrap.json` pinning all transitive dependencies, and npm verifies the tarball integrity (sha512) against the registry.

The image bakes in the **r5t** LLM provider (the org's keyless OpenAI-compatible gateway at `https://llm.r5t.io/v1`) with the `qwen3.8-27b` model as the default, so the agent is usable out of the box (see [Built-in r5t LLM](#built-in-r5t-llm)).

## Build

```bash
# Build locally
./extensions/pi/build.sh

# Build and push
./extensions/pi/build.sh push <registry>
```

### Environment Variables

| Variable         | Default                | Description          |
| ---------------- | ---------------------- | -------------------- |
| `DEV_REGISTRY`   | `localhost:5000`       | Target registry      |
| `DEV_IMAGE_NAME` | `dev-workspace-pi`     | Image name           |
| `DEV_VERSION`    | git tag                | Image tag            |
| `DEV_BASE_IMAGE` | auto                   | Base image reference |

## Usage in Devfile

Replace the `tools` container image:

```yaml
components:
  - name: tools
    container:
      image: <registry>/dev-workspace-pi:<tag>
```

## Quick Start

```bash
# No API key needed: the r5t provider is baked in as the default
pi

# Non-interactive (print) mode
pi -p "Summarize the changes in this repo"

# Use a different LLM instead (e.g. Anthropic subscription via /login,
# or set ANTHROPIC_API_KEY and select its model with /model or --model)
```

## Built-in r5t LLM

`~/.pi/agent/models.json` registers a provider named `r5t`:

- **Endpoint**: `https://llm.r5t.io/v1/chat/completions` (OpenAI-compatible, **no auth required** — the config carries a dummy `apiKey` that the server ignores; pi only requires *some* key for a provider's models to appear)
- **Model**: `qwen3.8-27b` (Qwen 3.8 27B served by vLLM 0.27), 150k token context window, 32k max output tokens
- **Thinking**: the model is a reasoning model. The vLLM deployment accepts `reasoning_effort` values `none`, `low`, `medium`, and `xhigh` (default). Pi's thinking levels map onto that set:

  | Pi level    | Sent to server     | Meaning                          |
  | ----------- | ------------------ | -------------------------------- |
  | `off`      | `none`             | thinking disabled                |
  | `low`      | `low`              | minimal reasoning                |
  | `medium`   | `medium`           | moderate reasoning (default)     |
  | `xhigh`    | `xhigh`            | maximum reasoning                |
  | others     | (clamped)          | `minimal`→`low`, `high`→`xhigh`, `max`→`xhigh` |

`~/.pi/agent/settings.json` sets `defaultProvider: r5t`, `defaultModel: qwen3.8-27b`, and `defaultThinkingLevel: medium`, so a bare `pi` run uses thinking at moderate effort. Override per run:

```bash
pi --thinking off            # disable thinking for this run
pi --thinking xhigh         # maximum reasoning
pi --model qwen3.8-27b:low  # model + thinking level in one flag
pi --list-models            # list registered models
```

To point pi at a different gateway, replace `~/.pi/agent/models.json` (the schema is documented in pi's `docs/models.md`) or use `/model` with a provider that has a real credential configured.

## IDE Integration

Pi is a terminal agent. From an IDE, run it in a terminal pane, or integrate it programmatically:

- **RPC mode** (`pi --mode rpc`) — process integration over stdio for editor plugins
- **SDK** (`@earendil-works/pi-coding-agent/client`) — embed Pi in your own tools

## Configuration

Pi uses `~/.pi/agent/` for global configuration (pre-created for the workspace user):

- Settings: `~/.pi/agent/settings.json` (pre-filled with the r5t defaults)
- Custom providers: `~/.pi/agent/models.json` (pre-filled with the r5t provider)
- Project trust decisions: `~/.pi/agent/trust.json`
- Project-local settings: `.pi/settings.json` in each repo

First run prompts to trust project folders that carry project-local settings or extensions.

### Network and telemetry

Pi contacts `https://pi.dev` at startup for an update check and sends an anonymous install/update version ping. In air-gapped or privacy-sensitive environments:

```bash
export PI_OFFLINE=1            # disable all startup network operations
# or individually:
export PI_SKIP_VERSION_CHECK=1 # disable the latest-version check
export PI_TELEMETRY=0          # disable install/update telemetry
```

These can also be set in the Devfile `env` block or `~/.pi/agent/settings.json` (`enableInstallTelemetry: false`).

### Self-update

```bash
pi update --self   # update the npm installation
pi update --models # refresh the built-in provider model catalogs (does not touch the user-level r5t entry in models.json)
```
