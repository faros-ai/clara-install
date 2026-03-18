#!/usr/bin/env bash
# =============================================================================
# Clara Timemachine — Installer
# =============================================================================
# Usage:
#   curl -fsSL -H "Authorization: token $CLARA_TOKEN" \
#     https://raw.githubusercontent.com/faros-ai/clara/main/customer-deploy/install.sh \
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
  echo "    https://raw.githubusercontent.com/faros-ai/clara/main/customer-deploy/install.sh \\"
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
H4sIAC4JumkAA+1923LbSLKgz4nY2D3c57PPNZRimlSL4J206FGfoSXa5rRtaUi5PR63DwmRkIgxCLABUDa73RuzL/sBJ2YjNmIf94f2G/pLNjOrABQulERbpG0JFe4WAdS9MrMyszKzlIFyb92pVCo163VGfxv8b6lS43/57yor18v1Rq1Uq9XLrFQuVyvVe6y09p5BmjuuakNXbMu8NB9kOzu75DsfCvP/fi3pP/23/3zvn+/de6aO2FGf/YWJhO/u/Qv8V4H/foL/8Pn/Xq/K9slJT/zEEv8b/vuvkSz/FLz/15E1VdTZzNCUmW1daKZqjrR7//TP9/7ff9n+j3/9P//yv25gkGlalo7V9080dazZxdHctjXTHev2TbdxJf6XSxH8r0OBe+z9TXckKd1x/K+W2NTVp9p+udmsNvf2mpWy0qjVa5VGo1zJ1Jvsafdhu3fwpPtDR3mvuq6tJKHrfvvP3Xapff727eTl6cFfX2Rqe6wPhZ6+uqyQhOOZzz0PdzUpxfW3cRX+I75E9v9yo3yP1dfftTuP/0pRGTiaO58pzmRdbazA/1VLsBeUytVSo5LyfxtJKf93p5NSDDjAddGBFfg/gf+1RrmU8n+bSBH+7/5epaTcr9VhUZrVvZT/u/VJWRvWB+ly/K+Was16BP8rjXoz3f83kbZ+V5w7dvFUN4uaecFOVWeS2WL7N5mgvgNDtVV2AnRmqo4muqmx3/7+D9Y1Xc1WR65+obE+QiF7qf+s2mMo8FI13jpsYc2ZO7Gt+fmEjSzzTD+f27p5ju9tpmB/z3RDY46rzdjpgv4qUPiFo55rLRaA9o2PCCpmBW1usZk+085U3chkOs9/GDzqPu3sZ7Fj2Qy0+ds//g7/2BPNmGm2Ix6/9n+ZzAzWwB1MiGfI5dkvGca00cRi2az/67d//I9b9i8YG2Pb5ds90l+9NUaEWrrCBNvbZQHWVGqLHdvWdOayM8tmKrtQjbmmsLZ97rTYjL7swktbV08NbWCqU22XjQF95obLctbM1S1TNfK7zNFGtia/yqjOW9EPwxqphqhsPwsrgRVSXfBUyXr1wcMv1Vbh16yoDJ9r+OxXQZ3LwKN+xl6/ZgWTZbdF4Sx78+YBEB7NzKAo5DfGf7DXXr43WNuZHlSS3eatZYHcsKz3O1SZDWjDCkANCjPm1dhiWdEdzCFmmrEtZmrvDCSW6hkQSjbRx2PNZLo5m7u4DoajyVUuq5F3kJ5wFuhHq+CNgWZEg5dQ1p/JH7M/blO+H7NJ6wod1EdXLSxfvLL3o7LLFEXJQFHL0a63lpDDmehnLqv4eXldzn4uu/3HbN5/TSPk8yYmgFYGOqvDdMHLX34nSr7+45tfsw/Y2JKmGhA6l9PZt6ycz+fZ9i9e1m39Dc3O2DIJUHhbfPDw+G6Ce49rzzW/PnklOri5idzsdbmw/cuW1Ic3uEJ+VQH88FcAP/+d/fvrUmHvzbfbAD/s979nuZxX2Xf7rIxvxOMf9lm4bpbPSwCXvLrBIHM5UU8Bx//m1x8Jyflo3LnNKwEYCuara0KF+tgHg2NDUx2NaTRglZnz6Sn8ONXcdxqAa5mp5jjSQ8WfVgKuV5pTNC0BCNelF4uiSXRhsDA/ijSYEi1YmANgSlwJj31KgIi8CHDYy7qfff2qaL4BUEI0lN4uis/xLUc6XrtqOu80O5OIqGxbFEV48DPyH9hR/iuCriOc7uw2/5YFCKfFeb149WYnH1tt6PyDB5QBPiaBgykyaI464uvx0tZdIDqMaI9r4cCZx2xl4McAP4T2BZzs776Dvx4XJMiG2CWeqYCFn51zWScfxLJxFldmabMZbwPlf08musPe0Sf4YxhsAkwi8buwZ6g0+8TfelyvirhDC6B4VbzCzKoJUFWw57AtuEyFf+aCoTiPy2ZrXmkslBH73Jm8SvLeFN3hX7Z7z7vPH7eYn52pBoLwgmnvdcd1CIs5BrLs0YVmvyO40d1/y7KjHzq9l73uSYdlzayEV/77LPtdGLMkAtM+tWwX+HyFvUJGn1pDtj/oCEze3BxNVPNcGyucXkEul5X4fofYt8X6INjBlmVrIACEYTOAzMe6+2R+entgU+bcWLaP/y8X6y1vnO3RSHMcD4La3msUT5DRYip9B+B5i4yGAyD001y3tTGC08gAgg1vZpaju5ata44PigccZvG7CpRs4rozp1UsnuvuZH6Kuh+UxHAJnSJV7bCcqWljh32D1X3DnJE10/IBjiBdZ1nROSqRZY+7J09ePBycHH3feY7skcdeZfg+jKD9MyyynI0DF+3NvGa5Rnl4HiRfu03OEnikkGW3xExmpXdy4f1wv/j42uOxzhlcJmYFOZYZkBHD0JDX0Tjaw2zBFE7VgqPhR1cbA1MFGW1cKs5mELbPYVdAUu2ohP9QYz48hH50fpb0th/ubl/OJyNP+xz2fCBzhjYi8vTZof9TUaWCqMJHdSATXh/OicY789kMCBSgyTvACmuMpEnFQg4RLCLKPuUlpIDVOrXciSJB+It+Z3DwtP3isLNv8oejw85f4LdgkYH+TvTRhFecc/J8l8ANApYZCGz7cef5yeDgyVH3oMN+BPDFzs3HGnR8jI0aQFr5a3h+L794CD1hcmbkzygXdEuwFnLtgsGI159n0iAWnImQm8uLo6RgdCLTjvdFSnJVD6JFiDUJ4E70BGSSCx333s8OSivCnbcZBmOO8ZkZFDuj0Km2QuvmjT8rbd7IHQr4eWK9A9pHICPIOi8MwMMbHRz3jn7oHnZ6BBewdodAC0cua5uoc5vpI9Y+7rKco09nhua4pLL729xBJoO+vNUW+axXtv0zAnu7yx5Zc3NsL4IPL/vsoTa2rdFb6p5MNKXRSHxtpHc+g5vYv+xOXogrnKaG+g49BEx5fvKkd3TcPRjAq8H3nVchSs7LhveQWAlpIxEiFd8/eROxneTT+0P7i2jKn69Ywf2EnopSguWPL4s/XUG9Yr4R3wYIko+OXjw/7L3aL2flmRUVwEgdYMpAXkThQR6NKDbodfpHL3pAlbKqXjjDUqq9KLhuYe4UQFB0K9lLRhatRB5i9Fti9xKm2Su3+vJHSn48GHxS764AhkgFSTO2DDgk1LwGXDzsHPaODr6PwAVWYmvnuEsy+A2r87h7BNySWO1COWG5/WzQWf93rFZBtXBqu4e88vbBQaffx7EMuocJUxVuI5SbNxV6FWtRKB6Dhnmr/c5Br3Milb2y5VgJ3nrsdWhFaJeTa8oKQcbb9mhr/Up3vfjGh9v79fa901Zk7Nfe8Y5mmtnu4o6HrS3b8Hiu1Xc7Xi6+q3FeKtjPQm3HtrOg9cheJnWLQPHouPO83b02GQtn/3jatXI3EulVuNR+tHeJ25aY38gOL32C+sczC8AF8PSvL3qdgai18/zw+Kj7/CSOm0m5ADeTXmeXthpQcbnctbeXhEKfwGB8SseSd5aEsvvJvY5RLwkZOcbasAdYJkpI2hlIt66Hib1Ou3+E6iUPowzrHXRvqo31+RR+TPTzSTaEV5Fy+9uRF9nLSOeh6qqsz/mWz04HP4GAxmhjFSVWaXSShBnIkRpACImPLoLMGHOPrKnGzmxrCrTxsH3SHgiejSTER6ptOZwcnmnuaKI57LjHy6lz15qCTDxSDcOjh9mHdChPurqjdybvTm5mqDDZf4LFeUp6SwdPYrCOYj4b7ARS23wv8NvO7oSUkxJ9DbJ4Wpugwy96T7PsUbt31CcghUeAJaGOGmsXijrTlTPMrah6GGJChfa3Q48JDQkNUZAtriSKIn4kbwjnA3yP695QK8QbpiXg7LegAx/TK4H1SUMXyqpoTy9DrWdPzwB3v2KsuhrJaohkYpwntjp6i+AenE57OCdyuJjDYdr7mWbrU9QlTTXX1keOwk4mGlmM0ES+s+y3eAbgTqy5y3RXCes/Sat+4KuR5MqheUDbfufkxfHg2dNHT49ekpbdwyn5QxKDJeMSr9aHb9GK1Hcu5fHKBp2/HHd63WeoG3refgYS3ggVYgM8UZpzVWVxfhah28lF97eT30d74o0XELvrd+Ok1z74Hkg+oGY3qS35u9+Q/DLaytzRbBwoLGpMr+q81Wf5hKb7nR52OBMyIFiWK3rMsbzHokBCt72qArwXvZ+pjgPANI538rjd77886sUlpeUd8IrEO+B9EUYPl5CEI4EZrK/ZFzow4l8NdUhA/jrphANVvT+mOAFIRNzH2lQ3daLOSMhpC/5prhq6u8BzD1tG5sedZ93n3QRk5h+SkJmfWgRtEPvHsy9h/EKnFlQw/DZceH87/Jy0F8QH3QfG/LGt871Lm6q6wUzL1c+AbyAy4Y+4D9z24x7K8rExe5+WjtpvxB+3V2TJyPlmCUyP6JI6HiOuS+Ue9Y6eDTrP2l1gG0yrYGszY/HHZH5hyx9k+H20D/vb0TdL8gdtS0WCl5duwv35dKrai68Gz66Hhd7ROj9IP7BQMne16FF66KSG4Rm0CwyUa0kH19EidMTjBIc041b2mkp5z2KoENLE56I66zytz7XUHVKNJDHlIvoCXpVPYPiPw4ARhGHKTHSQEwB0fn6Oqox3dJLkMx6wqcGGJzKKPMBmmtp7l0xonVZQy6p8+vVmMRj1FuvNTaai3THvXMBLEGskprmVDZUazfzROEXtvYqAUfCqKIyoiLJQp4aUbbooeA/0KRvpRwcoPItmIi0QUgGUZeCjZZ/v4l88tt5lz17hKv2pc3ASrkwp2nNTcSbXbN3fUK8FL6vMHQLUalOHJb66mROWkF4lZTRJw2bJTLz/slM41UxAgEAWRVEUT8pJHGVj0sNZ9iL7EQBcUZZM6cIafxQkso+a0lgdG4LBy4e/OjR91tHjlspfPAK25WxuGCArj+YoBxFWoWWyxnqd9uGzjjKFff9zO2/cQEL/X3+S1tTGCv6/lTp8KJWr1XLq/7uZlPr/3ukk+/+uiw6s4P8r8L9eqqX+vxtJUf/fZq2k1GqNevV+834a/+X2JyXA+rVFglkh/ou3/wMFSOO/bCIh/8d55fW1sQL/Vy43G+j/Xa+VU/5vIynl/+50kvm/ddGBK/G/1Izgf62Sxv/bTKrshfk/mHuljPH/SpWU/bsDSVkb1gfpCvwH9I/t/9VKGv9lI+lzxX859k6jenPT1Gw5aotQ3f4hpK79bhMxXI67x52n3eedwav2s6fofl1u/dsV3fo1m+k+az/uYO6Dp+1ee0CPrQKdGqt6kUxkWobqag56b9OJGvsd+uGSg2/0ILBj25bdkoLbmBaGXZib3PLTO/KcLSiLIvTteKZHRdCX6wxN/XSTH3+MbG2sma6uGk5LjmEymoUr4EFrhBttmVThQU+z26GZyS7rtb+o4Z63WKR8uB1eBcIBGvp40xsvJKIPTGk9tmmavZdHc3c2d4OTHPiem70b54sWfZBORcfW6K1mM/SYLhTsKRkwFgpk/EMr5R8SiC8wLQUaDU0vfzeFQbnMXcy0fcCb8S4/iAUICLW5C3TlXHP3i1PTLZLl3rVKY8542SJF/biyBltTjZnqTmIrlk+oMgTIu+jZjW573KRTTC89LCmR7tm3IaH8759orakN2A8btdo14/9Xmmn8t02mVP6/00mW/9dFB67Efzn+P+F/rVZK5f+NpFj8/1JV2avWmpVGo1lNFQC3Pilrw/ogXY7/lXKzUo/u/7V6av+xkbQsNusBzIs1BUnpUJsZ1oJ8QR7P9bGWyaDVIRX6xqFYU14xX3KyhOxpvTOZ93HuoHB3SNKXkslsYUhBjVycHB1E40ymwHZ2+OedHZBeYboNQxuTQGsL0TD3Wrxn59iTNznfs8saOQqX7CjaEMg5Bf5YzOepZjmuD9RP5pFDNB0b8uBDLIeW6hjiyI8vK0c64pXwyDCSRA014VypLsMQeC6P9XLWQiENsksWwjs7LRYLBcFyXF7N77JomAYK8CO553s1okEd1hX29/QrolKSQyj1OuIdBn3OgWTP14N/8/0SSErFEaGdG/fiYG12qhnWuzytWZfPP1nD4YstdmRqBVp0b2lyGHZsCvAy1sZQiLwCeTMjy3TVkctdEWfclZupbMjVJuRpNmQ59fKgVLRyFEjPf02mnByK/TVb5AHIhsMh6bNGc9tghTOn/5QVnrBse+5OYFV/plG0RL3bUi+42OsBl62+U3gkK3QTwkHA6hOYkYqn4Ol4ilNVN4sjgTeFMeFNUUwLao5IeLdY0Z3OeImC9PH3vyfdW/JXHEkmQzHjeHg4B+eN55IwsDgMNCC7bDY3DIfmhqMV01FzsksYBZBpkl8nftalMMwUMVkEplP4CrcNF72j8HOLDc8nQ3bwtJvJdM/I0X6iXvCoU6/FssHHADFHhq5IUcDy6D86QeQZYRgrvpjL1rEVLOA5LjmPMjkGomJYGEeRLD9ZeA0wtKI0qYVDms/w5EanFcf4TDXnGEeUf/IHB3OpwbDHYpo4TbKBYtj6zNM2GQupo9RKvAH257k+essD0mUybYrmqkuoRGtCUy/VNRqz2AqjVX9ZYQfctVcNSC5WwEFP/xlD8LHcDFvkBshIFsgWlwfTNN185iYs6DOfaPq9yzR3hECGVsSwqWSuYbWLuas4ARqMztacueE6GQBzrnMr8gn/DqieWFHS2tHMItkUyzqztbPAuY8Wl0P8LkzTbMGGsmZ0iPnozZBmGRCHyJtbJD0rBVzj8c94vHIMbMc9PUV4Ryw05b0BDti2VEI8+DGej6SAbaIJCvFIMNMxL3RgSmjn/UEEQYV9EvYyzQR8NVo7O5nMB/8T+8B6nsfwB9i1OZAicH3IfCj4KfknPkFdQzns2xCqeQU9/eAR5OP2ScLGGSvXDwoehMPWXRXmjqoKOV5jVXzz8EHCf4M7mhf/geU05VzZZcNlvt7DfLR2f4yX1c/3hg8466GIacgI4EaKIxnuyPgyDGrKEyIIN/ydHWAOoIjY9+wWrp0fyyVYRueai5eweonhu2DMsSBROOq+F+eEx8hnjzHuDTETwM28hl3OsQAQVa8uJN8SWU/6XORTHGVlsAdLI0wNd+XuRQM8JX+VBtEDtNf8GwJ4y9SHgHNKat4PZEQN+AGIvKdQjCDvZSx0T0L70CoHFaK1MSDxvSE+P4xI/CPMTziqx9XQAZTdhUFNFcBdU9XDsJHwsQiYWIDCjgwhogsIn0nRV2jeE2KOLF/2m6aFkfgi2PBzi2r2QpoY2oVmAE8E7DF2lwcvARZWxGrOIz3SkWEiIWE2M3SN+ByMBekvssNhxvOZjlP1a6206HOCrzv2WziKA/t6AYCEQTHILzfw8vfd7JNrEa7nUlW+x3xiAc9VXCrgOamHCkSc/zF7Jxx6wJ/MluB3o8EGPMIe9lLGmsJO0RwNk7yvRQVRL11Cg4iHMa+EOw/jHmi7BNK4W0sxWBwhGQn5qRXsJ8jDS3LyT3MNhUtJChNhVnZ5rHEgs7BeroP8HIBN4MmG+KW6CkaYjm2YyG7EtzndFAwG5//nYe7R0N8CA3IZGzhEHjIhR0DTgGnpcq86v1o8edwN2NIWiKPEOlDccY4VYUl7wdccOktTgvkBTf4GFGsAAr9UQuzZ/Bt70T3ErI977eMnsUzntjqbsNzcmWPIGjYU8DREkX5o6FPd5UWm6nuYfsJPCnoTWsSHLZYY5Obhq6NDEHIT3Q35IkW8Dod0jjr0F2G4zF8wMuFhd7ohZzB5pQ6j82AgdcAIcSGKJG1YARvJ9TByiFzEpeqovkMkLZUzsebGGER9AItgCIQuJKiYI43zfme6ZowdghhASe/bAFZnV/CF8BfhY4BsMkzuLq0hkLLpAPK6GqI2vVRhkvEHGkYMvCchEWwFpgQIRMBL4FzCRPtcmmqLTzy2EJckoVuohTkTbswkS5HUgGDVkgUV5qetIFzFWHdg9+JAmBFVoOKFl6ZoEEdS0S32ZA6MfQG1EUSrKWoEFcbPFLMZjR++Y3LaYv2JBoKD+EyhmzF8u+mgOiS0eiK81mzhTgAGHWuqDfhWoICQUiio9rl0bQiXgJwWY5Hm/J1FTJWLagTqqpBBHNFOQTrp56KV8jfY6QwuVO3sfA8E8FQDgV+3bIf2KVQv9SDnVD3VkaQKGQvVQLwtXA8CTDYU/RuGg8jvcgEIe4O9AnFshuJTj8e094Uj2XcduyaCV7F3FNtKR/3bGS78mSJUXrqBTMEEJhiKnWO/QpQXKNLMQT2lS2hkO9zzHR4BYdA0xYco0zILP2s2BXrWeO0vLZv2Sl/XgtUf8OV0aDGpb0OhFpLE92HiMivsBVICkPcVBbe0ByRyCrXIi0dPgDQBeebmGw7vgiQbkmrRMPx7MhzRupBYYRbUC5gOAlDRugA9Ryh4jtFghPYak7ZV5D+eWDAlZEmCUpxHTcSL47k9Q341xI1E2BH5mfZXRdjFFHFjlWgSPvrILoCE5VD5R7AjdmclyBynZ9hHT13N7WRIkYnWMOMC2bQAABKpFpt1Rxg9+eREEEQfPjA8GgUswxDfQmni0DaBKl7cqSPqXSLo0jeuqCUyvQBAOUN9g9cTXPwhrOuAomwPmYiNz6uIGDIFEcURrohx5KHG4Y+K1DfAERrz6cLXlms4ItF35sngxuKBP8kIG0G4DD+L3ziyJrmht9cP+OYEs33hMOktjrQoKHceiBR2aIExxr5xYRoNQ0e0gSV8pBM3y3XoS7jaD4mgRABwOXPywQvHAe3g5k07OeGBz3vthuMksCW1SkLaBxGR42PrjO3oUi+Jmyggx1DAUxLaia9RW2LvVq4LPdsLGL1oKpTgyycTfeADi7wgCt0uigy6WXRJSATJBih5lcl1Mhvlf+fKlpMn/CbaRUw/EMwnIoSE7ahDRU0f4JXoGsoXN6ATHWZQlyl0n/T/iWWg9E4bNeITV4iSvMhVovgzUIoCX1pVWHtMoWeHfzp62AeB0leWYcw4oIx5Wt2xf9AmtpdvHD86t5OpYS1j5CJtbWpd8E0WkN4hDaU2Fsp9f2+QNxmWEzvFkO9I0ClYxRP6uFwiTcBaKFt4C6uMMMj1Cua5EQpUgnIhy5nIBMGHc1Jt4gdB970KYPhDDy7k1W55dWnsW1hN1Vj8jL9EPRreoEY1O+HqUPTTaGugXuFTcM3MzAZBXmh0vfB8Xsfgs1xlZA75tEjTl8AC0FT2+QnCKlMp6kYV+WBmD0is+ckYoAy5AH4Qx/Fn/C1pLyWJkoXqABwyHTRJxppca+Cx8aKeAy53ipqgBi4oJIigAsseznWDrsHAzYgMdNlTi0KEhs+Jko56RDR5OswRWly6ZU63C+cqcoMY9cpjdpy8dECiFE+xXTwwKCJnUnQtcXKGlXGu9Qi2XRiL7TFddAbGGfqgIslue5+Q8hwgwV4I0+2L8nXCifhHPSdAf5ANm1gWggsyzuL8DXiaqe44uNRjzdS1MbDQWOqx5ca/+dfLLWhekf80TRR2xeSJOscqIDfKBvDkUm2I9EQUUEXj5R7y0/AhSMPWfAa0zpmPKQqUPbXGrKA+ZsIuGuO+9IZC/2BY58gsEGNyqo5QFFRwPIGZNwC+gzImvxsIKQyMqcB+0Gz9bBE9TgAGn18ch/VNgBDJ5whQih/qYHcJGFBNNVV5+FluTmCfF+kL0GY8d8OuZHv4Inwv1S6XI3DeqF9Z6BOdncI/E8HWQMLJr80SQTmD/mMmAJbpzKJjXnZiITiOUC6mm6R4VryHDmOReWJN8Q/YMTIj/47k652dPpHbUw27IeQaNjdR5zYCttYAoSHDrdYL1GsNJWxnAoI8FGh5xBrIkldW53IVTI9uS9IUl7NCE6AAVaHO8ak0gEICyyU4SyEDBqMS14eB0EzCD79DFxWSc5KkQSZ+CxstbGTQ4V6gqKFpcGgpJWqu2q5+BovjEMt6qjED9wyFdUwH5bGAEHgWE/USe/wQZ9aPyTT0xYSACcb+CD2iQANsTEOnAwe6JT7BynkhGRUUQ5O1oQQEpNjGvXFu2sgnI/XeDSuvUDzTzbkW7AGekhQ3eDp4hMnCI0CkUqotCbkCAgK5CQGNMAkmFHYCEhkzXRPP8h0PlWHz5p8YKaWwOoHjsEe8BXnVkxMcbN83sWgFc3kfp7LXfqasYkyH9t8eGV2XjdEq/t+VUhn9/0uV1P97Mym1/77TSbb/XhcduBL/A/tvgf+1eq2Z2n9vIkXj/5TKTaVaLu814H+N1P771idlbVgfpCvwH3b76P5faZRS+++NpM34f5OCQBL6ZYtUfks2iHM8ni0dT5GalQ5JfHNQZoNAzS8+RZWRLybSmYSKkghIH+cUrFORvcl9HcFrzFlwrUKgI3izCafyXuf4aNA7OjrhDuUF5RNcxrPbfm1FPocozy31xw6yBM7YKC8k1+KXvt7cJXpx+5ogPeymLdQLVCEruIGD8SWDkt57DtyHIHQqLOIC/rlR6KtOKP/J5q7raGMF/99KrVZB+a9RbqT0fyMplf/udJLlv3XRgRX8fwX+16u1Wir/bSJF5b/GXklpVprAhlfvl1P579YnZW1YH6Qr8L9WKzej+3+tXEr3/02kjcb6QgOqZLemNXQD7Tu4MKlfN0AWFEuOjJXZgk9PyfAUwYXsAMhAcIvO6IRHGD8O089NCx0PThe+u/NNj45XyHqdP7/o9jqHTLy71HE25OAc8m3G/j3XtDGd5KLN/HQ+ZVm6V0P4eJHDlq1foEUFFSU5PDubnxr6aMBzUh56gfUdkJsqVNjy/WglP1DvJKvIHcIy8jkxX7uw35hn1nuF/1hOHDqSORyqBE5hq8mHau/7k8edgug6WkaGeCy3k2zkk2cCoriXztHzju+8gYvsOwR6BhD+kavwCyQXx0Kh4BmTl1vJrlqQBS9t8lxv+FlmxPfmcg+szFbM12s/0nilFffQooaX+mjJlUY9tPZVvUBaBdVeFFy3IC59rySVWdKhaivkrpXYF99hC+oN7o73b5jnb8O3vfN38XvY/eVH7x5p4ROuqlnfukvuV3zRE9f4Mk+qzFbkguZlyyyaomaSb7+OvJcr7EVub2a5pV5M+RYzrHe7jDtBEX1A36dM9Npm/j1GwSIRCUK3JZL9El+KIzwZh7mG5dC5XRGSX94JP3CDbwTJS3KLB+6qQUuS4D7KDfGBuGTC1wAvcyfNRK/M9QZ0dHwCoNl+6pHk+IWqvhUBfO2eebYIEeMDMhiI2h2gQXOy3YEwO4DhLbltNdF1KpN0XWr8pXcjaeyLf1Uo7T3c2yo3d8SNxUmuVmw8pz/0zQF0ITwBCh2+chLr68QvjWQXuhq4ZNF+BluRW4Dlx33O29fQKSsTu4Uxk3TPYuyKx7snhqD+D9FknW2sYv9RruP9D5VKNbX/2ExK9X93Osn6v3XRgVXsPzj+V5v11P5jIymi/2vu7TWURrPZaJbq9fup/u/WJ+FYt9Y2rsL/UimK/5VSo5ne/7SJJNZfGWCcrreaNltDGyuc//r0v1pL+b+NpJT/u9NJ4L90CHzzdGCF81+B//Vao5Lyf5tIS/i/erNc39tL+b9bn7z9f327/9X4H+f/qvVSav+1kSTf/6oMlkQb+MQ2VuD/xP2vQIvS9d9MSvm/O51k/A+YwJulAyvwfxz/K+VaI7X/20hKvv+9vte8Xys1U/7v1icZ/9ez+19t/1eqNaP7fz29/3MzaQ2+XksDZfKLRYLgyGuw+uu/1WeOZOHB42hgu3OHbk2Y2VrBj/QThLORonRiGAyoiQLFUxgnEZiC5CQ5KMUWWciIMMNoW3ih2k6LyeZmu2RRGEvfilnwzYkkI0SWw8s3ZAvEvNwOWbNQkEfqD1pSODxMI8tFo/PkqYsH/rUAOIo/HLzonxw96/61850Xk4ru9yCbjUg01ps3XOSRNIm+BMYonNRk4hE3DygqS9CfSFhNEbaSu9w9EE/ae7QAYSfPjg+7PemyS3c687JM38Ii4k0R2zyX995zsxuzbFBOBOkiAVn2s4tU5Rd44H+DAiKuTAFvEHU1e//UsE5bJr7yDIu2f5HB5dc/SkaSPFCY1wFsn8W6FbQmLoal9qD0DAPAjJkzJxNQDLu2yIa7VjiIV8fORxhXdO76FWuGo0XauE7EHa/4me5XRGVpFLwMXtFKUdxgvpOnG6/toGILjLX1gf82rXw2I8HIQy/MXSeIQpMj7Mong0sQZlO8SAIV8WklaypexI/ruM+hmr/FOG7798VD96TT2y9L+U/a/e/70bteZdSW8qJL5H5svqQMRy9OpO/hOI0eAmCoNzk0Gxpc/faPv/N/zKcQwTuiQJwaUsRUywCSgcstSIiIxU7Wap7JNbem5lDsQdBv//M/OJERpsrwSTVFKDcvOwFiJHskQjRllUmflPWSAMxecGmaGarjPpMT1mHOp6cYq/MssDCW4huJ+HsshwvKyWswb4ftkzZ7dNR71j4JzZwUHTocDDppV2EUiDQakxl3tqujMreYFI95l/H7VqRYzLgbxWIx77KJbrrOwNXew2+Kw7zLgpjMIiTz52ZT0rSmlKz/uyxO5+ptrKT/K1dB/q/UGvWU/99ISvV/dzpdrv+7GTqwkv6P8L9WKVdT/d8mUkz/Vy0rtb1ytV6/X07t/25/StL/3ezufxX+l6uA9NH9v1Kvpvv/JtLNq+AoRjeJwH1lOiaHND82e8gTeL2awI45xoBFmjmWbg+ZqC4XSzEAPI9g6wWSotcVhcf61xw/cHY44j/lwgsovauZEoJiU56awvoYnt4Rt/JIUes116Esdbr10glH6heCJl5NIjJT3obIq7vk7XqhSTMcin6PBbEtCjusuSxXFQHx81RPU/EUJTBEuiGCvobbu4Zek4X85OTHG9V7fpHqyyXkMVVgpgrMj1BgCk/5cKz9ZEDxvFK3Q8gnfURHx+0IKorPdDnavrj8LHKx1OU3C3i3QxXoBVdYkb8kZHaU858MxdWm6Kus+TmBYDD/orf9sI6Sf5WuddsPLr8IZaEw2PvlUsl/K0KYB5PN3TaxG4Ga1LsHK+FSq2j2+CogKX9IpByPrZAYJi7EJSrjyJxectOCPyx+ZdHlo0ocvvNOG9DG41cbLUJR6SlCYrLK+JLJWl65fCcabnHshDa3E8CFa6rcxSQVpgRNCt3jcp2mWbP+Ed0u0IYYnpmrSsBY4qNNPGvAYeNFjF/vccMVExAUXPHsgV9UNYDFuur0IZhifj1Uj65XCXGOPWJTyjDfuJhf/oRXxMPDdr8zCL259hLEoHZNa0A33gdLIAF3MOlfBZBXbweQV74aIK/dHiCvfC1AXr8dQF79aoC8cXuAvPq1AHnziwbyL8BYwrsqTR1N8dJKe5ZfwXzCK4x3emnmuKDOdF48kMRCxeO3bWNmIUtG25Jv3eaNeVdvZ0WJLG8MJDsWJCyPV3AH9hehy7hv3FgD1v74xUk/smo8vFIssFIUNIp8uVAZNygXGWkzk7R4OU+nlg/yV0T++J2VwGh9GyjvgmqCslVRVmrCK5nUVG15U5Wrmqova6qS2FRjeVPVq5pqLmuqKjf1uRXltzRd2/4jiIy4chur2X+U8fwnjf++qZTaf9zptLL9x0fQgdXsPxD/a2n89w2lmP1HZU+536jvNcrNRmr/cfvTNe0/PmH3v9r+o1qK4n+l2kz9vzaSPqf9BwEVmQSkViB3ywqEr/ytMwOhYaV2IKkdSGoHwlI7kNQOJLUD+QwHK3wT4q+/PEMQuXe3xhLk8in/Ak1Blq7C12QLcvmsf25jkJsC9C/KGuTyKf8CzUE+GtC/JHuQy2f9cxuE3BSgf1EWIZdP+RdoEvLRgP4l2YRcPuuf2yjkCkBPrULusFUIwUZqFpKahXxtaUn8XwG1n3jwI9JK9h8l9P8tNcup/+9mUmr/cafTFfF/b4QOXIn/pWYE/yu1Wnr/10ZSZS9q/1FVGqVqpVmupOYfdyAlxv+90d3/SvyvV0r16P5fL6X3f24krSH+b8LpyKbMPRLNNlDc9k03dtnoEqMNtFjAu6Dp/mU1UXjj11RjnbEBXS8k8J02mvBJixz+NzWbSM0mUrOJ1GwiPqe33GwiOXg1kcMvXBe/ohnBzYWxTpXwoeK3Qwn/uZngO5wuu//tZqS/VfW/TZT/Ss1KKv9tJKX63zudrnP/26fSgZX8/wj/y41KKdX/biLF/f+aSrl5v9RoNPfS+99uf1p+/9tN7f7XuP+tUQnjf7nZaJTS/X8TafP3v21ADfzV3AK3okr3ll8Dl+qBUz3wzd4D97Wr0tZyE9yXr0JLr4JLr4JL00bSVfafN3EL9Gr6vzrZfzRS/d9mUqr/u9Ppuvafn0IHVtP/1Sn+TznV/20kxfV/deV+rdHYq9Xq9VT/d+vT5fafN7H7X23/WW7G9v9qvZbu/5tIG7T/XOt1bxu1/DyaaWa7K49ozaaft+DWtETLz/TetFThlxp+poafqeEnaquRGn52ZfVNXiN2czrr9EIOllp9pilNaUpTmm4u/X+Xk3A5AGABAA==
