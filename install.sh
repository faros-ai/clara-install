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
