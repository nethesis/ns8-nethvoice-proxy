# Copilot Instructions for ns8-nethvoice-proxy

## Project Overview

This is an NS8 (NethServer 8) module that provides a SIP/RTP proxy allowing multiple NethVoice instances on the same node. It uses Kamailio (SIP proxy) and rtpengine (RTP proxy) as core components, backed by PostgreSQL and Redis.

## Architecture

The module has three distinct layers:

- **`modules/`** — Container images for the four services (kamailio, rtpengine, postgres, redis). Each has its own `Dockerfile`, `Makefile`, and bootstrap script. Built with `buildah` via `build-images.sh`.
- **`imageroot/`** — NS8 module integration layer:
  - `actions/` — Python3 scripts implementing the NS8 action API (configure-module, add-route, add-trunk, etc.). Each action is a directory with numbered executable steps (e.g., `10validate`, `20configure`, `80start_services`) and optional `validate-input.json`/`validate-output.json` JSON Schema files.
  - `events/` — Handlers for NS8 platform events (certificate-changed, support-session).
  - `systemd/user/` — Systemd unit files for all services.
  - `pypkg/` — Shared Python library (e.g., `network.py`) available to action scripts.
  - `bin/` — Helper scripts (kamcmd wrapper, module-dump-state, generate_tls_config).
  - `update-module.d/` — Numbered scripts run during module updates.
- **`ui/`** — Vue 2 admin panel using Carbon Design System (`@carbon/vue`) and `@nethserver/ns8-ui-lib`. Built with Vue CLI.

## Build & Run

### Container images (local development)

```bash
cp .env.template .env   # fill in values
cd modules/<service>     # kamailio, postgres, redis, or rtpengine
make build
make run && make log
```

Start services in order: postgres → redis → rtpengine → kamailio (kamailio needs postgres ready).

### All services via root Makefile (on NS8 node)

```bash
make init       # first-time setup
make run-all    # start all pods with podman
make log        # tail logs
```

`run-kamailio-dev` and `run-rtpengine-dev` targets mount local config files for live editing.

### UI

```bash
cd ui
yarn install
yarn serve     # dev server with hot-reload
yarn build     # production build
yarn lint      # ESLint + Prettier
```

### Full image build (CI-like)

```bash
./build-images.sh   # uses buildah, builds all containers + module image
```

## Testing

Tests use [Robot Framework](https://robotframework.org/) and run against a live NS8 node via SSH.

```bash
# Full suite
./test-module.sh <NODE_ADDR> ghcr.io/nethesis/nethvoice-proxy:latest

# Single test file
robot -v NODE_ADDR:<addr> -v IMAGE_URL:<url> -v SSH_KEYFILE:~/.ssh/id_rsa tests/10_actions/00_configure_module_validate.robot
```

Test structure: `tests/00_*.robot` for add/remove module lifecycle, `tests/10_actions/` for action validation and integration tests.

## Key Conventions

- **Action scripts** are Python3 executables (no `.py` extension) that read JSON from stdin and write JSON to stdout. They use the `agent` module from the NS8 SDK for environment management (`agent.set_env()`, `agent.add_rich_rules()`, etc.).
- **Numbered prefixes** on action steps and update scripts control execution order (e.g., `10validate` runs before `20configure` before `80start_services`).
- **Input/output validation** uses JSON Schema files (`validate-input.json`, `validate-output.json`) co-located with action scripts.
- **Environment configuration** is stored in `~/.config/state/environment` and `~/.config/state/passwords.env` on the NS8 node, managed through `agent.set_env()`.
- **License header**: Python files use `# Copyright (C) <year> Nethesis S.r.l.` and `# SPDX-License-Identifier: GPL-3.0-or-later`.
- **Container networking**: Kamailio and rtpengine use `--network=host`; postgres and redis bind to `127.0.0.1` on configured ports.
