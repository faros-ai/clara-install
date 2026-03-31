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
