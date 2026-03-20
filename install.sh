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
