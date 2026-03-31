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
