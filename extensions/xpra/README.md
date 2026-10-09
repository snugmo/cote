# Xpra Remote X11 Desktop Extension

Installs [Xpra](https://xpra.org) ("screen for X") on top of the cote base image, together with the X11 dependencies and the [xpra-html5](https://github.com/Xpra-org/xpra-html5) browser client. A headless container can serve a full X11 desktop (Xdummy/Xvfb + openbox + xterm) over a TCP/WebSocket port: point any browser at the port for the HTML5 client, or attach with a native `xpra` client.

What the image adds (all inside the container build, base image untouched):

- **`xpra` 6.5.x** (Fedora package) — the Xpra server and client. Its hard deps pull in the headless-capable Xorg (`xorg-x11-server-Xorg` + `xorg-x11-drv-dummy`, the Xdummy backend), `xorg-x11-xauth`, `xrandr`, `python3-lz4`, `python3-pillow`, GStreamer plugins, and pipewire.
- **X11 desktop support** — `xorg-x11-server-Xvfb` (alternative headless X server), `xset`, `xinput`, core bitmap fonts (`xorg-x11-fonts-Type1`, `xorg-x11-fonts-misc`), `default-fonts-core` (Noto via fontconfig), plus a broader font set (`langpacks-fonts-en`, `liberation-fonts-all`, `adwaita-fonts-all`, `jetbrains-mono-fonts-all`, `cascadia-fonts-all`, Cantarell fixed + variable, Geist UI/mono variable, Inter variable, Linux Libertine serif, emoji), `openbox` (window manager), `xterm` (terminal), and `kitty` (GPU-accelerated terminal).
- **`xpra-html5`** (version 22, pinned git commit) — the browser client, installed from the upstream git repo into `/usr/share/xpra/www` (the xpra server's built-in web server serves it automatically). Xpra is published as a git project, not on PyPI, so the client is built from source at a pinned commit (`ARG HTML5_CLIENT_COMMIT`); gzip and brotli compressed assets are generated during the build.
- **`xpra-desktop`** launcher in `/usr/local/bin` — starts a daemonized desktop session (Xdummy by default, `--xvfb` for Xvfb) running openbox and xterm, served on a TCP/WebSocket port with the HTML5 client.
- **`xpra-entrypoint`** in `/usr/local/bin` — the image's `CMD` (see [Container Entrypoint](#container-entrypoint)): an empty X11 desktop by default, or a desktop + your command when arguments are passed.
- `ENV XDG_RUNTIME_DIR=/tmp/xdg-runtime-1000` so sessions and their runtime files persist across `exec` shells in the container.

## Build

```bash
# Build locally
./extensions/xpra/build.sh

# Build and push
./extensions/xpra/build.sh push <registry>
```

### Environment Variables

| Variable         | Default                  | Description          |
| ---------------- | ------------------------ | -------------------- |
| `DEV_REGISTRY`   | `ghcr.io/snugmo`          | Target registry      |
| `DEV_IMAGE_NAME` | `dev-workspace-xpra`     | Image name           |
| `DEV_VERSION`    | git tag                  | Image tag            |
| `DEV_BASE_IMAGE` | auto                     | Base image reference |

## Usage in Devfile

Replace the `tools` container image:

```yaml
components:
  - name: tools
    container:
      image: <registry>/dev-workspace-xpra:<tag>
```

## Container Entrypoint

The image's `CMD` is `/usr/local/bin/xpra-entrypoint` (the base image's `catatonit` entrypoint stays in place for zombie reaping):

```bash
# No arguments: an empty X11 desktop (openbox) served on port 10000;
# the container stays alive until it is stopped.
podman run -it --rm -p 10000:10000 dev-workspace-xpra:latest
#   browser:  http://localhost:10000/
#   native:   xpra attach tcp://<host>:10000

# With arguments: the same desktop is started as a daemon and the
# command is run inside it as the container's foreground process —
# its stdout/stderr go to the container logs (`pod logs`) and its
# exit code becomes the container's. The container (and the session)
# exits when the command exits.
podman run -it --rm -p 10000:10000 dev-workspace-xpra:latest xterm
```

Escape hatch: a first argument of `xpra` runs the raw Xpra CLI:

```bash
podman run --rm dev-workspace-xpra:latest -- xpra list-sessions
```

Environment variables (same names as `xpra-desktop`):

| Env var        | Default | Description                                |
| -------------- | ------- | ------------------------------------------ |
| `XPRA_PORT`    | `10000` | TCP/WebSocket port the session is served on |
| `XPRA_WIDTH`   | `1280`  | Desktop width                              |
| `XPRA_HEIGHT`  | `720`   | Desktop height                             |
| `XPRA_DPI`     | `96`    | Dots per inch                              |
| `XPRA_SESSION` | `:10`   | Display name for the desktop session       |
| `XPRA_XVFB`    | `0`     | `1`/`true` to use Xvfb instead of the default Xdummy |

## Quick Start

```bash
# Start a desktop on :10, served on port 10000 (daemonized):
xpra-desktop

# Then, in a browser:
#   http://<host>:10000/
# or with a native xpra client:
xpra attach tcp://<host>:10000

# Manage the session:
xpra list-sessions
xpra screenshot /tmp/shot.png :10
xpra stop :10
```

`xpra-desktop` options (or env vars):

| Flag             | Env var        | Default | Description                                |
| ---------------- | -------------- | ------- | ------------------------------------------ |
| first positional | `XPRA_PORT`    | `10000` | TCP/WebSocket port the session is served on |
| `--width`        | `XPRA_WIDTH`   | `1280`  | Desktop width                              |
| `--height`       | `XPRA_HEIGHT`  | `720`   | Desktop height                             |
| `--dpi`          | `XPRA_DPI`     | `96`    | Dots per inch                              |
| `--session`      | `XPRA_SESSION` | `:10`   | Display for the desktop session            |
| `--xvfb`         | —              | —       | Use Xvfb instead of the default Xdummy     |
| `--foreground`   | —              | —       | Don't daemonize (for debugging)            |

## Notes

- **Xdummy vs Xvfb**: Xpra's default headless backend is Xdummy (Xorg with the dummy video driver), which supports arbitrary DPI and dynamic monitors; `--xvfb` selects plain Xvfb instead.
- **Desktop vs seamless**: the launcher uses `xpra start-desktop`, which serves the whole virtual display as one desktop. A plain `xpra start <name>` would start a *seamless* session with separate per-app windows instead — either can be served with the same HTML5 client by adding `--bind-tcp` and `--html=on`.
- **Security**: `--bind-tcp` serves the session over *unencrypted* TCP/WebSocket and the HTML5 client has no built-in authentication (a password can be set with `--pass=...`). Keep the port on a trusted network, or front it with a TLS proxy / ingress before exposing it.
- **Logs**: session logs go to `$XDG_RUNTIME_DIR/xpra/<display>/server.log` (and `Xorg.log` for the X server).
