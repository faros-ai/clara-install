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
  cd "$INSTALL_DIR"
  bash setup.sh
  exit 0
fi

info "To configure, run:"
info "  cd $INSTALL_DIR && ./setup.sh"

exit 0
# Everything below this line is the embedded payload — do not edit.
__PAYLOAD__
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
