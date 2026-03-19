#!/usr/bin/env bash
# =============================================================================
# Clara Timemachine — Installer
# =============================================================================
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/faros-ai/clara-install/main/install.sh \
#     -o /tmp/clara-install.sh && bash /tmp/clara-install.sh
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
  echo "  curl -fsSL https://raw.githubusercontent.com/faros-ai/clara-install/main/install.sh \\"
  echo "    -o /tmp/clara-install.sh"
  echo "  bash /tmp/clara-install.sh"
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
  read -r -p "[clara] Run the setup wizard now? [Y/n]: " run_setup
  case "$run_setup" in
    [nN]*) ;;
    *)
      cd "$INSTALL_DIR"
      bash setup.sh
      exit 0
      ;;
  esac
fi

info "To configure, run:"
info "  cd $INSTALL_DIR && ./setup.sh"

exit 0
# Everything below this line is the embedded payload — do not edit.
__PAYLOAD__
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
