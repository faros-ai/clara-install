# Clara Timemachine — Customer Installer

This repository contains the self-extracting installer for Clara Timemachine. It is the distribution point for customer deployments.

## For Customers

One-line install:

```bash
curl -fsSL https://raw.githubusercontent.com/faros-ai/clara-install/main/install.sh -o install.sh && bash install.sh
```

The installer will:
1. Create a `clara-timemachine/` directory with all necessary files
2. Pull the Clara Docker image (prompts for Docker Hub credentials if needed)
3. Launch an interactive setup wizard to configure credentials and generate a pipeline

After setup, run your pipeline:

```bash
cd clara-timemachine
./run.sh pipelines/<your-pipeline>.yaml
```

## For Faros Engineers

This repo is updated automatically by `installer/release.sh` in the [clara](https://github.com/faros-ai/clara) repo.

To publish an update:

```bash
cd /path/to/clara/installer
./release.sh           # auto-increment version
./release.sh v1.2.0    # specific version
```

This regenerates `install.sh` from the current `installer/` contents, pushes it here, and creates a tagged release.

### What's inside install.sh

The installer is a bash script with an embedded base64-encoded tarball containing:
- `setup.sh` — interactive setup wizard
- `run.sh` — Docker run wrapper (with proxy support)
- `.env.example` — documented environment variable template
- `pipelines/` — example pipeline YAML templates for Claude and Codex
- `build.sh` — local Docker image build helper
- `README.md` — customer-facing documentation

No Clara source code is included.
