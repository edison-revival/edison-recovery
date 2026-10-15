# Contributing to edison-recovery

## Build and test

`scripts/build.sh` builds the xFSTK container and mainline U-Boot (needs Docker on Linux).
`scripts/recover.sh` needs a real board in DnX mode; see the README.

`.github/workflows/test.yml` checks that `mkosip.py` produces the known-good OSIP header
(byte-identical to meta-intel-edison's, booted on hardware) and runs Ruff and
`shellcheck`. Run them locally before pushing:

```
uv run --no-project python -m unittest discover -s tests
```

```
uvx ruff format . && uvx ruff check .
```

```
shellcheck scripts/*.sh
```

[edison-image](https://github.com/edison-revival/edison-image) builds U-Boot from this
repo at a pinned commit. After changing the U-Boot build, bump that pin there.

## Conventions

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org)
  (`feat: ...`, `fix(uboot): ...`, `docs: ...`).
- **Python:** formatted and linted with Ruff (settings in `pyproject.toml`). Standard
  library only unless a dependency clearly pays for itself; then manage it with uv.
- **Shell:** clean under `shellcheck`.
- **Pin every external input** (U-Boot and xFSTK commits, base images, blob checksums).
  **Never commit the Intel blobs:** `blobs.lock` holds their URLs and checksums.
- **Workflow actions:** use the latest major tag (`actions/checkout@v7`), except actions
  published as immutable releases, which use the exact version (`astral-sh/setup-uv@v10.3.0`).
  Dependabot proposes updates.
- **Hardware changes need a hardware test.** Note what you tested on a real board in the
  pull request; findings go in
  [edison-docs](https://github.com/edison-revival/edison-docs).
