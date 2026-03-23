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
