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

CI: `build.yml` builds U-Boot on every push (the Dockerfile checks the prefix, OSIP header
and layout) and uploads it; `release.yml` runs on `v*` tags and attaches `u-boot.bin`,
`u-boot-edison.img`, `SHA256SUMS` and `VERSION` to the release.

## Layout

| Path | Purpose |
|---|---|
| `docker/xfstk.Dockerfile` | Builds `xfstk-dldr-solo` from [edison-fw/xFSTK](https://github.com/edison-fw/xFSTK) v1.8.6 (pinned commit) on Ubuntu 24.04 |
| `patches/` | Patches applied to xFSTK: 10 ms device polling and a longer timeout, so the sub-second DnX window isn't missed |
| `docker/uboot.Dockerfile` | Builds mainline U-Boot v2026.10 `edison_defconfig` (pinned commit); checks the 4 KiB zero prefix |
| `scripts/mkosip.py` | Writes the OSIP header that mainline's image lacks |
| `blobs.lock` | URLs and SHA256 checksums of the Intel DnX/IFWI blobs |
| `scripts/fetch-blobs.sh` | Downloads the blobs into `blobs/` and refuses to continue on a mismatch |
| `scripts/build.sh`, `scripts/recover.sh` | Build, then recover |

## Releasing

1. Make sure `main` is green. A U-Boot change needs a hardware test first: recover or
   flash a real board with the CI build of the commit you'll tag.
2. Tag and push: `git tag -a v0.2.0 -m "edison-recovery v0.2.0"` then
   `git push origin v0.2.0`.
3. The release workflow does the rest. If U-Boot changed, bump the pin in edison-image.

## Conventions

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org)
  (`feat: ...`, `fix(uboot): ...`, `docs: ...`).
- **Python:** formatted and linted with Ruff (settings in `pyproject.toml`). Standard
  library only unless a dependency clearly pays for itself; then manage it with uv.
- **Shell:** clean under `shellcheck`.
- **Pin every external input** (U-Boot and xFSTK commits, base images, blob checksums).
  **Never commit the Intel blobs:** `blobs.lock` holds their URLs and checksums.
- **Workflow actions:** pin to the commit SHA of the latest release, with the version in a
  comment (`actions/checkout@<sha> # v7.0.1`). Actions published as immutable releases use
  their exact tag instead (`astral-sh/setup-uv@v10.3.0`). Dependabot opens one grouped pull
  request a month with updates.
- **Hardware changes need a hardware test.** Note what you tested on a real board in the
  pull request; findings go in
  [edison-docs](https://github.com/edison-revival/edison-docs).
