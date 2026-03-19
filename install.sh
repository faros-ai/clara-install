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
  # Try pulling; if it fails, offer to log in to Docker Hub
  info "Pulling Docker image: $IMAGE ..."
  if docker pull "$IMAGE" 2>/dev/null; then
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
H4sIAGxNvGkAA+19a3PbSJJg70Zc3C33897nalo7LarFNyna6mFv0xJts1syNaTcPR6Pl4JISMKYBNgAaJlta2Puy/2AjbmIi7iP94fuN8wvucysBwogSFG2SNsyKtwtAqh3PiozKysr18t9tepUKBRq1Sqjvzv8b6FU4X/57zIrVovVWqGyUyqVWKFYLJdKX7HCynsGaeL5hgtdcR17YT7Idna24DsfClN/P5f0X/77f/3qH7/66tDos3aX/ZGJhO+++if4rwT//Qr/4fP/Xa7KxvFxR/zEEv8b/vvnSJZ/CN7/S98Z5YzxeGjmxq7z2rQNu29+9Q//+NX/+28b//kv/+ef/tctDDJJ89KR8eaJaQxMN9+fuK5p+wPLve02rqX/YiFC/9VCrfIVe3PbHYlLXzj9lwts5Fsjs16s1coPKvcL1UKuVihV7wMQqqlqjR20HjY6e09aPzdzbwzfd3Nx5Fpv/KHVKDTOX726+OV070/PUpUHrAuFDp4vKqTReOpjz8OXmnL51bdxHf0jvUTW/+JO4StWXX3Xvnj6z+VzPc/0J+Ocd7GqNm4u/5ULtXIi/60lJfLfF51y+UACXBUfuLn8B3+Lify3jjRH/qsUd0AJT+S/O59yK6P6IC2m/3KtulOL0H+pVigm6/860r2v8xPPzZ9adt60X7NTw7tI3WP120xQ397QcA12DHxmZPQvLNtkf//r31jL9k3X6PvWa5N1EQvZL9ZvhjuAAs8849zcZQF23nqnoGKWNScOG1tj88ywhqlU8+nPvUetg2Y9nYO5SKegzb//7a/wjz0xh2PT9cTj5/4vlRq7lu33LmjZ38ywtynGzP6Fw9Jp9evvf/sfd+xfMDbGNop3e6RXEsaeb47nQphwe6Mo0JpKGd4rkX3o9I0hg+V6NPbraZgw9tpwe7YBskJ6o5RmA6CayRA/vS3vZq/SzDP7rknPFXxWVbw2hhMTnqwz9uIFy9osvSHKptnLl98x/8K0g3b4D/ZC5nmZ/o6dWap4eoM3kwZ2wNLyt6wmhaqLC2jNskCt2TGT9e2ytOpHaCaGnqkXmleGekAPOD76sZuVXaSxmvASiqo5+nP6zxuU789pmlho0vHM5eYWcngX1pnPSiqvM/Ytx/bqm+mNH9IZ9dpS0BSdxrJnjsssZuFEv/1aFHzxw8srmMmBo00AkMHmpsW+ZcVMJsM23sqsG9ZLGtLAsU3VEpSw+vh4eWENTea7E1NVp09eE5m6yM1eFLMbb+9pXXiJk6qqCoDKXwFQ/4P9+4tC9sHLbzcAqOx3v2Obm7Ky7+usiG/E4+/rLFw3y2Q0LIiHSDDGzU1RTxaH//Lqz4QPfDT+xOWVENjldLVsqNAaiPZz7GhoGp7JTBqwwezJ6BR+nJr+pQkIXWSGPYj0MKdmlVNab2q/F7HZGnVN7R4sqL5GIIq4kEKmGo2JrPX0i+d5G+kKsV97O80/VdTGKzds79J0U7HkwTZESQSpysh/YD/5rwiV9HHG0hv8WxpwlOb3xfT5y63MDMCg7999RxngYxxEbZHB9Iw+Tims2r0hSBehScUXNKUBC/oNKsHX2txwoEdYDc+D03gvvRVmMpDl3DXHLPvrozcqZ3pDihBpVvo+PzBf5+3JcBjXhCJbXvL77/XCqRAaavB4ZU5xarHMv/5rfetKjOlr2ReW/veNt5Dpqn5NZ5boATR7hSLQs/HA8E0GPMUYDADPoXrkLSgisU3Q5dxL1/JNj5lvLM+37HPOJjMEDBCyQrDg/S+mFSstiRG8V/89E3DSyp0ar2AleCdL5rbeiV+CUV+9S89O7ohlz5A/ytdXWE1oRRCzE65q7jzhaM/njDZAvLPQqEIIRTNw/fDZO+aDsMqyRfjVn4AMO6hDvaUse/eOmLLqEfIXx+255mTZZYfhIHiny2l2ZgyHp0b/lVrQtQW+GlrgJeRx9sRPyLQppgRGIupNZ7SpwNVJ5o5MRWhB22WbEw/RKoxf7Ay+EhJmOETjuL0sInl7mKRggoJlUyuKv+Xg04HAwalBCE1cUQGtpU/MnW2aoNcAdwMqn9gMdEV7YAyB0WdWrjKAZOHYZ9b5xDV755Z/MTkVwA7kP5Z+bPlPJqes0e+bnhdIgA2GWo1jI6enT8x3XgGnsjyYql8nlgsE5jusjyOBN2PHs3zHtUwvF9QBahJNpcI11dqF4/lsc+xivVwqQMGE9xENQtvIU/jqOXUmLnv8pEllEAaZNHvcOn7y7GHvSbt7HPqdDmrQeyF/7cFSBezKEEMxAIEufH/s7ebzG2+1eq5QtUTk8PKUE2Bom+bAY9/gQL9hXt8Zm5llxknFVX+P2z81n4Yf0mklqSr5SS5DekZOBiERTW9CB0uOIzSh8IJuhFsmyQMHJJZJWNYYL5wWb1EpTmuTlA56SI8x2UTPIyOZl7E7m/NKx2DQ+m3fi8HgBn5geyKjgVSnwZzMC95kPHZcH5D4EnDWGSCv4PXl2HNnQtSpWmKI0oB/p45/EcXmZ91mb++g8Wy/WbflY3u/+Ud4QhGGBHmW/uXCApKnBja9DLu0gDkDHjNAjX9Ls8bj5tPj3t6Tdmuvyf5MwMJuTgYmDGKAzQ9BvJEf4M2b8KuH0C+mF0BpkvJRF4UcpbeipKnZdjL6kKZSqNKbzYhtn2Cs04jsFUp6dd/NFiJ5TJOjguwzQik1oQNa7/yR67y2BiAohrQ2epBQeOJcAl7TxAsWxisAEPAWe0ed9s+t/WZHzCyMex8oqO+zhu1fuM7Y6rPGUYttetZoPDSBZaFp6i8T+AH4gl9g5cqkg9KN3xB9Gi32yJnYA3eqf/qlyx6aA9eBhYN3Uyc1bWR8QAKIkX4qOM7paXork5JwCPOj8IBwwWWNp8dPOu2j1l4PXvV+aj6PeRNmEjyFmdRMmRCnEtoWX1F4wzGsSnV4yX7G9UoopKJByV9iehfXZVVQ4HUcKLWpVdUL8CCC9xCRH7WfPd3vYCPF9BxAiOpgCjxY2EDH5GJF0CdRR6/T7LafdYBDLPiUNqzsGVZouNOs72cnXhb0Tr+UXjQT0VrCUzLz9ZpxxIBJVjGLVtEvN0GvSNkPQ7Mb9P59kG2mr4sGEod8GrNYBu8eNvc77b2fFuEdVuma57g2MvgN8H3caj/Vf6YF9mSLceij8tFggqcFzQmmi8Bo7fNWG3t7zW4Xh91r7ce8iZvsUB9C2WVXwi8X9IhXrXWM96rb3Os0j7Vq5ry9tnczRWQPZz9EoU7rImkf0cURV88l1kZasN9rVWyPTbvRwlURm5q/KPJ877Mi8pJx6x6XWqh/YsUL9SFmwQt6MX+103pKQG4fNZ82WoqkI4/Xc6FwgQ9jPdf0bXl2E+3UTDfnrmoCHPOFBS0XtDcYO4BnQCp/etZp9kQjzaf7R+3W0+P4tzHkEZeNyCP2wzI9C5i3XoVadeJeLrHgxBT7QJFm+T7fYK2J7eac7sfymhBT4NwD1GPQ+Mmgcgb6uC85QqfZ6Laftp4+Duh66FxCcyNzYE1G8OPCOr9Ip0I9jBRNK9oOXil7VKDkDQzf6HHJKEbT24evrEtfI3pZoHmZMNmkcPk4+1gfaHYjbhQCHrffOG70hPgk9KlHhut4nK2dmX7/wvTYUYeXNCa+MwKNsm8MhwFfSz90cZKeo2WifWkz6tbmeGiAOPcjjO0AhgXMEU2hWEs+k9aZutYDztZV+1FDss4pg0xSu9eFMTWCZ52DNHvU6LS7BH14jDylpcVj7DqDnDG2cmdYOGdYEfiFiiH0wi8W9kLYG4IS3OQQfY6ie5gSI7kjRBgQ4KxdCm1JvDMERI5OijC5AHhdX6N9U2QYM0HKzhF9FYPgfMvHGMZg9+HBGZAVO3aN/ivEr02ZVzM1iTw+5kG7+th0rRGaP0am71p9L8eOL0zyWyDEuXRcyHZp+RfOxGeWH2ecm9pI/9L2oTcAnQCK6TaPnx31Dg8eHbR/YWk7raGy/ileRNFRmFcdhzmiUW04XCviNfeafzxqdlqHaM942jhsznud7qOtp4fW3glZgbz85CzKluLLIvDmfJnfXTlHQHQt1dfjTmPvJ2BuQCStuHexvdEzaF0JvZ7fD/jt4nwBwrhMt6n6DvNeWeNMTOe6zY4+lTMfqDXNHD8vXwTci4amSiyoLSDR2WGODc8DfB7Mjuao0e3+0u7sz/8wu7DO7acsE9dP9Y0qoZ0CLrCHzJGDgcXplnVN97UFMnYsKc8hwMfmyLItYk3Ix2gV+3ViDC1/ioZnVyfKx83D1tNWLFHyT/FEGTFVBw2SZMJLKpkk8hidyZDBmGqKEFy4PNl4w2/UJM7ORReEz8euxTm6OcLNLdvxrTNYj4m+1UR0QXB83EEFMmYq5MdlJkO1qKZDllYzMPMiOiWRVRE3o3jfjcEAqVOr81GnfdhrHjZaB7Hv0raTdc3xcPrD7CItJ132ODLt0V6maToi7+YUCXoQKqW9VgvbuWmbruGbPbnkxKxrR3I1mmOiJ0K4x56afEvplQ3EfhlY0D1mACqoFXRAKufA9FEZVDt9qYWm+RArU5uPM3bADKIGbpbOZJ1j6Fu+gLDQZCLIpxvLU0z3MAhXFxbo5zcbJ/7HtslN8or07rF9PqGawBSa3LhORaSdaDuanFtPh8RXtY8eyvLweXs/YAZx+wNfS/JFV5+ogeTrOOmD8OupwxGJAYkO4K9lDD1GZlPprJBjnYnNvgkYj5bzG+iQ6/m52W3iVHiTzXHPDdv6jSM36zSP2r1253EqKtbKD/N39PSKrtnYm9um3M+jzB25PTsVchVlFMt8TO+ChT3UvUg187q2sDXZr5srQ5rYDqrLXxBZnwHD3zRz57lt9qPlGuo9t0Edddo/NveOe5ArRrvQvsZqFkdaG/G6Ba4Q1+gXWkdn+6M0CipwaLyBHLjLzkgJxfy9g9Zh65ili4VCOoxyRyDoDofmkAXCLsn6pgury4/th12WrhBbxdUD1NIe/f/CGQ4gh2DR0kUDdVXpixJxnMmPplm+pZ4FTMtvvJUYdpU/J1cIKDqnGO6UywII+5kSN8eAaCuHz3s/tjqNnphYaE2b4pn2oqWH1sjy6zC14heW5hM+U1R4ZYXL4yzXyR9xi//eeIt/ZgordyJ8pVyJrjjXfSyWT0Ir4jOcVb0XhSy7pcrYcfPw6KBxDEzXfGOgITd7ani0Rmf7tBOZmxqjoZw3vpPcffboUeuP9TTPIEQHycgXV4nGpUU1BkZgmmlV6wcNaOoMbnMwVN0NB8IJ9qh11DxoPW2K8wNSUPJC1JHdeKvXdaVa6YMApRWRPUMcC1WcnkPscfmifjFKQJPS3GCXRUvNoiuIvA4soXxpBVChu0REVJuzjtcXreNxAH4fXiFnqrQERsaAvnQN7AVPCM1SaS50o6XnQLU0A9aSFDuuh2xJ3/S5HqSlQIj3LpxLkNUNfxLnXrPHg38slN45gL5e6MWohDFyD0VuyIUwLnydoQMjnehZJG/xOpr2a8t1bDIUbZKf326a8LMLA9E1BRAEQPce4ZIptv7IQdDLKLmn9ahbVx7MOGFKEJjn6Cvl7llHYYFB0L5v2eI4gUCT+S66oZMQ8uu9rfpVaFeMNFG1FbZF8vbWuy2Q7uH/fHMRfkjzhL5lLL35sW15OqGwW7nK5XIgyXNvSnqbVu6jfVbNxGweza2VF48WEBuaKOWw34f8YhdwIG83cB0l5CDljRZHlNUDktkiYlLAIkidEZiCPJJ+twSnCQFGutyeSV0q9FUN8ExQO/VlmlJSm8QO+sDRw47Fd8Y2bUenQzY1/UxAe+7E7iHu80gLgvyibpuhV1wpDr3Sdk1C76XVCV7OKOraOaDJaGS405AjcOtp97hxcNDbb3XQX3d8Ocik4z7Cf11gXc8Rc7XX+XsbT9qHzfx/XKUD8xg/U4Y2FqTyPQeB40c3cu6xRxasKsF0KXiq5tWb+mbmo2CHquRbPHNzRmduworNxtt7KhOdP8me+6wQhx/HDrkFk5erLLIb3r7Xkak/YBsx0y+xFOoQh3tCzadn1BvGcnloN+ddsI1xaIcj4uT+1HzjM1wIvPftlcx0jyvZwbnNb8hxUezcfaNkC9nzb8i/WLrsyreCcmZZyCNEA1xEBk5/gksDrVPbwPhN0EAb+4fN3GgQ9tQ+NGCuPvqRy1Ue4JT+r/rxWiI/oLXrzh1EJ7gpnewtG2SF4ZBrndwQJywAsRuyhg+q6WQ4IJeTofXKRLgOHHSE3TtGxyOxqRqRAjZdM/DINV+b7tSH7p8Hm7Ad7btmr1HfFUIZzDYvAwSS33+24K2IbKZ4prCkiCwwZD/kU0sdDrxpw10OHCrCTF28DDHbVGitnDsWVWPMihB+rVaF8OvwyhClX80xXhnGJnSmh0xjkYMxi4cwb7rVEGZXoOsrXQAjVa8mvUZKE/hUPmFjc5zB6TSw1piQhxX0giS4CC4YpYHjCwu3U+mABzkZXBrDV4TY6LY6Ob9A4oGps3AuOVaECCMGNcLDB9b2sY/9q4Txn9QysqI2lo3/tLNTKlfKOxj/qVxK4j+sJyXxn77opMd/WhUfWDb+U0D/1UKllsR/WkcKxX+6Xys9KO3kivcfFAoPitVaEv/pzqdcQPUriwS6bPxPbf0H5Evif64jofzHbQSra2Np+Q8DD5drGP+rWtlJ5L+1pET++6KTLv+tig8sLf8p+q+Ukvjv60lh+e9BrVCt5sr3qwUAwIMk/ufdT7mVUX2QrqF/oPlqdP0vl2vJ+r+O9LHifyrfhc7Etk1XD/kptqx+LxUT2uf7fh0BQJXvxPPG4QHudhZ3/+2abl2lU63DxuMm5t47aHQaPXrczZIzt2Hl6bzK7tDwTQ9DoNGODHeiIBeJ6FZM03Udd1dzn7AdX7hQBDbmPWc85T6tYoMTd1uoCG62naHN2hLbjdpGw25QATmnhCrgEU+FqbyIJmqtp5oTCs5Mel6vFVDDPde9Uqh8uB3heAp4gBtPan90ppCIwjcieGzQNMuX7Yk/nvhsQKeHHXcK32k7O+/QB5mNQro+ctxLNO3DQvRmio7xys3kteFaxik/1AcTilZ+3BI2oDcu7vkixjg2vcc4RamjTvuPz3uNzuMublLjxizUgDOPx+96vH46iSd+24748eT4+KhHpelnV/x+2uY/xEau5o799muomWJwhXaXgw58W9/M4ubVW8iH0cow/xXtWcMM823rgdN/BePAjehs1h3R9lc2S06+hKNZdaCMf4GZyRIcCbHwHfleigZf/PDy23TkxVX6SpQdAdh95k/HZh04y2Cbb05JJwMJlW3gvOemX8+PbD9PXrZLlcacs2Xzlo0ocF0NrmkMx4Z/MYPTmZgqQ6S+jR5EGCyH2kgLBKSHOSU+B6EG9X+1c76iNmA93KlUltD/K4WdWpXif+/sJPe/rScl+v8XnXT9f1V84Fr6l/q/ov9KpVhI9P91pLD+Xyg8KN/P7TwALaxyv1ZM9P87n3Iro/ogLab/UrFWqkbX/0q1mqz/60jz7ubYg3lxRqAv7JvjoTMl/ejxxBqAIoEOcVToG4/5WjGlPzhC93QubSY/8hi++6SD5EANu8eOXJMO3HkYPTqVyrKtLf55a0t6H5oDUmhdoRpuvhDv2Tn25OWmDHMCqo2X4/oNcpo8SPFZ/pjPZKhmPUYq1I/BMtgJHl874YFe2SaqbxjoFhui3uvxbnkljegBU6gJ58rwGYaC93lM0bNdVEEguxbvcWtrl81EPWSbXF/NbLNoIEIKjasFiJM14gkTrCscaEhVRKW0SETU60gUFOjzJmiWHB78mwpBQDoYjgj9advkV84a7NQcOpcZgllL8wrFF/dY2zazBHQJGnLpHAG+DMwBFKL4ObwZ0qX7PvepG/MgZsxgJ9xsQscdTtimIULSzglNTJCjsxzqNSnkHIsVzKYZQLKTkxOyZ/Un7pBlz7zuAcs+YenGxL8AqPIDtbui3g2tF1ypk8jlGpc57o+JMThwEAB9QjMy8WSljScrZiA/Miw7Lx7QYkQqqcPy/mgczokff/c7srnFf8URpFLkj8h9pD2cL55Lo7z8SWD52GbjyXDo0ZxwcmIWWky2iZIAI22KfcQ9GIPrd7g7Lnd6zHHINoY+hhzBz7vs5PzihO0dtFKp1hm5Ql4YUApreSHABR8DguwPrVwQpjmfwRhLF0g0fXI7JSDOg99uALhzBDW/ZWEAzGTo4BEeOnXK4uce7yfQJje7T/ManuTo9OJYDw17grdp8E9qkDCnJgx/IKaL8yQXOIZrjaW1aTjVOkytzDbA/jCx+q9YF1YaP5VqnGHclpCDNcKGQKDV1R+wGUij/aqYY3vc7zpwmOdO9sSyrd+gqxh3G1vkRx+RLdDhNG7hsv1Mqj+OOSURdz5UyzaaZsPmjXusOYCmou+Jg4jDbPjRcc+3mTgtvM0On8uzvNvM9PuIbKxEx8NSysa6oE3IXcYJMGF0rulNhr6XAnTnFqU8n/DvgesJiJLtimYW2aYA69g1z4LIOQRcjvnbME3jKTvRLaMnmI/enNAsAwERe/PzZGfFwp6MAo+VYxBxHqBJuBBjoRHvDUjArmMQAWJkrkmfk5CHNjjRBFrc+PqoH4D7WVomUylYy8jHeri7tZVKvVOf2DvWkefX38GqzZEUketd6l1Wpfif+AR1neiRuU+gmufQ03eSIR81jmMWzply3aDgHsyUkfXMscGP+YhA63SERR5uhzq4s7fHqwpFIMOqxCl7iRLqDa5oMm6hjBBwoiQC83Uo7tlJJlq7GuOi+vna8A5nPRSLGwUBXEhxJCdbOr2cBDVliBDEGYmtLRAOoIhY99xdhJ2M5MkCMHpLAi8GerFhrWHMMyFQcNRdGduT+6+zxxgylYQJkGZewCrnOYCIhqwL2bjG3uM+5/kUR0UZ7MGcyCr14sm23r1oWOL4r9ogOkD2pvLK5y1THwLJKa55EadFNK/C3MqnUKRZ+XImuGtM+9AqRxXitTNIoo4Hf3wc0eRHmJ9wKJnrsQM4uw+DGuWAdm3DCuNGzMc8UGIWj+nqGCK6gPgZFxyU5j0m0M18sN82L4wEssSGnzpUswygOTRfm0OQjUA8xu7yQJkgwooLjzLIjywUnEhJGI+HlknyDh2il0D2OM60xSnOWa6+FKRFn2NiymG/RXA1EF9fAyJhhEiKtRVE4lNR7uJrEZHbtKpUOLrYAvKMslZABnYLFYiE4cPszXB4QDWZu0LujUb+k4w9HG8MawqHPONkGBdoTVQQjZtFZBAJFMYr4XG+cA10fUJpXK21qKWe0IyE/rQbrCcoy2t68q8TE5VLTQsTIUm3+YVRwGYBXr6H8hygTfeXZvbUBPkds44MP4en/GYWTBQ3Zpc5yxYCBtcDJmHpkQ7snSwSA09QhozJEfA0EFpafG9UVYv7atuBWLoL6iiJDnTLDqeKsKYtYw7ZfEowv4iu0wOFXysxE3kHsz7uNI6ezGQ6d43xBd4hNMHwruxE4NMJqvQnFBWGFxlFYvOEgPhwl8WGg8VwVqDkHpGoS41GgaTFiiUg0C7hiQLCybxQJpEJD0enOOECJq/UY7TbSaf5ZnatoQMnkS3SPIKqidcV8a4RqLwLOr15imgRDIHIhRQVu29y2e/MMocDjzAGSFJ+6wF0toVcCH8RP3ooJsPkbhMMgZWN6PyeiaRNLw2YZPyBjhE9+SQ0gnuBKwEiEe7Zw1zCRCspDWOQ0CcehZdrlNAttMKcibPMpEuR1oBotasrKkwlCWMQzweWB6sXR8KUqAINL7x0FwNltLWi99iTCQj2WbRGEK+mUBpUmJ/PBOEXnR++Z3rCABYmKA7iM+IbbsnDTKI5JAQ9eXZy6l8ADnrOyOzxpSAHSko2a7jn2p2WXAPydhmLNKdWFjFVPpoTqKtCB5EnKrPaPjZXrXJ/gZVuyJWqra2fgAGemqD4W47r0TqF5qUO5BwZpxayVKFjoSLO20J48GOmJ6J/gPpDnLApv89rmytA2BvsFahjY1SfOmYWJ0UpRwpsOFvYoAhcd0mRoC20v50h4M9ywuRlDVEouIAJhmLn2K8Q5wWONPakLwcPyUR98PEgM7qmKIyyHTv7m+nShUImr/0Xx6W1UtlcsPo9Dk6PgEl9O+Gmibymvp/EgjnHniEnAH0/l8Ml7TtSOYV55NmjJ8Ca8Dw1OSd4vAuabkimxeFQc17hrQuNFWbBeA3TQQgqWheo5wlDzxG6Q9BaY9OyivLHE7y7i/wkUIuT3ES8OJq4Y5RXQ9JIRBzRn2l9zQmvjzwurBpPwkdF7AJJ2CYa/wh3xOqcCzLP8jPsozRXcy8QMmSir8cgSx4bgIDEqsVi3RROT4qdCIao8AODiVNob7xKShhNPFom0MSLK3XEvEsMXfvGDbXEpqeAKGdob5A9QeCfAFx7FAzqhIl7yHgVEUem4OYqxCsefUnEyzw3kPsGNEJjPp0qazndSCf6zqQOPpx+pyYZcQPvbvRB1EBbiMiiGkfRZPNErvU9vjjBbL/2mPYWR5oXnDsDTAo7NMU4E9/gYe7h0EKyARA+skia5Tb0OVLtu1hUIgRYLJy8k5crQTu4eNNKTnSgZK9tJovyqwLn1Kopae/4zRXvXefMiq71kqSJLEoMWdwloZV4idpie3fjuvBoehbDxoyEEXz+ZGLcg8AjL4i3vo0qg2XnfVISQbMBTl5mep3MRf3fu7bl+Am/jXaR0veE8IkEoVE72lDR0gd0JbqG+sUt2ERPUmjLFLZPLZCXiEkF9MQNoqQvcpMo/gyMoiCXlnOsMaDrVk4w2CAolMpYJsI/Zgi6A7XRJpaXbzx145SXqmAtA5QiXXPkvOaLLBC9RxZKcyCM/Gpt0BcZtilWihO+IkGnAIrH9HG+RhpDtVA2+wqgjDjI7Qr2+dDUA1qiXojRk4BtDVUAJfgg+L6sAIZ/IvFCh/aurMtk3wI0jeH0N/wlw1BQlAqs2QtXh6qfSUsD9QqfgvtFxy4o8sKiK6Pqy47BZ73KyBzyadGmL0YEoKns8h2Em0ylqBtN5L2x2yO15tdhD3XIKciDOI4/4G/NeqlplCxUB9CQ7Q0pTIfb852eFONFPXtc7xQ1QQ1cUYhRQQWVPZxYQ7puERcjctBlBw5dpxHeL4rb8hFxiGlTR1hxsd+G5WbPDZQGdRddL6NtkOTyp9gubhjkUTLJ+47YDcLKuNTahmUXxuJKoYv2wrhAH1Sk+W3XiSjPARPcqXDdfl1ky2xMyK2eY+A/KIZdOA7diZuS29q4oTmyPI8H1LEtcwAiNJZ67Piz39Q161OaV5Q/bRuVXTF5os6BAcSNugE8+VQbEj0xBTTRyNwnfDf8BLRhZzIGXudNBg7lGDkDljUeM+EdjEEaOyfC/jB0zlFYIMEEL8MF4SWH4wncvAHxPdQx+Q2xyGFgTFn2s+laZ9PodgII+PwCdazvAhiRvo8ApfimDnaXkAHNVCODX9XC3Qnc8zx9Ad6M+27YFQpEHFYpvG2uR+C8Ub/S0CfaQ4V/NqLtEBmnSyqGuEsj6D9mAmQZjR3a5mXHDqJjH/XiM2CuFzzrNkAJ45pJtSb/e+wYOVN/T/r11laX2O2pid0Qeg2b2Ghzw0hKQ1AaUtxrPUu9NlHD9i4mGIHsfFcya2BLsqzF9SqYHsvVtCmuZ4UmIAdchTrHp3IIHBJELiFZCh0wGBWfB1SaSfnBhqn/0Dl8CTrxK1hoYSGDDmtRn2kaPAKlxs0N17fOADgeiaynJhvimpFjTdtDfSxgBNJjolpgjx/izJpKMlZqQiAEY3+EHVGQATZm4qEDD7olPgHkZCy8HKqh8dZQQgKf+/IDkdguysnIvbfDxisZDC5YA6SRFBd42niEycItQORS3O9f9T3HtwGk3oSIRpQEEworAamMqZaNe/qeJGVYvPknRkYprE7QOKwRr0BflXqCh+0rF4vdYC7v41R2Goe5mzjTof+3ZKOr8jFa+vx3pVAsFYp4/r+QxP9ZU0r8v7/opPt/r4oPLH3+W9F/pZrE/1lPCvl/1x7cLxRruXKx+GAH/reT+H/f+ZRbGdUH6Rr6h9U+uv6XdgrJ+a+1pPWc/yYDgab0656pPOAzqHM8djBtT5GZlTZJlFsoc0GhJr9oMhkpNZH2JAzURED7OKegwDn9NLmyEbzAnFnfyQY2gpfrOFRONwR02u1jfqA8m/uAI+Pi7h6sLc/nkO4gmXceO8gSHMZGfSG+FlV6ubmLPcWtLEFW+Ji2MC9QhSzrB8dnFwxKey8PcO+D0pljkSPgH5uEPuuE+p/u7rqKNpY+/4vx33bKqP/tlJL4X+tJif73RSdd/1sVH7iW/gu1CP1Xy3j+P9H/Vp9KDyLxXyu1XKl4v/igUqkk6t/dT7mVUX2QrqH/SrkSpf9ypZTof2tJa431hQ5U8ceaVtAN9O/gyqS1bIAsKBYfGSt1Dz4dkOMpogv5AZCD4D1xGR6dCOPbYda57eDBg9OpOu5826PjFbJO8w/PWp3mPhPvxDktjE3FfeeDI5ioN9NwRR66O37sWp4pTgVkUmKz9km7e1wPCgbVxp/HDZ2bDh2ZxmHjdc+0QYyu+KPJiKUxS1ocHaNzYK71Gh01qCip9+nx5HRo9Xs8J+WhF7mUvp1cDz111Zzwsz4MD2/wixvZ5la8706GCUThh2/aT5vqTAbCTp3zk34NaidVHPejk4vZbFb6iBd3409gQRbIqE7U8C3KyJGaxQerUvdmjnDVI42XdmcPXlHDc49e6ZVGD17VDStLxgLDnWZ9PzvxsrjDWIorM6dD5d3QKazYvqhzWFCvOoVVF41lxdvQaaw6fzdzGCsAPx7a0QCvvMvWAXftVBUHeiyMFx2QSt0Ln3aaC2bRFDUTe36qHnmvVxicYDLPoCc+25x7OCmzy4bO5TbjZ5uIPvFIUypyOKrOv88wpkigAemUFAQb4KBo44Y3zDWAw+LuQshVeSdUPAbl28hLckcGfgKDQBJzKpT71wObSoUOydQVKFxnEDommoocnFF41T7CS6EaB5LVCpeDmCNUyPZaZ9LHIOJUQI4AUX8CdFSO9ycQ7gQwvvgDU/XYI1GpGL+H+uxLcahr9os8vcXXFH6KanPiiXux445QscGE/vj8Es4hJxRYUkKHsqi+Jh2egtmxzjAYADnZvbaM4KgVLSiwFvhZgA4uNHJhwcNWqegprXrw5lGnfdhrHjZaB3XbQRPlcPqDguvHFrM+2YT2P6SnVbZxE/+PYrWC+z+lcuL/sZ6U2P++6KTb/1bFB27i/8Hpv1yrJv4fa0kR/4/agwc7uZ1abQcvArifGADvfBIH61baxnX0XyhE6b9U2Enuf1pLEvDP9TBe1yvTHK+gjaX3fzX+X64k8t9aUiL/fdFJ0L+2CXz7fOBa+p+R/6qVZP93PWmO/FetFasPHiTy351Pcv1f3ep/Pf3Pyn/laiHx/1pL0u9/zfXmRBv4wDaWlv/U/a+1WiWJ/72elMh/X3TS6T8QAm+XDywt/0n6LxUrtXIi/60jxd7/DnIgACo5//UFJJ3+V7P6X+//V5T3fwbrfzWx/6wnreCs19xAmfxikSA48gq8/rqvrLGnuYLwOBrY7sSj2xPGrplVkX6CcDZalE4MgwE1UaB4CuMkAlOQnqQHpbhHrjQizDD6Fr42XG+X6X5p2+RROJO+FbOg/I40J0S2iZdv6B6IGb0dcnuhII/UH/S48HiYRrYZjc6ToS7uqWsBcBS/33vWPW4ftv7U/F7GpKL7Pci3IxKN9fYdF3kkTeIvgdMKZzWp2YibexSVJehPJKymCFvJj9x9J57MN+gpwo4Pj/ZbHe0qR380lllGrwCIeFPEBs8l38tjdgOWDsqJIF15z+2TkqyftYtUN1PoO5UHCooYM1m8U9M33frp0DndtfGV9EbaeKujztUP6hldMq+wUu6WifHDZBPYpdmGsbdB4+LOWGoeZm+MsWEGzJuQGydGZJumwz3N7sVXyc77GHZ04quRmUPPjLSzTEAeWfzMUhVRWRoNL4M3uFKQNwDHfGjgzR5UdIrhuN7x37aTSac0NHooI+E1g0A1m0SAmXiMCiJxihdx2CQ+3cgxixdRoR/rHPH5Wwz1Vr8vHlrHzU69qOU/bnR/6kYvO9WpX8uLpybrsXOmZWo/O47JEw7rKOkFI8PpkdzQj+vvf/sr/8cUQwneEcPizJMCrDpD4DAIfsFxROh2coKTHtrc+TqE5BKx/v4//zPkvAyfDFsEgJOl6CxwJHskrjRl1RmmlnVB2GYZkpomiuq4z/SEddiT0SlG+DwL7rXQoiKJqH1sE2HMmXIwffuN4wZ71O4cNo5DE6jFlA6HkI5bixiFL41Gcsb18PpYzrtMi+K8zfgtLVoEZ1zDZiI4b7MLy/a9nm++gd8UvXmbBZGcRSDnjy3cJOnaFG//WxSn8+Zt3Nj+VypVaon9dz0psf990Wmx/e92+MDN7X8V4ACJ/W8dKdb+d/9+rQCAqCb2vzuf4ux/t7v6X0f/RUC0anT9L9US+99a0u2b4ChGN+m33dxoQCfXVGz20Eng1VoCm/YAAxaZ9kC7PeTC8LmeiQHgeQRbGUiKXpdyPNa/6anA2eGI/5QLL6CUVzPFBMWmPJUc62J4ek/cyqNFrTd9j7JU6dZLLxypX6iMeDWJyEx5d0Rey6cw5K9NbYZD0e+xILZFYYdNn22WRUD8DNVTy0krCAyRboigr+H2lrBrstCBOv3xVu2en6T5cg57TAyYiQFzNQbMPbr7ORKOPx6X5AnXjRB9ah/xzORGhFrFZ7o/rS7uR4vcPbX48gF5gVSWXnDrFB29hMxe7vzXYc43R3ju2VQ5gacwdRdcXUxL6Kt281v98Hnvx1anIS/JCOWjcNn1YqGg3opQ57Ozzo+DYp8Cm6m8NyvmEqx5xWZBg0vAQ1oCcLsLmWgsdBbYkSMTveCGBjVMftXRcqNcOC3epdmjBUw1Ey1K0e0p0uJ8u/ISEzm/If2eNVw22TEtmMdAQEva6MUEZkeEfjm6G+YmXWC16gcMI0uLbnjWli0JY5ydhdhNC5wOvPTx8923WHIiggo+YDODX5TVA4Bet50RTDu/nqpD17uEJNcOiUlFgAEC+tMHQkk8PGx0m73QmxuDZQaz1wAXYxgCi0YEASA+C2Io311iKH02xFC528RQ+lyIoXp3iaH82RDDzt0mhvLnQgy1z44YPh2vD3lTnNEf4Z2d7jhzAz8QWRivNDPtQdYYW7x4RMsM1TF74ziWEMpytEH95nHeorx+PC1KpHmLoLWyIGF5vIY88CYJXUh+664ngA9Hz467EQjyUFQzQaiiaJLnoEODZK+YZ2TRjbNkbkq7YibIXxL5Z+/tBMHu28CAGVQTlC2LsloTsmRcU5X5TZWua6o6r6lSbFM785sqX9dUbV5TZb2pFdj/l/b/CEIo3riN9/D/2EniP60pJf4fX3S6sf/He/CB9/D/KCfxn9aT4v0/KuVKZaeSnP+/+2lJ/48PWP2v9/+oFSoz/p9J/Pf1pI/p/0FIRS4BiRfIl+UFwiF/59xAaFiJH0jiB5L4gSR+IIkfyNyJTPxA7ogfCF/w+OvPwxFE7/Gd8QRZDIbPxBVkLmQ+J1+QxZD4FJ1BbosgPilvkMVg+EzcQd6bID4lf5DFkPgUHUJuiyA+KY+QxWD4TFxC3psgPiWfkMWQ+BSdQq4hiMQrJPEKCfAkcQv5vNxC5sT/FRD7wI0fkW7u/1GolZL4v+tJif/HF52uif97K3zg5v4fpUo1if+7lhTr/7GzAwDbqSb+H3c/xcb/vdXV/1r6r5Zrxej6Xy3WkvV/HWkF8X9jdizW5e4R67aBaqdy3dgG3X++0wZ6LOCl0XRPsxGruPD7rLHOmQEtFxL4i3aaUKxFD/+buE0kbhOJ20TiNpG4TdyC20R8tGtisZ+47fs93QVWE/86MXrfcaP3xxa8P5G06P6329H+3sv+C9iQ6H9rSYn994tOy9z/9qF84Ob23+JOaSex/64jxd//Vnlwv7pTS+I/3/00//6321r9l7j/rVqI3v+2s5PEf15LWv/9b2swA382t8Dd0KR7x6+BS+zAiR147ffAfe6WsZXfBPfZWMKSq+CSq+CSdMN0nf/nbdwC/R72v2otif+xnpTY/77otKz/54fwgffw/yyXCon9bx0p3v5XKNfK5XIlsf/d+bTY//M2Vv8l/D8BzSLrf7mW7P+tJa3R/3Ol172t1fOzPTbtRksf0YpdP+/ArWmxnp/JvWmJwS9x/EwcPxPHz1U5fiKH/ejW7VVcF7YaY3dyAUbi9ZmkJCUpSV9E+v+vhNfhAG4BAA==
