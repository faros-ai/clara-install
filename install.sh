#!/usr/bin/env bash
# =============================================================================
# Clara Timemachine — Installer
# =============================================================================
# Usage:
#   curl -fsSL -H "Authorization: token $CLARA_TOKEN" \
#     https://raw.githubusercontent.com/faros-ai/clara-install/main/install.sh \
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
  echo "  curl -fsSL -H 'Authorization: token \$CLARA_TOKEN' \\"
  echo "    https://raw.githubusercontent.com/faros-ai/clara-install/main/install.sh \\"
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
