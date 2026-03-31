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
