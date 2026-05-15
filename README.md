# swarmfile

**helmfile for Docker Swarm.** A single bash script that reads a `swarmfile.yaml` declaring which stacks to deploy, diffs them against what's running, and applies changes with `docker stack deploy`.

```
$ swarmfile diff

Stack: myapp
  ~ web
    image:    - nginx:1.25
              + nginx:1.27
    replicas: - 2  + 3
  = db
  + worker  (new service)

[swarmfile] Changes detected.
```

---

## Requirements

| Tool | Version | Install |
|------|---------|---------|
| `docker` | 24+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| `yq` (mikefarah) | v4+ | [github.com/mikefarah/yq](https://github.com/mikefarah/yq/releases) |

> The Python `yq` package is **not** compatible. Install the Go binary from mikefarah.

---

## Installation

**One-liner** (installs to `~/.local/bin/swarmfile`):

```sh
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/swarmfile/main/install.sh | sh
```

Override the install directory:

```sh
SWARMFILE_INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/swarmfile/main/install.sh | sh
```

**Manual** (run directly from a clone):

```bash
git clone https://github.com/YOUR_ORG/swarmfile
cd swarmfile
./swarmfile --help
```

---

## swarmfile.yaml

Place a `swarmfile.yaml` in the root of your compose repository:

```yaml
defaults:
  context: prod-swarm          # default Docker context (optional)

stacks:
  - name: myapp
    compose:
      - docker-compose.yml
      - docker-compose.prod.yml
    context: other-swarm       # per-stack context override (optional)
    labels:
      tier: frontend

  - name: monitoring
    compose:
      - monitoring/docker-compose.yml
    labels:
      tier: infra
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `defaults.context` | No | Fallback Docker context for all stacks |
| `stacks[].name` | Yes | Docker stack name |
| `stacks[].compose` | Yes | One or more compose files (merged in order) |
| `stacks[].context` | No | Per-stack Docker context; overrides `defaults.context` |
| `stacks[].labels` | No | Arbitrary key/value labels for `--selector` filtering |

---

## Commands

### `swarmfile diff`

Compares desired state (rendered compose files) against live Docker Swarm services.

```bash
swarmfile diff
swarmfile diff --selector tier=frontend
swarmfile diff --file path/to/swarmfile.yaml
```

- Exits **0** — no changes detected
- Exits **1** — changes detected (useful in CI to gate a deploy step)

Per-service output:
- `~ name` — service has changes (image / replicas / env vars shown)
- `+ name` — new service or new stack
- `- name` — service will be removed on next apply (due to `--prune`)
- `= name` — unchanged

### `swarmfile apply`

Runs diff for each stack, skips unchanged ones, and deploys changed stacks.

```bash
swarmfile apply
swarmfile apply --interactive          # confirm before each deploy
swarmfile apply --selector tier=infra
```

- Unchanged stacks are **skipped** — no unnecessary redeploys.
- `--prune` is always passed, so services removed from compose files are removed from the swarm.
- `--with-registry-auth` is always passed for private registry support.

---

## Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--file FILE` | `-f` | Path to swarmfile.yaml (default: `./swarmfile.yaml`) |
| `--context CTX` | | Override Docker context for all stacks |
| `--selector KEY=VAL` | `-l` | Filter stacks by label |
| `--interactive` | `-i` | Prompt before each deployment (apply only) |
| `--help` | `-h` | Show usage |

---

## How it works

```
swarmfile diff / apply
       │
       ├─ reads swarmfile.yaml  (yq)
       │
       └─ for each stack:
            │
            ├─ docker compose config   →  desired state (temp file)
            │
            ├─ docker stack services   →  current service list
            │   docker service inspect →  current image / replicas / env
            │
            ├─ prints diff
            │
            └─ (apply only) docker stack deploy -c ... --prune
```

All `docker` calls use `docker --context CTX`, so the global Docker context is never mutated.

---

## CI example

```yaml
# GitHub Actions
- name: Check for stack drift
  run: swarmfile diff --selector tier=frontend

- name: Deploy
  run: swarmfile apply --selector tier=frontend
```

`diff` exits 1 when changes exist, letting you gate, notify, or fail a pipeline step.

---

## License

MIT
