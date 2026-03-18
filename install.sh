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
  info "Directory $INSTALL_DIR already exists."
  if [[ -t 0 ]]; then
    read -r -p "[clara] Overwrite? [y/N]: " yn
    case "$yn" in
      [yY]*) rm -rf "$INSTALL_DIR" ;;
      *)     die "Aborting. Remove or rename $INSTALL_DIR and try again." ;;
    esac
  else
    die "Directory $INSTALL_DIR already exists. Remove it or set CLARA_INSTALL_DIR."
  fi
fi

# ── Extract embedded payload ─────────────────────────────────────────────────

info "Creating $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

PAYLOAD_LINE=$(awk '/^__PAYLOAD__$/{print NR + 1; exit}' "$SELF")
tail -n +"$PAYLOAD_LINE" "$SELF" | base64 -d | tar -xzf - -C "$INSTALL_DIR"

chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/output"

# ── Pull Docker image ───────────────────────────────────────────────────────

if [[ "${CLARA_SKIP_DOCKER:-}" != "1" ]]; then
  info "Pulling Docker image: $IMAGE ..."
  if docker pull "$IMAGE"; then
    info "Image pulled successfully."
  else
    info "WARNING: Could not pull image. You may need to build it locally with ./build.sh"
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
