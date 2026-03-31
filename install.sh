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
H4sIAG0UzGkAA+19a3PjRpKgdyMu7pb3ee9zmdJMi7IIPiRK3fLQO7TEVnOs15Bq2z0+LwWRkIQRCdAAKLXcrY29L/cDNuYiLuI+3h+63zC/5DKzHiiA4ENqiW5JKHe7CaAeWVWZWVlZmVlG2/jioVOxWNyoVBj9u87/LZbX+L/89yorVUrrq8VSubRaZMUS/H/9C1Z8cMggDf3A9AAUz3Um5oNsp6cTvvOuMPXvY0n/6b/95y/+8Ysv9swOO2ixH5lI+O6Lf4K/Zfj7C/zF5/87W5W1o6Om+Ikl/jf8/a+xLP8Qvv/njts3zMGgZxkDz720HNPpWF/8wz9+8f/+y+J//PP/+af/dQ+dTNO4dGi+f2OZXcsrdIaeZzlB1/buu42p9F8qxui/UlwvfsHe3zcgSemZ0z8Mdz+w+1a1tLGx9uplubxaNjZevQQOXKm8zFQ22G7j21pz603j+7rx3gwCz0gi12rtz41asXZ2cXH+w8nWX95m1l6xFhTafTepkEbjmd96HJ5rMgoP38Y0+kd6ia3/pbW1L1jl4UF79vRvFIy2bwXDgeGfP1Qbt5f/VouVjVT+m0tK5b9nnYxCKAE+FB+YSv/F9Rj9r62Xyqn8N49Ufpkk/21svFpdT6W/Z5CMB6P6ME2mf9jrra/F6L+8Xkn1P3NJC18Whr5XOLGdguVcshPTP88ssOp9Jqhvq2d6JjsCPtM3O+e2Y7G///vfWMMJLM/sBPalxVqIhewH+1fT60KBt755Zm2yEDvvHSiomOWtocsG9sA6Ne1eJlPf/779urFbr2YNGItsBtr8+9/+Hf6wN1ZvYHm+eHzsfzKZgWc7Qfuclv2lHPuQYczqnLssm1W//v63//HE/oR9Y2yx9LR7eiPn2A+swdgZJtxeLAm0plKmfyGy99yO2WOwYPcHQTULA8YuTa/tmCArZBfLWdYFqhn28NOH1c38TZb5Vsez6HkNn1UVl2ZvaMGTfcp++onlHZZdFGWz7Oefv2bBueWE7fAf7CeZ5+fs1+zUVsWzi7yZLLADlpW/ZTUZ3Lp4gNYsD9SaHzBZ3ybLKjgiI9HzLb3QuDIEAT1g/+jHZl6CSH2l4T5l+UsoLwcqy178zn9BL6AAjS+07PrWbEMMOfxz+zRgZZXXHQS26/jVpeziH7M59dpWkypgx7KnrsdsZuN4f/hSFPzpjz/fwIB2XW0cgBqWlmz2FSvlcjm2+EFmXbR/pp51XcdSLUEJu4OPV+d2z2KBN7RUdfoY1pG3i9zsp1J+8cOCBsLPOLaqqnBu+SuY239j//pTMf/q568WYW7Z73/PlpZkZd9UWQnfiMc/VFm0bpbLacgwZWLCzi4tiQrzOA6857xTwdDjdRESyFFrODCpdleAYbDDnmX6FrOo3yZzhv0T+HFiBVcWoHeJmU43BqihBpfTXfvauRPpORqtXTttWF4DjVwUqSG9XGsUJ7JWsz+9KzhIZUgL2tvrwr6iPV656fhXlpdJJBa2KErizKqM/AfCyX/FaKaDI5Zd5N+ygKo0vj9dv/t5OTdp3q7Z119TVsg2ZYodntXyzQ4OM6zr7R7IH5GBxhc0zCGT+hVqwtfaeHFEiDEjngeHdiG7HGVDkOXMswYs/8vr9ypndlEKGVlW/qbQtS4LzrDXS2pCUTQv+c03euFMBDW1ObqwrnG4sczvflddvhF9+lLCwrL/uvgBMt1UpwAzAwTQ7A0KSW8HXTOwGLAbs9sF3Ifqke2gEMWWYL/nXXl2YPnMem/7ge2ccUaao8kAMSwyFxz+UlYx27LowZ3g9y3AU9s4MS9grfgoSxrLH8UvwcpvPmZHB7fP8qfIIeTrG6wmsmaI0YlWNXacsLdnY3obIt5ppFcRhKIRmN599pEFIM6yfAl+dYYg5XarUG85zz5+JH6tIEKe43ptzxrOuiIx7AQHejXLTs1e78TsXKglXxMBKhERQM48jp74CZmWxJBAT0S92Zw2FLhwydyxoYisdZtsaegjWkXxi53CV0LCHJ/RiQuBaiiBsmCcwoU1Uji7KMcgG0omnCiEdMV3NLC96RDfZ0sWbICA8QGxDx0Gm0qna/ZgDcg9+N4CZA/XObXPhp7VPrOD8+GJmPNQUGTZHTt4MzxhtU7H8v1QVKwx3P64Di4C9IkF7gUwLNuHofplaHtAZ4HLOtgTeDNwfTtwPdvyjbAO2E/RUCqUU62du37AlgYe1svlBhRdOIyoO1pB1sIX1mt36LGdN3Uqg3OQy7KdxtGbt9+23xy0jiK/s2ENOhTy1xasYsC1TNEVE/DoPAgG/mahsPhBq+cG96CIGn6BcsIcOpbV9dkL7OgL5nfcgZWbpZ9UXMF7dPBdfT/6kM0qkVZJWHI10jNyaogIcXoT+rQYHKEJhSeAEW2ZhBLskFgtYXVjvHBWvMXdc1YbpGwIIT0mZBOQx3oyLmNrNOeNjsHmGSCEn4DBNfzAtkRGE6lOm3PSQ/jDwcD1AkDic8+yWMftItPgNRrsnTsk+lRtMURqXNzgVf/EdqjOOGK/bdXbW7u1t9v1qiMfD7brP6qn2tudnQZ+RLmHNgEs+8O5DcyAGl7yc+zKBu4NGM4Aaf4ly2o79f2j9tabg8ZWnf13mkbswLBrQfe6wH3kO3h4z5YOBpZTa+TU69rwrI9DsWQOz85sK/yg1QFCP5Ue801UQR0UspoOlJLYImDlmJa0YVFCGwc4uxzJGOamUQszSxhGsmuDqlWd0DcqqQPydWJDyV2HwqNFo82SbKnJhGH+EaE7XIcEtuqNHnrupd0FQTiyR6UHiTBv3CsgTsIRwYd5BYAtvMX2YfPg+8Z2vSkmFPq1DWygE7CaA9juDuwOqx022JJv9wc9C/guKuL+OoQfgPL4BVZhhSo4/L8iBdQa7LU7dLretf7phxb71up6Lqx+HEydX+gowfvAESgGp8KhMZDCBGTkjEeZarRDKDyw2v7Rm+bBYWOrDa/a39XfJbyJcjqeopx2pEyE3fIklkXecAK/VQDPCGcSVGLfLRqUTDIBuiSQVUGB3klTqQ1tuDjqz4eeRf3ySXzHRTlex2a8CGMlA2ZwJCMMkA9rN+yvr2BVltjRB+yQIsVoTWWDHZ1bYUlc79kSiXWB/v5tczc3WnqVwyGmiEpxoA6B94Mg8w37zrr2aV9ed7oD13aCeCXZ0eEX6IvMo42E/vrg7f52EyehlB2DqCMjwGXHcM5EHe1mvXXwtgnMfsKnrGnnT7FC07vOB0F+6Oct0w/KCaCOryWKMiNfp/QjAY1lFaNkF/9yG/KLlf00MrwF9HchxhFYJ3UkiTg1ZnoXugyLJ5NkAsFBN8yTHkjusFcnuRorgU8wUCA1iNqATPa0Mgl0BlSKBWG4urBg2mbP5yR+IsBpOJcgcPJKYBfRt31fyGSj9CpFMwDKs84gG27tCMHzpRUQi/JXsGTlyyvMCjrGCCwzkOu39e3mwdZ3k8gVO8Mbz2LHgCx2Ggf7+s+sgimJ6lQ+woHwaUJzYj4QhxvbvNXa1la91UJsaTe2E94k4WgEhkh2CUr05QSIeNUaYByqVn2rWT/Sqhnzdip0I0UkhKMf4sRC4hbtzOMyFwp0M4hcJC7fSdjiIjYKW9jUeFmL57uLoMVLJolTJMpGBKkIDAlyVAjFeCFKg5Qm+eCwvl9rKE4Ye5zOvKMFPo1jT4Ftdi4dB2oEzLHCkpiOOwtKvPwUIUn0MyogmWzn8ChfEQy7aw167rXVHSsjWUKCQVkIRCRc6xj8tTz2YkTKeYEMXxeFZhOeUOTyUQIbwIZ1Auul5303sDYJMr0bfUT/E0t1J1x5kgbCiFfaOGWOG7BrmFNZwwrhD5KXIFE7QfSUS9iWCZ11z0bqHcsIdajUCC9ZxpmxonRF/eu8AtiFrKZtmFgO1U5A37W/vG3W2wLf6vvbhweN/aPkt+PkoaS8WVTmfjn+Kx6gSQjHEiHjJ1jJ3USzGFKmEjqquiZvdZJqGjMG0ySr5H6N6/AsMxhKfnoVSmRNejmDtJpQ7BP3i7PDfAtBNRHMMeCPGUy+cOoMifRLfFfGieJsEOQr4p98B/OLB2OVP+bk2rkH/9+N/M5SxiQZLsyUVesef0yUDSKLOAfaA3HNdeiM4BS4cyChaNZrrYP9xv5OuA733CtopW917WEffpzbZ+fZTAI8qmgIU/gqUT7hWqPpAkpccTeqzIwyLoFbohRMlc+ZKrC6M6ubB44Ir1DmNlhz6LAXvFr8bDsvEEKUcM7NS8t5AWy0h4e718YEuUi2RJgAmPl2Zw91gnwW1TjCeDtWsGass6WeGSCHbtEbkoNAPnH7UEnX6uoykDsY+lSijycCHXOA+xM9A6BIxViTuk52aZtSUafnOjfti+GaUYGFEKR0aHoFYLfMAfzKib4ssPr7AG3PBD6DRE2LnGaTEOkXHmlFXvzud2z5JkQMKaYpjWmU+vSSRHaRFxl5IBeqt7uwVLX5qpKg496GrzCc+DWmhg41yyCQcIVygFwF60P1NT8VAwl2u3ZUawudgtD9vjY91+dC6ynsr84Bjw6bvKQ5DNw+oF/H7PVCqTX7rYck9Q6R7eDKYQTW0qBnghDzJ6CEXegWiL64JmMtBT74kiQ0CDhNqPbjJ+n6AIeZMqMcKuwBiEFZ9rrWPGgRV0OpKPqUlSvawHO7hjmwjVMsbJh2bO4ixXDuoi8mQiFOWsIS/LAl/hxn49EVJpY7triEC8voiRzKoRwYmsSYVMW1ItNgjcOmlpeEAVInPPFXCQjO7WDMXgJ27+2eAhNmR0CeF4hfSzKvdsgm8iAJX6BhwcDybM6UrMCzOz6XitG0kxDnyvUuuFrCHQbMDpKOJa8dXC3kmY/eAAABFNOqH709bO/tvt49+IFlnayGyvqnZP6uozCvOglzRKNad7iqkNfcrv94WG82iHHs1/bq415nO3jK1bbwFJyWDL8wPI0vYsllcfLGfBkPrhwjILqGgvWoWdv6DpZCIJJG0rtEaPQMGiiR1+PhgN8eF0YA7/XT5MBl/oU9yCUA16o39aEc+UCtafYI4/LFpntS11SJCbWFJDrazYHp+4DP3dHeHNZarR8OmtvjP4wKjGPhlGWS4FTfqBKykeDiTkSM6XZtTresZXmXsKz6iaQ8hgB3rL7t2MSakI/RKvbLEDYswTUeuXs6Ue7U9xr7jUSi5J+SiTJ2SB82SBI3L6lk7dhjfCQjR+VUU4zgouXpdDv6Rg3i6Fi0QFLa8WzO0a0+WvfARtg+hfWY6FsNRAs2RDtNVA8mDIX8OMtgqBbVcMjSagRGXsSHJLYqonjFYTe7XaROrc7XzYO9dn2v1thNfJd1XNhkD3rXfxxdpOWgS4hjwx6HMkvDEXs3pkgIQaSU9npkzmowWyhOn1jnttMlkwFv4HpoaAKCxvtrNVOHzYMf3yVOE32ZvoocYnVJA/3m6OiQN8aVQaG6gks7768NBAr1E5svi8AUsQBvtf19bZdytilfnPlFM45neWEN2dFSSZn9ybmFOWS0m/tunncSLYGAs+CGwsz71sDE0cZtxf6B1ivH5W2wbKm8YRThv9IK2aZh8RgCyLwIj15JKMecWY6FzbSlhJEgxhxK4WOMLQrxvQW2b3HbqQsHePtVaBDiM9OzQiOULu2bulaAml1l2Za5jeFJZC6V7d3I0XEOJxbVSyNZx5x9zl5AnL7kYqijG1hkmG5gG60uqqYY32ySUiOxTW4BMqnJyEYtqQ5pCqI4wQLb5pOkydyRCUtqJiYwxxvStkrVbGQHpGxRI1m+fXewndUgqsHaqaEWgoCKVLHXZ4j0gk3wTXDMygo3cKdoWUrOWLlMsqnLl5JhoXF+/FAm+aPUiHyZwOsSbKSYD+J7D6jlHHY5SrbnxlKHjcP6bmMf6kQDpVAXkGAwNdZkKsloisPCT1yibegnLnorMYsh7UwhZveUYIQUsXdSyq0YnvGkGarPhq08zaLEidqcyaQ0OhW2ROcA4ixZ2iCh7yDNiDaesZJxXdBozmkaIJFtJj2QyDtZGxRmjA4BsPsRnY8YF031w9NYBVD4eQY1kL46qjUPU9K5p27P6XpnpmP/ypcX1qwfHrQPmjuZuB5BfhhvPKpXNMWGdGyb0nSUMjelJfC12MhSRrGvSoAu3ElFwItVMw60ia1JuG6vfdL0JCAV/BVZ+1uQsAXD/JPtmeo9P9IFeeFP9a2jNuRKUOdoXxNVOYdaG8nKHBTJpyh0NEBH4VEqHCqwZ76HHGjQzUjrh/nbu429xhGISsViNopyhyBd9XpA9qF2gZQrlgfi/J8Ovm2x7JoQbL4d2sCr0cqdJo1WFhTO+rA8en5mdt148+0+57jVLOfKfOGb1dxSK94hRpVQfLzlgF5aHsGrRTex6oh/0Oxotl1/XXu7e9TGOhFnkfuo+m/yPbtvB4sf5Nzc5P/qnviLH3DIb6KCwOR6YsVC/4amnKilIXrNAFt3h8FgCIvu8KRLBgVAWIDdsl7sXKwpmnjcp5kdkIzx/+durwuTLaRj6Q2CWmHp9hLz0cHjVG62nwcWUwDQBWu5KZyRuwUUHVMMrfFlAYRmhhJDp8AHJzH/7ecw3sbeu/afGs1aW1BgAedP0eJIe/HSNOVVoEHxS5v9eFGxWkTL4yRXyYtymf8W8x4vrDyd8JXycrrhVLwjdjrEf05tzw9gD2n3TWCyJJPdgo656Xjr7evXjR/vRsrRGu5AzbEKJEFHz+pmn++j+t7hbu0IaMx6b6KZT17KQHkQHbS2boxrs9+L0GlC2Wu3O7YcB1FJoDxMgZSB/Qje5zWcVuU7sCPVssvWs7pYK/3Vkkg4KV/co0bteOX2uLvJxpU64MyFTqhOLPK+4fwmSsI6eWYTMNK3YLPSDbc13EfDxZUz3DpDsVZ962B/WzLrbGaKtX7SFiYJn6LVagvE7LVPopho9SHF6PhKG0k9Y6yOu3AxiR3lRMTWGwsRTEPt5Ao4do8rLDiYnO2yXLbwobCoFrBCpKtCCo+gWHkGsijrLY+hjPIIaQgba1kJrEqNHQAzXP30r9oHUW4WqiqPrYRa0w/lpxNbWc9+a3orI8FJfRdsvK/afmAGwySXqy0eOXaioouj4ZcTHVyl6Rj3HMbViJElG7dbCDUQfB0y5LCGrpqqybpzaXuuw7fy5AJKNngLrAUd0ZVqF2gct9RHCUiYvJLvqJ9TG5TG61ZVObzjgCuJfZwPuNRJjfqQC+qA9gPbEbEoBOKP996OhNGQXxeWqzcR3QTp6JVCYpnUSMsfl7+rv4P/c6Na+CEPbkYMGhnDGqQT82Zxc+3GMIzFJeFoy+NXKM/iDqtoW2eluxhbqwh/ESsgNrS4HWF/iLhMT1hbfJpIIUcicpBik4QTVFOFhLxMJK4mi2bqlKYpzCN507JgypGJkd7Yp1LPGPmqOngq+BfBci13miF20AeOHk4ivjO25Lg6HaOBYy6kPZBS24j7PEynIL+4K2/kFdfaRV5p9iSR9/I8Dl6O6LS1IDLDPkp8ER/xxn7rqLa7295uNNGVe3DVzWWTPsLfFjDUd4i52uvCwuKbA2Dt/3aTDQ8OeUAiPH1CKt9ycXKCuInLAnuNRyvhcKn5VM2rN9Wl3G+CHaqSrzBSyylFaolqIBY/LKhMFLUkfxawYhJ+HLm0iSaTLllkc5wVGMxtly0mDL/EUqhDhISJNJ8d0UMwZhSgXcM/Z4uDiO1HLP7BvvUerUWtgX9XqGSmBW6fFgb9ekF2y0Jl+UIJfhLyF+RzLt245Vu1rY2zkNeIBriIdN3OEJcGWqdWgPFbrFmvbe/VjX436r2/Z8JY/ebxuh4y+pf0idZjsxH5Aa1NC0kRH+C6jL9gOyAr9HpcPcTPrISqLtFUzQS5hBT7eHLasy8snNeuiy7QW0focCPMzWJSwBJaEcojcuvS8q4DAP8sNE9rat819yT1XSGUyRzrKkQg+f17G96KsPiKZwqVp8gCXY66RxPAoWN0FORQqR9l6uJlhNlmImvl2L6oGhNWhOhrtSpEX0dXhjj9Ksd5zbtrSOFeyHg/FjNlchfGDbfqwugKNL3SCXOk6tWk11hpmj6VTyjDXbd7ch2qVS3Iw4p6QRJcBBeM08ARnk1d8aAfJGxfmb0LQmz0Ah6enZMfhe3YOJYcKyKEkYAa0e4Da7vP+I8Y/1utBPdZsZZmjf9dXq8Ui6sbGP97tbSaxv+cS0rjfz/rpMf/fig+MOv9LyH9V4prpTT+9zxS9P6X1dKrV6+MYmlttbK6sbGaRgB/8skIqf7BboKZ9f4Xbf2Hx/T+l3kklP/4Nv/h2phd/lsDplPG+O+VSjGV/+aSUvnvWSdd/nsoPjC7/Cfpf628sZ7Kf/NII/LfatF4VS6+3FhdL6Xy39NPxoNRfZim0P9acWMtvv6v4v4vXf8fPv1W978o84Xm0HEsT7/yRZw6/UFuTOio7pt5XACjzCfe1fbI/Lu0+S9TwLrJZhp7tR0ys9zarTVrbXrczJOnmmkXyBl3k5u934hDFW4HQVYO8dOUuue53qZmAYGOGtwKIlQTb7mDa8piiDNKPDChInhedopqZxlZRzsr2AwrIKuXSAX8xhuh7S6hllmDVLNSwZHJjoNaTWoUct0whcpH21lgdcfHc40+RZ6Txqa2jBif6V/AO7xsQFik4pFFJiNswwF98MhJnYyOtCViB/VpGhdpduRLYRSjzFvhOx1kF3hDMhvdBPTa9a5Qqc+9yCzNwOTS9Gx0U0A/GZgH1O/jYbAJ0Hh42ouI5jr0Hp3NMtyfrNbcaeHxNB7JQg04YaHfHNO84kLXtdA3jn62xG/poiaOcDWzsA9fQs0UmD1yrhwC8FV1KY/HVh8gH4awx/w3dFoNE8MPrBdY0/Ld3qXmTT8wg3O2dHjQavyY981TSwWCx7Y9y+xRBtvnTkaXQFrkxRGS12Ht6A0aDai8IwgWiWf/EY+PITvME1kox3Pnsng8L0xV+AQuLqHB2pjcOZrQ2jBw8xzlhHcRj5ISQUDoEAzbNUfEyCxyM829g7f7RzSPyvUjjNsiKpTnqNgHsnkwTOEkok+LXh9OiwAtG1wPrCqw5+4KP6SrRutYgdXrzAqqhXO3b3FmE35DsyXX6V3DjMJ8iiBy4pRsFCpuvvgpMPGIP0kQ8S9ReADBOhdAImjdkM97fTpTzedp0qhYXmEc/+JbnaFnB9d5d4Cz1QGhclAdOtQfx+qKXECaeeI/xBDxHZldC4z/6Y8/f5WNvbjJ3oh8eodFztgrmVeOxchQZKMsRI1G3wkK5LUxU2nMOVq2YDtQpxrGaVVF6C2htshKFq01KxglPYwpkcrsTyCh/k8ZvzxQGyAPr6+t3Ur/t76+lsr/c0mp/u9ZJ13/91B8YCr9j+r/1tL7n+eTEvV/xZev1l+upzdAP4NkPBjVh2ky/ZfLpdUR/d9apZyu//NI4+5m3oJxgf2bx7bDSK87Q7trZTJo00qFXvgs0Iqp3ZordE/ulcPkR35D2zbt+AzYfmMAIy1mdiaTZ8vL/PPysjQgRj9kh3zIScez9JN4z84Qkp+XZAxH2Ej6Bt9NIqcpwDYnzx8LuRzVrF99BfVTTONj9Bg+5vd3Ycxsj+4vw4YIev0aM14Jv1pK06hBTThWZsDw8s+AXxR1uom7MsiuBQVZXt5kI/fAsCWuacitjISsphvPtDsdZI24i8a6otGBVUUsFnicoI6FeASYl2Drz+eDf1Px1Wh/ij1Ck/gDcg1hNXZi9dwrPgK7tjMkABqyBq5SIAXKirhQgg2dgWdfwhb8DCYQo/KRY7k/MDuWv8mO/WHXZf613wnQ4clzrJ6hl2hTHD+/TZfJVUvHhCwNzaIcXyywA8fKE7ZJnFjSg8pmMsfHx6TM7gy9Hsuf+q1dFcTaM68MbiSNTaGuDqAnxCGlbV5qbfOi6kLftJ2CeEAdcN5l2tPvf09qc+0VNp7JkCkwd0/wmcmOeZ0axRSOQ9XjChsMez2f9EucDJiNKssVogDAJIcCsnLj4fDadG4Jz+2NDT4we6YzxCuBOTSZTIMH+IV2LCjRFVVw+vIA+z17IFWgvevNcOAS+wT1/3lody5YC8ODZzK1UwywGLH3R3gJLK2uTpeN9B51cHgxCXcDCP03uM8HsR/7VwAVrwbEFrm7N6I4KZO42tUJcpnOIMFpR/mr8mKksNCy9a/zUV3GAqt3oan4exGtmMe0hY+ud7bCRLCBFbb3Trr28xtJsEtl8lbMqPOCCW1C7lUcAAt651n+sBf4mZ6Mu1DgA/4NUJ2YUdJn0cgKCsRpHXjWaRjikiaXY8MKDNPgmh3rWv5jzEdvjmmUUXeGFBMU6MyAIvzLiyqxcrznkEdSFRbtWKjPoQFpznNNQkoMoTuE8VE3BIgmUAvHeb3uj/m9VJdnMsCXyeS/t7m8nMl8VJ/YR9aUcU8+wgrEkRSR62PmY16l5J/4BHUd65cHHkM17wDSj+IaQ3ZYO0pYBEbKtcKCW9H4ckzcBUkeVTIoCtTBfQ98XlUkVDBWJaKzSJRQb5A7xy8YOFarm3UZCVB8nIvXrvo4qX4eH/gjjrp+6xyxblwUsCfHyzq9HIc15YgQhMvO8jJwZigyEHeobOLcyQtVWDiN/oyTlzB7iZfWQZ9HotVhr1vyihXuTsF28OYaWhhhZf4J+LvvAiKasi7k9KHskPi5wId45CYJgGBMEDxYqFZ08OKXaiV/1TrRBLK3lJMIb5lgCKWApOZFSD3RvLptSD5FLvyRL0fu2EloH1rlqBKu7zqS4NvPBEc0WQjGJxr1bzp2AGcPoFN9eXdHBDcSPhaAEvPoNa5jiAAB8TPpdgoa94SYhOOn/b55Yex+Amx436Wa5b0IPevS6oFwBqIegsvvPzgGyZJf155DfmSfnR9zgRd28ng6BqvJiQtMVE6yz3HmQDgVj3L1mWZawJwQ/BnhFlGQQXC7BETCCKcUFDcMma3CUSfXIkIsa1WpuNGJBaTLvFZARmCOFIjFy8bs9WgcbzWYm0IWjIfolow9GhgYa4rGJuZkmBQRWVQQD3BLZBCL6Msr4QF5cQ30AkJpXK216wV8IWyLvcBmuJ6gfKvt+X4ZWnRgGu4oxN0BK/xqe2CzMF8YSzJAtGn9UM+fWCDTYta+GRjodDqyYKK4MbrM2Y4QMLhsPIxKj+Q/ejxJDDxGGTIhR8jTQGhp8KNeVS0eHa+EYukmbIdIdKCLwDlVRHeNMladw4cE84uobG3YvGolRiK2YdadZu3wzUimM88cnGOAriHew8COBT4d4+bsmIJE8SL9WEy3yCR+u8kS723AoKGwbzokUZcajU+SdqkDTQIdCR6rSTiOhHoZP+D0VRtsEjB5pT63ASHn0hFTCgDgOHYUWsCpquON6hw0mioRJRSjnGhdIHKhjYoj79g6ta1e1yeMAZKU39owOytCLoR/ET/aKCbD4K7QHAIr65M7qYWkTS9NGGT8gUY+bfkkdgQLoVkMIhEaksBYwkArKQ0D/dInfl2GuP+rRxYHp8K1nvZStGtAtNrUNypMJTnHIJ53bR9WL46EGVEFKhF46RbGbTnQii6wN0MQ7PN4CEy8miK7UGHuLgzCLxryfMP0hPFULNg4iM+Ib3iYDyMJq0F09qQr73VwDjjou32rzZcCAzYp+bzpnfEAJ5SP74D8TcZizamVRQwVRYIlUMUeRDr45rVDa761Mv4KK12Pb6qWl78DBnhinZuXtuv5tE6heqMJOfvmiY0sVeyxULPA28L54F7PxwK+YxVBl8xDVvgGCKFBqGA7NsDtU9PCQHPa9Wly2nC0sEERG/GKrmyxUZd0ihN/agj1jd1DoeAcBhiKnSFcEc4LHGngS9MUiozDYQjQrx7NrBRGOa6T/9XyXNpA89p/cD1aK5UeAqvf4tPp02QSbMfCjkPbvh8nTrPB3iIngP2+YeCS9jVtOcXdbG9fvwHWhO79ZIngcxC0vSGpyXo9zaKKty52rDAKyppIti5QzxfKj0O0JqK1xqFlFeWPNxhKlsyMcBcnuYl4cTj0BiivRqSRmDiiP9P6agjrjgIurBpPwkdF7AJJ2BIIAT7hjlidjTDzKD9DGKXqlV5xpRyaSnXzZJ4BCEisWizWdWHAp9iJYIgKP/DWHwrhHFy5Umni0zKB6kpcqWOqSmLo2jeudCQ2fQ2Icor6BgkJTv4xzCuPx3WMMjZFgKAqYtZ1Bq44rGM6hFckOMpI52cmct+QRqjPJ9dK82thjwTsTO7Be9dfq0FG3Ljy7CAAUQN1ISJLxJZr6Viu9W2+OMFoX/pMe4s9LQjOnQMmxW2/ui5ejNVxez0byQam8LVN0izXB4+Raj8mohIhwGTh5KOMpwzt4OJNKznRgZK9VlSsZYrDysbUqm3SPgpF7V3rHFnRNShJmsijxJBHjT+txDPUlgjdrevCSAloDwbCD49GPH4w0ZYwNBMNL0ZawS2D7RQoMDWsmjZw8lWm18k83P/7U1tOHvD7aBcpfUsIn0gQGrWjDhU1fUBXAjTcX9yDTvQ4g7pMofvUotaJEGlAT1whSvtFrhLFn6FSFORSvEe0S7feHmPsUdhQKmWZCBuco9ntqkMjsby88NU9oH5mDWvpohTpWX33ki+yPsaoRQ2l1eW8v6bWBn2RYUtipTjmKxIABbN4RB/H70gTqBbK5i9glhEHuV7BOetZeiBk3BdiMC9gWz0Vzws+CL4vK4DuH0u80Gd7U9Zlsa9gNs3e9a/4S0ZFoaApWLMfrQ63fhYtDQQVPnF5hMyiPdjIC42uvP5KAgaf9SpjY8iHRRu+BBGAhrLFTxBuM5SiblSRtwdem7Y1v/TauIe8BnkQ+/Fn/K1pL7UdJYvUATTk+D2KGuO1A7ctxXhRzxbfd4qaoAa+UUjYggoqo7DVODa4GJHVONt16d47dZSCdyVKmUbsUvghqrjtASlBXagAcJu2lz8zURrU7cb9nHZAYhROsF08MCigZFIIXHEGhZVxqfUAll3oiyeFLjof4gJ9WJHmg1AlojwDTPCuhRvCZYnNcjAhj3qOgP+gGHbuuoguKDiLs6nwInfWtRzb6oIIjaV23GD0m4ikCGDQuKL86Ti42RWDJ+rsmkDcuDeAp4BqQ6InpkCHiCL3MT/ZPYbdsDscyPNEzNF3uyxv7jBhV4zhVZvHQv/Qc89QWCDBhJuqOwb2J3RZAMT3cY9J547EYaBPefa95dmn1/HjBBDw+eW5WN85MCL9HAFK8UMdBJeQAdVUfZPfqciPxr2zAn0B3oznbggKBbCPbin8Fb6PwHEjuLIAE50rknU9oG0PGadHWwxx6V0IP2YCZOkPXDrgZEcuomMH98WnwFzPedYVmCUMsye3NYU/IGBkhv0N7a+Xl1vEbk8sBEPsa9jQQZ0bBvbqwaYhw10p8gS1hTts/3yIAfHONiWzBrYky9p8XwXDY3vaborvsyIDYABXIeD4UPaAQ4LIJSRLsQcMe8XHATfNtPnBhgl+AA5fwp74gtExNACs3RZAw8DvyNa4OV5/fAqT45PIemKxHq4ZhnRWCRmBPP2vFNnOtziylpKM1TYhFIIRHqFHFGSAjVnoQOMDWOITzJwMzWjgNjRZGypcLMjBBIjE8VBORu69ElVeydiE4RoglaS4wNPBIwwWHgEil+LOKAp2I3YMsMmyJ1fAsTdRhRzSuh8JxocLizr050hrCYloa7fBL6k9GZ4AqFgVD+UM43/ivgegVsRlNeLuA3+iQYHBDhxGdgn8JihlhQAj0N9UfPF2RgeZBSQWsXEDVg9rB8ojJ8AH/U3uFfRiei0vYP2hdgNAiQLI3QUOgNEtvHqV53kN9F4gZocjdMx587E8ljd7PpoadHogrgGPmeoCcYwykan8ccTUyS0v8ghigkALsIjTbj/TcHDSfMmFQe7inxjpExETBHuG5f0icAdyi+cj6iiDi82QDF4iFTRre0Zq0/cIEtr/S9Hjodq4ffyP1eJaGv9tPim1/3/WSbf/fyg+cIf4H5WNNP7bXFKi/X+puFFaf7We2v8//WQ8GNWHaQr9w2o/6v9XTv3/5pLmE/+D3wUXKsp0C2ces793neHh3+lIl44m6GCRspOmxIPNF9nFk5pVqVboHA93PbhjP6O47oYeTUTp1X7CnPnAzYd6tZ/nEVSEbldpHhwc8YAieeMTQoaIexKxtgIfQ7rGa1w8jjBLGIwDN2rJtajSs41dLIoHL6q0p3Y03oZQyVGFLB+E/uUTOqW9l5E4tmFfbbBYLI/fmoQedcL9n24i/hBt3N7/e3V9NY3/OJ+U7v+eddL3fw/FB27v/11ZraTxH+eSxvh/l19ugAye7v+efDIejOrDNIX+1zYq6/H1fy1d/+eT5hrrEY0Ok10BHwAMtInim0l71gCJUCw5MmJmAT7tkrE2ogvZzpBR7QKdawsvSn6EbJ85LjrrnFwrd/f77h2vkDXrf37baNa3mXgnfBvxGJT7m3AnZ2S+uG+m7oo8dfQhHni2bwlPmlxGGDi8OWgdVcOCYbV4Gkqm5cryBf0JI37zEZd57Pa+ZXXJqALdV/rDPstilqxwtyTfSc++xCNjKkrb++xgeNKzO22ek/LQCyOjm2BUI08tNSbcP46hwxMPX8eWlpPt3XJMIAp3WDvYrys/Jpw75RsrbYGU9YFwkSVv33w+L/0qSpvJXouQBTIqLzR+rB9zQ5vsjJhZGHF7rMYaL2+OOitSw2PdFfVK486KVdPOk7LA9K7zQZAf+nk82i0nlRkD0OpmxHMxERbluwj1Ks/FqmgsL95GPBir/N2IA2M4/ejopk28ssicx7xrnoh80hPneJJTYWYh6iE4dppFU9RMos9hNfZeVTj6+vt6s4UDXy6WK/niWr5Yyg8869K2rrD1PRjCXtx/7WwQ5Cs57rQFnJVMmzh/6apwISuMW8BRXj4T4sFY5Y+AEeSXuAf/363SJx5vVDolWqcwUBhQc5y/YW6T9dyrFcbdFYl9oJdiJubvWOXfR/hmLA6GtDMMY2FwTDlAQwhABcAWm1sAItPnQKhwIcpcmZfktkncqYowJsHRm7vMABfNRPzeqgpTPLcb8fzOxHzhFNofHOK1g7VduRIIK6IEr0jkyo1TaTYUsxMiA5G4iRD6HiSbCAkLIehfsg9kNdHLMZNgylQdfSn8NEe/SIdMvuRxx8ilIZoQj/OKZN0h/RPwa557nI5hxYv4WVJ9dfKHhNGxT+2OcOW/tM3Qe5LWO1iqAqARF9dBue6h/2Qm7nhZDd+8bh7stet7tcZu1XFRg9q7/qOaVzGNPJ4vhmc5sc7xklu8zt6DuunWU4wBLJhXGClYPPjqSUYLrpbKG0YR/iutkIKdgtaOyn+o/0OEfUgZ8/b2H+XyWnr+M5+U6v+eddL1fw/FB25v/7G6sZHGf5xLGmP/8bKysb6a6v+efhLOqA/axjT6Lxbj9A8coZze/zePJObfaGNEvAvLGjxAG3c4/91Y20jlv7mkVP571knQv3YIfP98YCr9Fzfi57+V4moq/80jlV+Nkf8qL9dS8e/pJ7n+P9zqP53+R+W/1Uo5vf9vLkm//9toj0SK4FdZ0QnK3duYXf7D+7+LDBeEUqr/m09K5b9nnXT6D4XA++UDU+lf6f8k/ZfX1lL931zSiP7vVdkoV9bX19ZfllL939NPOv0/zOo/lf7XV8tx+i9Wiqn8N5f0AL5eMlhbPYylgoZ/I9ejUjSRB7D8owh3lq/CRSlnMi3WnQpHnBAIagXqENfOYDCNSPA50R9uNYJ1JvfKIINBFbcbDQ8vTc/fZLrR2gqLmH3oj/w7mSOOpK9Umz33zHbYEoa84a3zNzlqfEvdoIFg/mHrbevoYK/xl/o3MnwbXetCNhOxwMX3b6/Ig84qthIOpOAwmdEItVsUxSgEKhaGVoR55e52X4sn6z2aYbCjvcPtRlO75zToD2QWdZX0Is+lhYkVIezo36EjC0jfuy7Ljmb1vQ7tnHUHvFg7I4W+VnmgoAjWlMcLawPLq5703JNNB19JG6DFDzrK3PxRPaOd5g1Wym01MRCfbAJBSugYQBs2Li4Sp+YxiAwGWeoyf0i2nRja8DobhTS/lVwlO+tg/N5hoHpm9Xwr1s4ska1k8VNbVURlqTe8DN7PTdESYTrGz4a6DPoa49p95L8dF2991vCLRyqKhoVLRjJplrUYIVftIxr6LMaIV3ymON5VYTcXi4E8OQieDGScpxfEyfj1RJDZN85+6RmB1UdbQkvlxGvEVUzyqhiWyFctAnl17137T41mTQZrjOSj2D/VUrGo3oqQW+PIhYNmIGg8zjKWkmGcE2IyTyk9OlHIpL8lJo3RyoHuk+cqifaTh31C3EDVaR6A91Z9nmWs/CurTQuOajReA0VgI8/mRDS/5eiOb08b522rOxz00OjNYkemf+HfdYDzfTK0841uWGM7UDXOMK7Tx+cOI9wmcKzuHUaaLtm2oHPAIH8Zoof8J49/DBptHpLEpyWx4ueS5ySMtj19km5lqcmLqPDOVbFa89cYz7X6Ujw0jurNakkrcFRrfdeqfvIEYVXoBZ5QUzg7mOng7dH41lSE50gHKEqsHtUVzTD//rd/53+YkpjCdyTT8Xi4FGzd7YEIhSuYEKnENS5kPSs9T7hTSWSdZiL9/X/+R8QpAz6Zjgz9K+KHmp0+RnL2BjlZD0U9iFUQv3VCFMYYcJbTzZsDmxeP8fxIHaP3UGAJsXTFG9Tvo+AtykspsqJElrcIawgLE5bHyymcYf8Eo4ifRq+pwAIvGYsVCDOr2MGaKC7CCLMlxMdcqke4ZRqj/49G6P7ENm5v/7GR2n/MK6X6/2edpuj/74UPzK7/F/RfLq1tVFL9/zxSsv3vy43yxstyJdX/P/mUqP+/19V/uv9/aaMSX/8ra+n973NJD6D/H3u5HL9YPowk/gC6/9aFPfA1X0seex7bpZDjJl6IkVe3Y4Saf+1mOwwdDzXR5cq01RPB3GljqQdyn0XFP06Fz0dB+R1rQQjYEl6+rkcgyOntkF8pXYzGN/akaaEdM1uKH2R8tgcByF+0QwDuDJyeAaRnAPM9A0hUtRFl/taKNk4R/O3t9Gz8GjmNLTyMIk0H8LPWo91Ca0ZZdYaqZZ1wFaq85pXG6z5UWAuR4duuHdXY64PmXu0oMoDaPa3Ra1mT1ipGVwLGb0fF9XL6/aibTLsZdYUGjd/IJm5FxTVu5FbUFXZuO4HfDqz38JtuRF1h4e2o4nLU31r4SdMY/d+ku+1u38at9X/lcqWYxv+aT0r1f886Tdb/3Q8fuL3+b61cTuN/ziUl6/9evVxbLb9M7X+ffkrS/93v6j+N/kuV4kac/oH80/O/uaQHML/Fe21pG9sy+l2KXKfuM45EAn1YTWDd6eKFBZbTDeOboWqP7yPx0mR+66O8SIJel41k62GlUKRcq4a8VjbRfpjyrBmshVc6483reHGpdtOzFfiUpWLghRd+ooEx/JGZKe+6yGsHdHXvpaWNcOTGaCyIbdFVnVbAllbFJdLcHGPDkMoO6CLdqk5fo+09oOnyLfWen6X6cgx7TBWYqQIzNWJOjZhTI2ZRQ2rE/GyNmEn0YUck9BwBr5vxOCUcfITA8KmWu0PENir318k8iVXRgb9jRTAgM9p949hhkOXHex51t3EJ6/v0MyvaYPhtQIJpp1bhZNSwDEjcGMM5soFpkrRcgplBbPj8p6YsHr6ttertyJtPnawRapjfbJm9yGRpBBNOz6MgnNXnRjjlR0M4a8+RcMqPhXAqz41wVh8N4aw/R8JZfSyEs/FECOfzMTBKHfVUgU+wcgK0OHx71IrNIL92ZOTCkTiaFPjUoW68XSowOlxIUqovSRV3LsxfFvkjSnRPiJFfhbr0sJqw7KooqzUhSyY1tTa+qfK0pirjmionNrU+vqnVaU1tjGtqVW/qtz63StP9pAn+n/cU/em28R83MP4TZEzPf+eSUvuvZ51m8P/8ZD4wu/2XpH/4vZbaf80jjcZ/fGWQ/91GeX0jtf968mms/+e9rf7T/T/LxRj9lyBbuv7PJc3d/3NuYSAfiyvo9GiOT9v7Mw0BmVpPfT7un48/0tqcPEAfTyi11AU0dQFN05g0s/9nzxx277gduIP/5/rqair/zyWl+r9nnW7t/3kHPnAH/8/V9VKq/5tHGuP/WX65Xiqtp/q/J59m9P/8hNV/uv9nqbQRX//Xyun9b3NJv6X/JyEVuQSmXqDPywuUz/yTcwOlbqWazFSTmfqBpn6gqR+oqCH1A039QFM/0KfhB8olHP76MTuC6v14Mp6gkyfnUbuCjp2vx+QLOnl+Ho8z6H0Rz2flDTp5ch61O+idiedz8gedPD+PxyH0vojns/IInTw5j9ol9M7E8zn5hE6en8fjFDqFeD4fm6PUK1QV+C28QglPUrfQ1C00TVPSGP9PQSafePAr0u3tv4ob5TT+73xSav/1rNMU/8974QO3t/8qr1XS+z/nkpLtvzbWSi831tZS+68nnxL9P+919Z9K/+ur5ZH1v1JK1/+5pAfw/0w4wJqXuVei2Rbu9ZXp1grrTDDaQoslE/Y0HlpZmYm7xaGPOySsc6RDs/mBPmujKcVa9Os/U7Op1GwqNZtKzaZSs6nUbCo1mxp7MTEtk5/5UdL9WAA96M3F6RnSEz9D+q23VI8qTYj/eE+7/zvp/0vFcrr/n0tK9f/POs0Q//GT+cDt9f+l9dViqv+fR0rW/79cK66uV16l+v8nn8bGf7y31X+G+I9x+i9trK+n8V/mkuYe/3EexwCPJfTjbVX6TzsQZHoOkJ4DfD6BIB+9um1OcSAfjz4tjQOZxoFMUyxNs//F+5U+dRNwB/1fZSON/zSflOr/nnWa1f73U/jAHex/V8vlVP83jzTG/hf+VDbS+1+efpps/3sfq/8M9r+lUnz9p/iv6fr/8GmO9r+ITE/D8vdgYDm1ht6jBzb9pYaeoOUvXfKbKvxShV9q+Jsa/qaGv7yG1PA3NfyNnETgKvmbH0TQUs3fPkqzXw3+z/qUIrX6VQVSq980pSlNaXq49P8BGyTF2wC+AQA=
