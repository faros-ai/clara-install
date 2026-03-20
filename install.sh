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
