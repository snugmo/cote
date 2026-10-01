# PiG (Pi in Go) Extension

Installs [PiG](https://pi-in-go.dev/) ([MichaelKinsy/PiG](https://github.com/MichaelKinsy/PiG)) on top of the dev-workspace base image. PiG is a faithful Go implementation of the [Pi coding agent](https://pi.dev) — the same small core, re-implemented as a single native binary, tracking Pi's behavior with explicit parity evidence. It starts in ~21 ms (vs ~300 ms for Pi) with about a quarter of the peak memory, and no Node.js runtime is required unless you run TypeScript extensions.

PiG runs in four modes: interactive TUI, print/JSON, RPC for process integration, and a Go SDK for embedding. Extend it with Go, Rust, Python, or Node extensions (Pi's own TypeScript/JavaScript extensions run unchanged), skills, prompt templates, themes, packages, and Piglets.

Installed from the official npm package (`@pi-in-go/pig`) with `--ignore-scripts`. The package is a thin Node launcher whose `optionalDependencies` pull in the native `pig` binary for the build platform, so npm selects the correct architecture automatically and no lifecycle scripts are needed (upstream publishes the package without a `postinstall`). npm verifies the published tarball integrity (sha512) against the registry. PiG 0.3.1 tracks Pi 0.87.1 (`pig --version` prints `0.3.1+0.87.1`).

The image bakes in the **r5t** LLM provider (the org's keyless OpenAI-compatible gateway at `https://llm.r5t.io/v1`) with the `qwen3.8-27b` model as the default, so the agent is usable out of the box (see [Built-in r5t LLM](#built-in-r5t-llm)).

## Build

```bash
# Build locally
./extensions/pi-in-go/build.sh

# Build and push
./extensions/pi-in-go/build.sh push <registry>
```

### Environment Variables

| Variable         | Default                  | Description          |
| ---------------- | ------------------------ | -------------------- |
| `DEV_REGISTRY`   | `localhost:5000`         | Target registry      |
| `DEV_IMAGE_NAME` | `dev-workspace-pi-in-go` | Image name           |
| `DEV_VERSION`    | git tag                  | Image tag            |
| `DEV_BASE_IMAGE` | auto                     | Base image reference |

## Usage in Devfile

Replace the `tools` container image:

```yaml
components:
  - name: tools
    container:
      image: <registry>/dev-workspace-pi-in-go:<tag>
```

## Quick Start

```bash
# No API key needed: the r5t provider is baked in as the default
pig

# Non-interactive (print) mode
pig -p "Summarize the changes in this repo"

# Use a different LLM instead (e.g. Anthropic or OpenAI via /login,
# or set ANTHROPIC_API_KEY / OPENAI_API_KEY and select its model with /model
# or --model)
```

## Built-in r5t LLM

`~/.pig/agent/models.json` registers a provider named `r5t`:

- **Endpoint**: `https://llm.r5t.io/v1` (OpenAI-compatible, **no auth required** — the config carries a dummy `apiKey` that the server ignores; PiG only requires *some* key for a provider's models to appear)
- **Model**: `qwen3.8-27b` (Qwen 3.8 27B served by vLLM 0.27), 150k token context window, 32k max output tokens
- **Reasoning**: the model is a reasoning model. Verified end-to-end, the r5t deployment accepts PiG's thinking levels `off`, `medium`, and `xhigh` (and the full `off → minimal → low → medium → high → xhigh → max` set cycles on the model)

`~/.pig/agent/settings.json` sets `defaultProvider: r5t`, `defaultModel: qwen3.8-27b`, and `defaultThinkingLevel: medium`, so a bare `pig` run uses thinking at moderate effort. Override per run:

```bash
pig --thinking off            # disable thinking for this run
pig --thinking xhigh         # maximum reasoning
pig --model qwen3.8-27b:low  # model + thinking level in one flag
pig --list-models            # list registered models
```

To point pig at a different gateway, edit `~/.pig/agent/models.json` (an OpenAI-compatible endpoint needs `baseUrl`, `api: "openai-completions"`, and an `apiKey`) or use `/model` with a standard provider that has a real credential configured.

## IDE Integration

PiG is a terminal agent. From an IDE, run it in a terminal pane, or integrate it programmatically:

- **RPC mode** (`pig --mode rpc`) — JSON protocol over stdio for process-based editor plugins
- **Go SDK** (`github.com/MichaelKinsy/PiG`) — embed PiG in your own Go tools; Piglets can fuse extensions into a standalone native binary

PiG also exposes `pig auth`, `pig status`, and `pig verify` (verify the binary, downloads, and installed packages) for operational checks.

## Configuration

PiG keeps all of its state under `~/.pig` (pre-created for the workspace user) and never reads or writes `~/.pi`:

- Settings: `~/.pig/agent/settings.json` (pre-filled with the r5t defaults)
- Custom endpoints and models: `~/.pig/agent/models.json` (pre-filled with the r5t provider)
- Stored API keys and OAuth tokens: `~/.pig/agent/auth.json`
- Project trust decisions: `~/.pig/agent/trust.json`
- Extensions / skills / prompts / themes: `~/.pig/agent/extensions/`, `skills/`, `prompts/`, `themes/`
- Project-local config: `.pig/` in each repo (read only from the working directory, never parent dirs)

First run in a project prompts to trust it before reading `.pig/settings.json` and project extensions. Install packages or extensions with `pig install <source>` (user scope) or `pig install <source> -l` (project scope); write a new extension with `pig extension init <path>`. Edit an extension while PiG runs and use `/reload` to pick it up without restarting.

### Network and telemetry

PiG contacts its update endpoint at startup and can fetch provider model catalogs in the background. In air-gapped or privacy-sensitive environments:

```bash
export PIG_OFFLINE=1     # disable startup network operations (update check, catalog fetch)
# PI_OFFLINE=1 also works
```

These can also be set in the Devfile `env` block.

### Self-update

```bash
pig update self         # update the pig installation
pig update              # update installed packages and model catalogs
```
