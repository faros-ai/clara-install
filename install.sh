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
