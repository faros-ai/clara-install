#!/usr/bin/env bash
# =============================================================================
# Clara Timemachine — Installer
# =============================================================================
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/faros-ai/clara-install/main/install.sh -o install.sh && bash install.sh
#
# This script is self-contained. It creates a clara-timemachine/ directory
# with everything needed to run Clara pipelines via Docker.
# =============================================================================
set -euo pipefail

INSTALL_DIR="${CLARA_INSTALL_DIR:-./clara-timemachine}"
IMAGE="${CLARA_IMAGE:-farosai/clara:latest}"

info()  { echo "[clara] $*"; }
error() { echo "[clara] ERROR: $*" >&2; }
die()   { error "$@"; exit 1; }

# ── Self-save when piped ─────────────────────────────────────────────────────
# When run via `curl ... | bash`, $0 is not a real file and we can't seek back
# to read the embedded payload. Save stdin to a temp file and re-exec.
SELF="$0"
if [[ ! -f "$SELF" ]] || ! grep -q '^__PAYLOAD__$' "$SELF" 2>/dev/null; then
  TMPSCRIPT=$(mktemp /tmp/clara-install.XXXXXX.sh)
  trap 'rm -f "$TMPSCRIPT"' EXIT
  # If piped, stdin has the script content — but bash already consumed it.
  # The trick: curl pipes to bash, but we need the file. Re-download or
  # use the already-running script. Since bash reads the entire script into
  # memory before executing, we can't recover it from stdin.
  #
  # Instead: tell the user to save-then-run. This is what most installers do
  # when they have an embedded payload.
  info "Clara Timemachine Installer"
  echo ""
  info "This installer contains embedded data and needs to be saved to a file first."
  echo ""
  echo "  curl -fsSL https://raw.githubusercontent.com/faros-ai/clara-install/main/install.sh -o install.sh"
  echo "  bash install.sh"
  echo ""
  exit 1
fi

# ── Preflight ────────────────────────────────────────────────────────────────

info "Clara Timemachine Installer"
echo ""

for cmd in base64 tar; do
  command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is required but not installed."
done

if [[ "${CLARA_SKIP_DOCKER:-}" != "1" ]]; then
  command -v docker >/dev/null 2>&1 || die "'docker' is required but not installed. Install: https://docs.docker.com/get-docker/"
  if ! docker info >/dev/null 2>&1; then
    die "Docker is not running. Please start Docker and try again."
  fi
fi

if [[ -d "$INSTALL_DIR" ]]; then
  info "Existing installation found at $INSTALL_DIR — updating scripts (keeping .env and output/)."
fi

# ── Extract embedded payload ─────────────────────────────────────────────────

info "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Preserve .env and output/ during update
if [[ -f "$INSTALL_DIR/.env" ]]; then
  cp "$INSTALL_DIR/.env" "$INSTALL_DIR/.env.bak"
fi

PAYLOAD_LINE=$(awk '/^__PAYLOAD__$/{print NR + 1; exit}' "$SELF")
tail -n +"$PAYLOAD_LINE" "$SELF" | base64 -d | tar -xzf - -C "$INSTALL_DIR"

chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/output"

# Restore .env if it was backed up
if [[ -f "$INSTALL_DIR/.env.bak" ]]; then
  mv "$INSTALL_DIR/.env.bak" "$INSTALL_DIR/.env"
  info "Preserved existing .env"
fi

# ── Pull Docker image ───────────────────────────────────────────────────────

if [[ "${CLARA_SKIP_DOCKER:-}" != "1" ]]; then
  # Skip pull if image already exists locally
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    info "Docker image $IMAGE already exists locally. Skipping pull."
  elif docker pull "$IMAGE" 2>/dev/null; then
    info "Image pulled successfully."
  else
    info "Image pull failed (likely requires authentication)."
    if [[ -t 0 ]]; then
      read -r -p "[clara] Do you have Docker Hub credentials? [Y/n]: " has_creds
      case "$has_creds" in
        [nN]*)
          info "Skipping image pull. You will need the image before running pipelines."
          ;;
        *)
          read -r -p "[clara] Docker Hub username: " DOCKER_USER
          read -rs -p "[clara] Docker Hub access token: " DOCKER_TOKEN
          echo ""
          if echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USER" --password-stdin 2>/dev/null; then
            info "Docker login successful. Pulling image..."
            if docker pull "$IMAGE"; then
              info "Image pulled successfully."
            else
              info "WARNING: Pull still failed. Check that you have access to $IMAGE."
            fi
          else
            info "WARNING: Docker login failed. Check your credentials."
          fi
          ;;
      esac
    else
      info "WARNING: Could not pull image. Run: docker login, then: docker pull $IMAGE"
    fi
  fi
else
  info "Skipping Docker pull (CLARA_SKIP_DOCKER=1)."
fi

# ── Launch setup wizard ─────────────────────────────────────────────────────

echo ""
info "Installation complete: $(cd "$INSTALL_DIR" && pwd)"
echo ""

if [[ -t 0 ]]; then
  read -r -p "[clara] Run the setup wizard now? [Y/n]: " run_setup
  case "$run_setup" in
    [nN]*) ;;
    *)
      cd "$INSTALL_DIR"
      bash setup.sh
      exit 0
      ;;
  esac
fi

info "To configure, run:"
info "  cd $INSTALL_DIR && ./setup.sh"

exit 0
# Everything below this line is the embedded payload — do not edit.
__PAYLOAD__
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
