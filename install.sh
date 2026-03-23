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
