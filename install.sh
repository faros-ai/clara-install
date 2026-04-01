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
